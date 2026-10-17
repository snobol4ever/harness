#!/usr/bin/env python3
"""
read_one_wire.py — minimal single-participant wire reader for smoke testing
the SN-26-csn-bridge runtime.  Not intended for production sync-step work
(use ../harness/scripts/monitor/monitor_sync_bin.py for that).

Spec:  READY GO

SN-26-bridge-coverage-e: streaming intern on the wire.  MWK_NAME_DEF
records bind name_id -> name bytes inline; this reader builds a names
table from those records and prints semantic records (VALUE / CALL /
RETURN / END / LABEL) only.  No sidecar file is used.

The optional third argument (NAMES_FILE) is accepted for backward
compatibility with older test harnesses but is now WRITTEN at end of
run as a derived artifact: the per-participant intern table built from
MWK_NAME_DEF records, dumped one name per line indexed 0..N-1.  Tests
that grep that file continue to pass; tests that want the live wire
encoding can ignore it.
"""
import os
import sys
import struct

KIND_NAMES = {1: "VALUE", 2: "CALL", 3: "RETURN", 4: "END", 5: "LABEL", 6: "NAME_DEF",
              7: "PM_CALL", 8: "PM_EXIT", 9: "PM_REDO", 10: "PM_FAIL"}
TYPE_NAMES = {0: "NULL", 1: "STRING", 2: "INTEGER", 3: "REAL", 4: "NAME",
              5: "PATTERN", 6: "EXPRESSION", 7: "ARRAY", 8: "TABLE",
              9: "CODE", 10: "DATA", 11: "FILE", 255: "UNKNOWN"}

MWK_NAME_DEF = 6


def main():
    if len(sys.argv) < 3:
        print("usage: read_one_wire.py READY_FIFO GO_FIFO [NAMES_FILE]", file=sys.stderr)
        sys.exit(2)
    ready_path = sys.argv[1]
    go_path    = sys.argv[2]
    names_path = sys.argv[3] if len(sys.argv) > 3 else None

    for p in (ready_path, go_path):
        if os.path.exists(p):
            os.unlink(p)
        os.mkfifo(p)

    print(f"[ctrl] waiting for participant to open {ready_path}...", file=sys.stderr)
    ready_fd = os.open(ready_path, os.O_RDONLY)
    print(f"[ctrl] participant connected, opening go FIFO...", file=sys.stderr)
    go_fd    = os.open(go_path, os.O_WRONLY)
    print(f"[ctrl] go FIFO open, reading wire...", file=sys.stderr)

    names = {}            # name_id -> bytes
    n_records = 0         # count of SEMANTIC records (excludes NAME_DEF)

    while True:
        hdr = b""
        while len(hdr) < 13:
            chunk = os.read(ready_fd, 13 - len(hdr))
            if not chunk:
                print(f"[ctrl] EOF on ready fd after {n_records} records", file=sys.stderr)
                break
            hdr += chunk
        if len(hdr) < 13:
            break

        kind, name_id, t, vlen = struct.unpack("<IIBI", hdr)
        value = b""
        while len(value) < vlen:
            chunk = os.read(ready_fd, vlen - len(value))
            if not chunk:
                break
            value += chunk

        # Streaming intern: absorb NAME_DEF, ack, do not surface.
        if kind == MWK_NAME_DEF:
            names[name_id] = value
            print(f"[ctrl] [NAME_DEF id={name_id} name={value!r}]", file=sys.stderr)
            try:
                os.write(go_fd, b"G")
            except OSError as e:
                print(f"[ctrl] ack write failed (NAME_DEF): {e}", file=sys.stderr)
                break
            continue

        kn = KIND_NAMES.get(kind, f"?{kind}")
        tn = TYPE_NAMES.get(t,    f"?{t}")
        if t == 2 and len(value) == 8:    # INTEGER
            (ival,) = struct.unpack("<q", value)
            vrepr = f"INTEGER({ival})"
        elif t == 3 and len(value) == 8:  # REAL
            (rval,) = struct.unpack("<d", value)
            vrepr = f"REAL({rval})"
        elif t in (1, 4):                  # STRING / NAME
            vrepr = f"{tn}({vlen})={value!r}"
        else:
            vrepr = f"{tn}(empty)"

        print(f"[ctrl] #{n_records:03d} kind={kn} name_id={name_id} {vrepr}",
              file=sys.stderr)
        n_records += 1

        if kind == 4:   # END
            break
        try:
            os.write(go_fd, b"G")
        except OSError as e:
            print(f"[ctrl] ack write failed: {e}", file=sys.stderr)
            break

    os.close(ready_fd)
    os.close(go_fd)
    print(f"[ctrl] read {n_records} records total", file=sys.stderr)

    # Back-compat artifact: write derived names file if requested.
    if names_path:
        max_id = max(names) if names else -1
        with open(names_path, "w") as f:
            for i in range(max_id + 1):
                nm = names.get(i, b"")
                try:
                    s = nm.decode("utf-8")
                except UnicodeDecodeError:
                    s = nm.decode("utf-8", "backslashreplace")
                f.write(s + "\n")
        if names:
            print(f"[ctrl] wrote {len(names)} names to {names_path}:", file=sys.stderr)
            for i, nm in sorted(names.items()):
                try:
                    s = nm.decode("utf-8")
                except UnicodeDecodeError:
                    s = nm.decode("utf-8", "backslashreplace")
                print(f"[ctrl]   id={i}: {s}", file=sys.stderr)


if __name__ == "__main__":
    main()
