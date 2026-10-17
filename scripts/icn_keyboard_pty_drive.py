#!/usr/bin/env python3
"""icn_keyboard_pty_drive.py -- drive Arizona special/keyboard.icn over a real pty with the test's own
timed three-phase keystroke protocol, the only way this program grades at all: a redirected stdin cannot
supply getch()/kbhit() a real terminal, and `script(1)` cannot PACE the Quit key to land while the program
is polling inside test 3 -- ^\\ (0x1C) raises SIGQUIT the instant the pty's line discipline sees the byte
(ISIG stays on under cbreak), independent of whether the subject has read()'d anything yet, so a Quit sent
before test 3's kbhit() loop is reached lands on the wrong test. The keystroke script below (wait ~1s for
startup, then a,b,^D / c,d,^D / e,f,^\\ ~0.3s apart) matches what the coo's ask and CEO-1354 describe and is
proven byte-stable over 16 runs (8 m3 + 8 m4) against both SCRIP and the Arizona oracle (icont -s ... -x),
hq_icon 2026-10-01, closing special/keyboard out of UNGRADED.tsv (Zona -> 119/119).

Usage: icn_keyboard_pty_drive.py <cwd> <timeout_s> -- <argv...>
Runs argv (compile is NOT part of this -- argv is already the thing to execute: SCRIP --run ..., or a
compiled m4 binary, or the oracle's `icont -s NAME.icn -x`) attached to a pty as its controlling terminal,
feeds the keystroke script, and prints the transcript to stdout: CRLF normalized to LF, and -- SCRIP runs
only -- passed through the ONE error voice (util_render_error_voice.py icon, same renderer every other Icon
program is graded through, never reimplemented). Exits with the child's real exit status.
"""
import os, sys, pty, select, time, signal, subprocess

KEYSTROKES = [
    (1.0, b"a"), (0.3, b"b"), (0.3, b"\x04"),   # test 1 (getche, echoed): a, b, ^D
    (0.3, b"c"), (0.3, b"d"), (0.3, b"\x04"),   # test 2 (getch, silent):  c, d, ^D
    (0.3, b"e"), (0.3, b"f"), (0.3, b"\x1c"),   # test 3 (kbhit poll):     e, f, Quit (SIGQUIT)
]


def drive(cwd, timeout_s, argv):
    pid, master_fd = pty.fork()
    if pid == 0:
        os.chdir(cwd)
        try:
            os.execvp(argv[0], argv)
        except Exception as e:
            sys.stderr.write("icn_keyboard_pty_drive: exec failed: %s\n" % e)
            os._exit(127)

    out = bytearray()
    start = time.time()

    def drain(dur):
        end = time.time() + dur
        while time.time() < end:
            r, _, _ = select.select([master_fd], [], [], max(0, end - time.time()))
            if master_fd in r:
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    return False
                if not chunk:
                    return False
                out.extend(chunk)
        return True

    alive = True
    for delay, key in KEYSTROKES:
        if not drain(delay):
            alive = False
            break
        try:
            os.write(master_fd, key)
        except OSError:
            alive = False
            break

    deadline = start + timeout_s
    while alive and time.time() < deadline:
        r, _, _ = select.select([master_fd], [], [], 0.2)
        if master_fd in r:
            try:
                chunk = os.read(master_fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            out.extend(chunk)
        wpid, status = os.waitpid(pid, os.WNOHANG)
        if wpid == pid:
            break

    try:
        wpid, status = os.waitpid(pid, os.WNOHANG)
        if wpid != pid:
            time.sleep(0.3)
            r, _, _ = select.select([master_fd], [], [], 0.2)
            if master_fd in r:
                try:
                    out.extend(os.read(master_fd, 4096))
                except OSError:
                    pass
            wpid, status = os.waitpid(pid, os.WNOHANG)
        if wpid != pid:
            os.kill(pid, signal.SIGKILL)
            wpid, status = os.waitpid(pid, 0)
    except ChildProcessError:
        status = 0

    try:
        os.close(master_fd)
    except OSError:
        pass

    if os.WIFEXITED(status):
        rc = os.WEXITSTATUS(status)
    elif os.WIFSIGNALED(status):
        rc = 128 + os.WTERMSIG(status)
    else:
        rc = 1
    return bytes(out), rc


def render(raw_bytes, here):
    """CRLF -> LF (a pty artifact with no semantic content -- both the oracle's and SCRIP's captures get
    it, so normalizing it on both sides is a fair comparison, not a thumb on the scale), then SCRIP's error
    block through the ONE error voice. THE GLUE CORRECTION: every other graded program's prior output ends
    in '\\n' (write() guarantees it), so the renderer's unconditional leading blank line before "Run-time
    error" is exactly right. Here the line before a Quit-triggered crash is the raw, un-terminated echo of
    the ^\\ byte itself (local pty echo fires on receipt, before the subject ever read()s it) -- "scrip:
    error ..." lands glued onto that same line, which the renderer's anchored regex can't match at all. The
    fix is textual, not a renderer change (a second renderer reading pty-vs-non-pty context would be the
    second implementation CEO-625 exists against): split the glued line so the renderer's HEAD pattern can
    match, then drop the ONE synthetic blank line the renderer adds on the assumption of a preceding '\\n'
    that, here, never existed -- restoring exactly what the oracle's own leading '\\n' produces: a fresh
    line, not a blank one. Verified byte-identical to the oracle over 8 m3 + 8 m4 runs, hq_icon 2026-10-01.
    """
    text = raw_bytes.decode("utf-8", "surrogateescape")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    glued = False
    idx = text.find("scrip: error ")
    if idx > 0 and text[idx - 1] != "\n":
        text = text[:idx] + "\n" + text[idx:]
        glued = True
    rendered = subprocess.run(
        ["python3", os.path.join(here, "util_render_error_voice.py"), "icon"],
        input=text.encode("utf-8", "surrogateescape"), capture_output=True,
    ).stdout.decode("utf-8", "surrogateescape")
    if glued:
        lines = rendered.split("\n")
        for k in range(1, len(lines) - 1):
            if lines[k] == "" and lines[k + 1].startswith("Run-time error"):
                del lines[k]
                break
        rendered = "\n".join(lines)
    return rendered


def main():
    args = sys.argv[1:]
    if len(args) < 4 or args[2] != "--":
        sys.stderr.write("usage: icn_keyboard_pty_drive.py <cwd> <timeout_s> -- <argv...>\n")
        sys.exit(2)
    cwd = args[0]
    timeout_s = float(args[1])
    argv = args[3:]
    here = os.path.dirname(os.path.abspath(__file__))
    raw, rc = drive(cwd, timeout_s, argv)
    sys.stdout.write(render(raw, here))
    sys.exit(rc)


if __name__ == "__main__":
    main()
