#!/usr/bin/env python3
"""util_render_error_voice.py <oracle> -- THE EQUIVALENCE LIST, applied.  stdin -> stdout.

⛔⭐ ONE ERROR VOICE (Lon 2026-09-12, RULES.md § ONE ERROR VOICE, ceo CEO-623/625): the runtime prints ONE
SCRIP-shaped error for every language and never an oracle's shape.  A ref that pins an oracle's error text is
graded THROUGH THIS RENDERER: it rewrites every SCRIP error block in a captured stream into the named oracle's
shape, and the grader diffs the rendered stream against the oracle's ref.  Nothing is hidden and nothing is
dropped -- every field SCRIP printed is carried into the oracle's shape, and a block the list cannot render is
left as it stands (so it reads RED, never green by omission).

THE SCRIP VOICE (src/runtime/core/core.c core_error_voice):
    scrip: error <code>: <text>
      at <file>:<line>[; statement <stno>]        or        at startup
      offending value: <image>                     (only when the raise carried a value)
      in <frame>                                   (one per activation frame, outermost first, then the
                                                    builtin frames at that level and the operator in flight)

THE LISTS (each row is what the oracle prints for the SCRIP field, measured on the oracle named):
  icon     Arizona icont/iconx 9.5.25a (corpus/packages/icon/jcon_tests/errors.ref, loadfunc.ref are the receipts):
             "\\nRun-time error <code>\\nFile <basename(file)>; Line <line>\\n<text>\\n"
             "offending value: <image>\\n"                      when present
             "Traceback:\\n" then each frame on its own line, verbatim
             startup: "\\nRun-time error <code> in startup code\\n<text>\\n"
  spitbol  SPITBOL x64 fork /home/resources/x64/bin/sbl -bf (RULES.md § Oracles):
             "<file>(<line>) : ERROR <code:03d> -- <text>\\nin statement <stno>\\n"   (stno 0 when SCRIP printed none;
             frames and offending value have no SPITBOL counterpart and are dropped -- SPITBOL prints none)
  raku     rakudo-local 2026.05 (/home/resources/rakudo-local/bin/raku), the compile-time refusals only (code 701; measured
           2026-10-11 on sub f(Int $x) { }; f("x"), master entry sub_say_9):
             "===SORRY!=== Error while compiling <file>\\nCalling <f>(<types>) will never work with declared signature (<sig>)\\n
              at <file>:<line>\\n"  -- Rakudo's next line, the source excerpt with <HERE> (------>), is a field SCRIP does not
              carry and is not invented; every other code is left as SCRIP printed it
  none     identity (the SCRIP voice itself)

THE CODE RANGES THE VOICE RESERVES (src/runtime/core/core.c icn_errmsg_known is the table):
  700-799  compile-time semantic refusals of ANY language: a program refused before it runs (the cto's ruling on hq_raku's
           ask, 2026-10-11 04:xx CDT). The voice's located form, then exit 1: mode 3 before execution, mode 4's compile writes
           no .s. Taken: 701 a call that can never succeed against its callee's declared signature (Raku, lower_raku_refuse).
           The next language's compile-time refusal takes 702 and up.
"""
import re, sys, os

HEAD = re.compile(r'^scrip: error (\d+): (.*)$')
AT = re.compile(r'^  at (.*?):(\d+)(?:; statement (\d+))?$')
RAKU_701 = re.compile(r'^call (\S+?)\((.*)\) can never succeed against the declared signature (\(.*\))$')

def render(lines, oracle):
    out = []; i = 0; n = len(lines)
    while i < n:
        m = HEAD.match(lines[i])
        if not m:
            out.append(lines[i]); i += 1; continue
        code, text = int(m.group(1)), m.group(2)
        j = i + 1; at = None; startup = False; val = None; frames = []
        while j < n and lines[j].startswith('  '):
            l = lines[j]
            if at is None and not startup and AT.match(l): at = AT.match(l)
            elif l == '  at startup': startup = True
            elif l.startswith('  offending value: '): val = l[len('  offending value: '):]
            elif l.startswith('  in '): frames.append(l[5:])
            else: break
            j += 1
        if oracle == 'icon':
            if startup:
                out += ['', 'Run-time error %d in startup code' % code, text]
            else:
                f = os.path.basename(at.group(1)) if at else ''; ln = at.group(2) if at else '0'
                out += ['', 'Run-time error %d' % code, 'File %s; Line %s' % (f, ln), text]
                if val is not None: out.append('offending value: ' + val)
                out.append('Traceback:'); out += frames
        elif oracle == 'spitbol':
            f = at.group(1) if at else ''; ln = at.group(2) if at else '0'; st = at.group(3) if (at and at.group(3)) else '0'
            out += ['%s(%s) : ERROR %03d -- %s' % (f, ln, code, text), 'in statement %s' % st]
        elif oracle == 'raku' and code == 701 and RAKU_701.match(text):
            r = RAKU_701.match(text); f = at.group(1) if at else ''; ln = at.group(2) if at else '0'
            out += ['===SORRY!=== Error while compiling %s' % f, 'Calling %s(%s) will never work with declared signature %s' % (r.group(1), r.group(2), r.group(3)),
                    'at %s:%s' % (f, ln)]
        else:
            out += lines[i:j]
        i = j
    return out

SPITBOL_LINE_WIDTH = 120


def _wrap_spitbol(lines):
    """sbl -bf hard-wraps every line of its fatal block at 120 columns, mid-word, no indent (MEASURED 2026-09-28 10:4x: a 98-byte path
    made `...(2) : ERROR 014 -- div` end at column 120 and `ision caused integer overflow` follow on the next line). The rendered
    block is wrapped the same way, so a long path grades byte for byte instead of reading red on the oracle's own line breaking."""
    out = []
    for l in lines:
        while len(l) > SPITBOL_LINE_WIDTH:
            out.append(l[:SPITBOL_LINE_WIDTH]); l = l[SPITBOL_LINE_WIDTH:]
        out.append(l)
    return out


def _fatal_fields(block, oracle):
    """(file, line, statement, code, text) of ONE SCRIP error block, or None when the block carries no file:line; statement."""
    if oracle != 'spitbol' or not block:
        return None
    m = HEAD.match(block[0])
    if not m:
        return None
    code, text = int(m.group(1)), m.group(2)
    at = None
    for l in block[1:]:
        mm = AT.match(l)
        if mm:
            at = mm; break
    if at is None or not at.group(3):
        return None
    return at.group(1), at.group(2), at.group(3), code, text


def render_fatal_block(block, oracle):
    """THE FATAL BLOCK AS THE ORACLE PRINTS IT ON STDOUT (ceo CEO-1344, on hq_snobol4's measurement, the cfo seconding; the coo's
    row instruments-a-spitbol-fatal-is-gradable-...). `block` is ONE SCRIP error block (the `scrip: error` line and its indented
    lines); the result is the list of stdout lines the oracle prints for the same fatal, so a grader can append it to SCRIP's
    stdout before comparing with a ref cut from the oracle. MEASURED 2026-09-28 09:00 CDT on x64 sbl -bf, r.sno (OUTPUT then a
    run-time 1 / Y with Y = 0), stdout byte for byte:
        before                                      <- the program's own output
        (three empty lines)
        r.sno(3) : ERROR 014 -- division caused integer overflow
        (five empty lines)
        in file              r.sno
        in line              3
        in statement         3
        stmts executed       3                      <- masked: oracle-internal until SCRIP reports its own count
        execution time msec  0                      <- masked
        REGENERATIONS        0                      <- masked
        memory used (bytes)  11448                  <- masked (csnobol4 ALL.mask since 2026-09-08)
        memory left (bytes)  1037120                <- masked
        (one empty line)
    and sbl EXITS 0 after a run-time fatal where SCRIP exits 1 (the rc clause of the same list, applied by the harness).
    The labels are padded to column 21. The five run-summary lines SCRIP does not carry are NOT rendered -- a field SCRIP does
    not carry is masked beside the data, never invented -- and the suite's ALL.mask drops them from the oracle side. A block
    with no `at <file>:<line>; statement <n>` (a startup error, a compile refusal) renders nothing, so it reads RED, never
    green by omission; the compile-time fatal shape (a listing header with the date, `page 1`, the statement text) is a
    different block this list does not render. 'icon' and 'none' render nothing here: their refs carry stderr voices."""
    return _wrap_spitbol(_fatal_lines_unwrapped(block, oracle))


def _fatal_lines_unwrapped(block, oracle):
    fields = _fatal_fields(block, oracle)
    if fields is None:
        return []
    f, ln, st, code, text = fields
    # THE FILE NAME IS PRINTED AS SCRIP PRINTED IT -- the path the program was named by, which is the path the oracle was named by
    # (a runner hands both engines the same argument: bare in the harness's scratch directory, a full path in the Dotnet runner),
    # so it is never shortened here; a basename would match the one shape and red the other. Lines longer than 120 columns are
    # wrapped by the caller exactly as the oracle wraps them (_wrap_spitbol).
    # THE FIVE RUN-SUMMARY LINES ARE PRINTED WITH A DASH, NEVER A NUMBER: the CEO-409 mask replaces a matching line with a
    # placeholder ON BOTH SIDES (apply_line_mask keeps the line count), so the line must exist here to be masked -- its value
    # is the field SCRIP does not carry, and `-` says so where a number would be an invention. The mask rows admit the dash.
    return ['', '', '',
            '%s(%s) : ERROR %03d -- %s' % (f, ln, code, text),
            '', '', '', '', '',
            'in file              %s' % f,
            'in line              %s' % ln,
            'in statement         %s' % st,
            'stmts executed       -',
            'execution time msec  -',
            'REGENERATIONS        -',
            'memory used (bytes)  -',
            'memory left (bytes)  -']


def render_fatal_merged(block, oracle):
    """The same fatal as a MERGED stdout+stderr capture reads it (the bash package runners capture 2>&1 and cut their refs the same
    way). MEASURED 2026-09-28 09:1x CDT, sbl -bf r.sno 2>&1 through a pipe: sbl writes each line of the block to both streams
    unbuffered, so the merged text is the program's output, three empty lines, the error line TWICE, seven empty lines (stdout's
    five and stderr's two), then in file / in line / in statement / stmts executed / execution time msec / REGENERATIONS each
    TWICE, memory used, memory left (stdout only), two empty lines. Deterministic, so rendered as measured; the twice-printed
    run-summary lines are masked by the same regexes as the once-printed ones."""
    one = _fatal_lines_unwrapped(block, oracle)
    if not one:
        return []
    err_line = one[3]
    # each stream is wrapped at 120 columns on its own, so a wrapped error line appears as its two halves twice in a row
    e = _wrap_spitbol([err_line])
    return (['', '', ''] + e + e + ['', '', '', '', '', '', ''] +
            _wrap_spitbol([one[9]]) * 2 + _wrap_spitbol([one[10]]) * 2 + _wrap_spitbol([one[11]]) * 2 +
            [one[12], one[12], one[13], one[13], one[14], one[14], one[15], one[16]])


def replace_fatal_in_text(lines, oracle, merged):
    """Replace the FIRST SCRIP error block inside a captured text with the oracle's block (merged capture or stdout-only), the
    rest of the text untouched. A text with no SCRIP block is returned as it stands."""
    i = 0
    while i < len(lines):
        if HEAD.match(lines[i]):
            j = i + 1
            while j < len(lines) and lines[j].startswith('  '):
                j += 1
            block = lines[i:j]
            rendered = render_fatal_merged(block, oracle) if merged else render_fatal_block(block, oracle)
            if not rendered:
                return lines
            return lines[:i] + rendered + lines[j:]
        i += 1
    return lines


FATAL_SUMMARY_MASKS = (   # each admits the oracle's number and the renderer's dash, so the placeholder lands on both sides
    (r'^stmts executed       ([0-9]+|-)$', "SPITBOL's own statement counter printed in its fatal block: oracle-internal until SCRIP reports its own count (CEO-1344); SCRIP's rendered block carries a dash"),
    (r'^execution time msec  ([0-9]+|-)$', "SPITBOL's own clock reading in its fatal block: a duration, never a program's answer (CEO-1344); SCRIP's rendered block carries a dash"),
    (r'^REGENERATIONS        ([0-9]+|-)$', "SPITBOL's own collector count in its fatal block: engine bookkeeping, not the program's data (CEO-1344); SCRIP's rendered block carries a dash"),
    (r'^memory used \(bytes\)  ([0-9]+|-)$', "SPITBOL's own allocator arithmetic (CEO-420 clause (b), csnobol4 ALL.mask 2026-09-08), printed in every fatal block (CEO-1344); SCRIP's rendered block carries a dash"),
    (r'^memory left \(bytes\)  ([0-9]+|-)$', "the same allocator arithmetic from the other side, masked with its twin or not at all (CEO-1344); SCRIP's rendered block carries a dash"),
)


if __name__ == '__main__':
    args = sys.argv[1:]
    fatal = None
    if '--fatal-merged' in args:
        args.remove('--fatal-merged'); fatal = 'merged'
    elif '--fatal-stdout' in args:
        args.remove('--fatal-stdout'); fatal = 'stdout'
    if len(args) != 1 or args[0] not in ('icon', 'spitbol', 'raku', 'none'):
        sys.stderr.write('REFUSE(rc=2): util_render_error_voice.py <icon|spitbol|raku|none> [--fatal-merged|--fatal-stdout]  (stdin -> stdout)\n'); sys.exit(2)
    data = sys.stdin.buffer.read().decode('utf-8', 'surrogateescape')
    trailing_nl = data.endswith('\n')
    lines = data.split('\n')
    if trailing_nl: lines = lines[:-1]
    if fatal:
        # THE FATAL BLOCK (CEO-1344): a bash runner pipes SCRIP's captured text through here; the SCRIP error block inside it is
        # replaced by the oracle's fatal block as that runner's capture would read it (merged 2>&1, or stdout alone).
        res = replace_fatal_in_text(lines, args[0], fatal == 'merged')
    else:
        res = render(lines, args[0])
    text = '\n'.join(res) + ('\n' if trailing_nl else '')
    sys.stdout.buffer.write(text.encode('utf-8', 'surrogateescape'))
