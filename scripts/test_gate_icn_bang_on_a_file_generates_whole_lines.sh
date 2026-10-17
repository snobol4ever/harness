#!/usr/bin/env bash
# test_gate_icn_bang_on_a_file_generates_whole_lines.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. !f (rt_runtime.c, the DT_FH arm of the element generator) read each line with fgets() into a 4096-byte
# stack buffer and measured it with strlen(), so a line longer than 4095 bytes came back as TWO elements (a 5000-byte line
# generated 4095 and 905) and a line carrying a NUL came back cut at it -- while read(f) over the same file returned both
# whole. Arizona iconx generates every line whole.
#
# WHAT IS HERE. !f reads with rt_line_read, the runtime's one growing line reader (read() already used it), and carries
# the byte count it returns as the element's length.
#
# ARM. Graded against the LIVE oracle (icont/iconx 9.5.25a) in both media: a file of a 5000-byte line, a short line, a
# 9000-byte line and a line with an embedded NUL, read once by !f and once by read(); the lengths printed must match
# iconx's byte for byte. A witness the oracle does not run refuses the gate rather than passing it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
python3 -c "import sys; sys.stdout.write('x'*5000 + '\n' + 'short\n' + 'y'*9000 + '\n' + 'ab\x00cd\n')" > "$T/long.txt" || exit 2
cat > "$T/w.icn" <<'EOF'
procedure main()
   local f;
   f := open("long.txt") | stop("no open");
   every write(*!f);
   close(f);
   f := open("long.txt") | stop("no open");
   while write(*read(f));
end
EOF
( cd "$T" && "$ICONT" -s -o w.x w.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses the witness"; exit 2; }
want="$( cd "$T" && ./w.x </dev/null 2>/dev/null )" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run the witness"; exit 2; }
( cd "$T" && "$SCRIP" --compile -o w.s w.icn </dev/null >/dev/null 2>&1 && gcc -no-pie -o w4 w.s -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "⛔ GATE REFUSE(2) [$G]: the witness does not build in mode 4"; exit 2; }
o3="$( cd "$T" && timeout -k 5 20 "$SCRIP" w.icn </dev/null 2>/dev/null )"; o4="$( cd "$T" && timeout -k 5 20 ./w4 </dev/null 2>/dev/null )"
echo "  HOLDS: !f generates each line whole, whatever its length and whether it carries a NUL, exactly as read() and iconx do"
if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  arm 1 PASS: lengths [$(printf '%s' "$want" | tr '\n' ' ')] in both media"; echo "✅ GATE PASS [$G]"; exit 0; fi
echo "  arm 1 FAIL: iconx [$(printf '%s' "$want" | tr '\n' ' ')] m3 [$(printf '%s' "$o3" | tr '\n' ' ')] m4 [$(printf '%s' "$o4" | tr '\n' ' ')]"
echo "⛔ GATE FAIL [$G]"; exit 1
