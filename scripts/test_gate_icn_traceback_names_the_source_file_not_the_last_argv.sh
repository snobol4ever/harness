#!/usr/bin/env bash
# test_gate_icn_traceback_names_the_source_file_not_the_last_argv.sh -- A RUN-TIME ERROR TRACEBACK AND &file
# NAME THE SOURCE FILE, NOT THE PROGRAM'S LAST ARGUMENT (cfo 2026-09-12, found by the shootout kernels).
#
# THE DEFECT, MEASURED: `procedure main(a); write(1 + a[1]); end` run as `scrip tb.icn -- x` died with
# `File x; Line 2` where iconx says `File tb.icn; Line 2`; fannkuch.icn run with 7 died `File 7; Line 58`.
# The driver had already recorded the source path per input while walking argv, then RE-SET it from
# argv[argc-1] after the walk -- which, once a `--` has split program arguments off, is the last of THEM.
# Every reader of that name moved with it: the traceback's File line, the per-frame `from line N in FILE`,
# &file, and the DWARF location. Same in both modes because the name is sealed at compile time.
#
# THE REF IS CUT FROM THE ORACLE AT RUN TIME: stdout (which prints &file) must be byte-identical, and the
# stderr lines that carry a file name (`File ...; Line ...` and `from line N in ...`) must match line for
# line. The rest of the traceback is not graded here -- other gates own its shape.
# ⭐ SELF-TEST SEAM: GATE_FAIL_ONCE=1 rewrites our extracted File line to the last argument so the gate is seen to say no.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(2) [$GATE]: lib_oracle_flags.sh unloadable"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE]: no scrip at $SCRIP"; exit 2; }
ICONT="$(icont_bin)" || exit 2
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/tb.icn" <<'ICN'
procedure main(a);
   write("file=", &file);
   write("args=", *a, " last=", a[-1]);
   write(1 + a[1]);
end
ICN
( cd "$T" && "$ICONT" -s -o tb.oracle tb.icn ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2) [$GATE]: icont did not compile the witness"; exit 2; }
( cd "$T" && ./tb.oracle x y >tb.ref 2>tb.ref.err ); ORC=$?
[ "$ORC" -ne 0 ] || { echo "⛔ REFUSE(2) [$GATE]: the oracle did not die on the witness (rc=0) -- the witness no longer errs"; exit 2; }
grep -E '^File .*; Line [0-9]+$|from line [0-9]+ in ' "$T/tb.ref.err" > "$T/ref.files"
grep -q '^File tb.icn; Line 4$' "$T/ref.files" || { echo "⛔ REFUSE(2) [$GATE]: the oracle traceback does not carry 'File tb.icn; Line 4' -- $(head -3 "$T/tb.ref.err" | tr '\n' '|')"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" tb.icn -- x y </dev/null >"$T/$M.out" 2>"$T/$M.err" )
  else ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile --out=tb.s tb.icn </dev/null >/dev/null 2>&1 && gcc -no-pie tb.s -o tb.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" ) >/dev/null 2>&1 || { echo "  m4 RED: the witness would not compile or link"; RC=1; continue; }
       ( cd "$T" && timeout -k 5 20 ./tb.bin x y </dev/null >"$T/$M.out" 2>"$T/$M.err" )
  fi
  python3 "$HERE/util_render_error_voice.py" icon < "$T/$M.err" | grep -E '^File .*; Line [0-9]+$|from line [0-9]+ in ' > "$T/$M.files"
  if [ -n "${GATE_FAIL_ONCE:-}" ]; then sed -i 's/^File tb.icn;/File y;/' "$T/$M.files"; fi
  if cmp -s "$T/tb.ref" "$T/$M.out" && cmp -s "$T/ref.files" "$T/$M.files"; then echo "  $M PASS (stdout byte-identical to iconx; file-bearing traceback lines: $(tr '\n' '|' < "$T/$M.files"))"
  else echo "  $M FAIL: stdout $(cmp "$T/tb.ref" "$T/$M.out" >/dev/null 2>&1 && echo same || echo DIFFERS); traceback file lines ours=[$(tr '\n' '|' < "$T/$M.files")] oracle=[$(tr '\n' '|' < "$T/ref.files")]"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$GATE]: the traceback and &file name the source file with program arguments present, in both modes"; exit 0; fi
echo "GATE FAIL [$GATE]: a program argument is being reported as the source file"; exit 1
