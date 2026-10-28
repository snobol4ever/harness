#!/usr/bin/env bash
# test_gate_pl_a_read_before_a_column_stop_carries_the_input_column_on_a_pipe_as_on_a_file.sh -- swipl links the input line to user_output's column:
# after read/1 has consumed "2." from standard input, the next format's column stop counts from column 2, whether stdin is a file or a pipe. SCRIP
# folded the consumed input into the output position from ftell(stdin), which fails on a pipe, so the carry was dropped there and every pipe-fed
# program printed its first column-stopped line two spaces wider than the ref (ProRosetta arithmetic-integer-1, graded through a pipe: FAIL in m3 and m4,
# CEO-2002). The probe is cut from swipl in THIS run for BOTH stdin kinds (swipl_bin); SCRIP's m3 and m4 are each run with a file and with a pipe and
# compared byte for byte; the self-test feeds the comparison a corrupted reference and requires it seen.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot run here"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plcol.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
t :- read(_), read(_), format('~w ~8|is ~d~n', [ab, 1]), format('~w ~8|is ~d~n', [ab, 2]).
:- initialization(t).
EOF
printf -- '-7.\n2.\n' > "$W/z.in"
for k in file pipe; do
  if [ $k = file ]; then timeout -k 5 20 "$SW" -q -t halt "$W/z.pl" < "$W/z.in" > "$W/ref.$k" 2> "$W/ref.err"
  else cat "$W/z.in" | timeout -k 5 20 "$SW" -q -t halt "$W/z.pl" > "$W/ref.$k" 2> "$W/ref.err"; fi
  [ "$(grep -c . "$W/ref.$k")" -eq 2 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the 2 probe lines with stdin as a $k ($(head -c 160 "$W/ref.err"))"; exit 2; }
done
cmp -s "$W/ref.file" "$W/ref.pipe" || { echo "GATE REFUSED(2) [$G]: swipl itself answers differently for a file and a pipe -- the premise of this gate is gone"; exit 2; }
timeout -k 5 30 "$ROOT/scrip" "$W/z.pl" < "$W/z.in" > "$W/m3.file" 2>&1
cat "$W/z.in" | timeout -k 5 30 "$ROOT/scrip" "$W/z.pl" > "$W/m3.pipe" 2>&1
"$ROOT/scrip" --compile -o "$W/z.s" "$W/z.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 160 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/z.bin" "$W/z.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 160 "$W/link.err"))"; exit 2; }
timeout -k 5 20 "$W/z.bin" < "$W/z.in" > "$W/m4.file" 2>&1
cat "$W/z.in" | timeout -k 5 20 "$W/z.bin" > "$W/m4.pipe" 2>&1
sed '1s/.*/corrupted/' "$W/ref.file" > "$W/z.bad"
if cmp -s "$W/m3.file" "$W/z.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
bad=0
for m in m3 m4; do for k in file pipe; do
  if cmp -s "$W/$m.$k" "$W/ref.$k"; then echo "  ok  $m stdin=$k: the 2 lines as swipl"; else echo "  RED $m stdin=$k: output differs from swipl:"; diff "$W/ref.$k" "$W/$m.$k" | head -6; bad=1; fi
done; done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a column stop after read/1 starts where the consumed input line ends, as swipl does, in both modes with stdin a file and with stdin a pipe (self-test: a corrupted reference is seen)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a column stop after read/1 differs from swipl for one stdin kind in one mode (tree SCRIP=$TREE)"; exit 1
