#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_no_script_passes_dash_o_to_scrip.sh -- THE ASSEMBLY OUTPUT IS --out=FILE, AND NO SCRIPT HANDS IT TO SCRIP AS -o FILE (Lon, "Do make our
# SCRIP command-line switches just like SPITBOL." CEO-1224: SPITBOL's -o=file names the compilation LISTING, so SCRIP's --compile output moved to
# --out=FILE; the cto's row spine-scrip-assembly-output-moves-from-o-file-to-out-file-and-every-script-that-passes-o-migrates-in-the-same-landing,
# reowned to hq_templates by CEO-2005).
#
# ARM 1 (blocking, ceiling 0): lib_scrip_dash_o.py reads zero scrip commands that pass -o FILE or -oFILE across harness, SCRIP (Makefile, tools),
#        corpus and .github scripts -- shell by a tokenizer (segments, wrappers, $( ), heredocs), Python by ast, python-in-shell by pattern.
# ARM 2 (blocking): the instrument CAN fail and does not over-reach -- a fixture of known bare -o callers reads exactly its expected HITS, and a
#        fixture of look-alikes (gcc -o, -o=file the listing sink, --out=, a comment, an argument after a bare --, a Python gcc list) reads 0.
# ARM 3 (blocking): no stub compiler parses a bare -o (a fake scrip that took -o would hide a stale caller the real driver refuses).
# rc 0 green · rc 1 red · rc 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LIB="$HERE/lib_scrip_dash_o.py"
[ -f "$LIB" ] && command -v python3 >/dev/null || { echo "⛔ REFUSE(2): $LIB or python3 is absent"; exit 2; }
fail=0
roots=(); for d in "$ROOT/harness" "$ROOT/SCRIP" "$ROOT/corpus" "$ROOT/.github"; do [ -d "$d" ] && roots+=("$d"); done
[ "${#roots[@]}" -ge 2 ] || { echo "⛔ REFUSE(2): fewer than two sibling repos under $ROOT"; exit 2; }
out="$(python3 -I "$LIB" scan --exclude=test_gate_no_script_passes_dash_o_to_scrip.sh "${roots[@]}" 2>&1)"; n="$(printf '%s\n' "$out" | sed -n 's/^HITS //p')"
[ -n "$n" ] || { echo "⛔ REFUSE(2): the instrument printed no HITS line: $(printf '%s' "$out" | head -2)"; exit 2; }
if [ "$n" = 0 ]; then echo "  ok   ARM 1: no script passes -o FILE to scrip (ceiling 0)"
else echo "  RED  ARM 1: $n script site(s) pass -o to scrip, ceiling 0:"; printf '%s\n' "$out" | grep -v '^HITS' | head -8 | cut -c1-200 | sed 's/^/         /'; fail=1; fi
F="$(mktemp -d)"; trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bad" "$F/good"
cat > "$F/bad/a.sh" <<'EOB'
"$SCRIP" --compile -o "$T/a.s" p.sno
timeout -k 5 20s ./scrip --compile p.pl -o p.s </dev/null
r=$("$ROOT/scrip" --compile -ox.s p.sno 2>&1)
S=$ROOT/scrip
env -u SCRIP_DIAG "$S" --compile -o "$W/b.s" "$f"
python3 - <<'EOP'
c = run([scrip, "--compile", "-o", s, prog])
EOP
EOB
cat > "$F/bad/b.py" <<'EOB'
import subprocess
subprocess.run([scrip, "--compile", "-o", out, prog])
EOB
cat > "$F/good/a.sh" <<'EOB'
gcc -no-pie x.s -o bin
"$SCRIP" --run -o=list.lst p.sno
"$SCRIP" --compile --out="$T/a.s" p.sno
"$SCRIP" p.sno -- -o foo
# "$SCRIP" --compile -o commented.s p.sno
echo "$SCRIP --compile -o in-a-string.s" > /dev/null
icont -s -o prog p.icn
EOB
cat > "$F/good/b.py" <<'EOB'
import subprocess
subprocess.run(["gcc", "-o", b, s])
subprocess.run([scrip, "--compile", f"--out={out}", prog])
EOB
bad="$(python3 -I "$LIB" scan "$F/bad" | sed -n 's/^HITS //p')"; good="$(python3 -I "$LIB" scan "$F/good" | sed -n 's/^HITS //p')"
if [ "$bad" = 6 ] && [ "$good" = 0 ]; then echo "  ok   ARM 2: the instrument reads its bare -o fixture red (HITS $bad of 6 expected) and its look-alike fixture clean (HITS $good)"
else echo "  RED  ARM 2: the instrument is wrong -- bare -o fixture HITS $bad (expected 6), look-alike fixture HITS $good (expected 0)"; fail=1; fi
stubs="$(grep -rnE 'case "\$1" in[^;]*(^|[ ;|(])-o\)' "$HERE" "$ROOT/SCRIP/tools" 2>/dev/null | grep -v '/test_gate_no_script_passes_dash_o_to_scrip.sh:' | grep -v 'bench_wrap')"
if [ -z "$stubs" ]; then echo "  ok   ARM 3: no stub compiler parses a bare -o"
else echo "  RED  ARM 3: a script parses a bare -o as an option (a stub scrip must take --out=FILE):"; printf '%s\n' "$stubs" | head -5 | cut -c1-200 | sed 's/^/         /'; fail=1; fi
[ "$fail" = 0 ] && { echo "GATE OK [test_gate_no_script_passes_dash_o_to_scrip]: no script hands the assembly output to scrip as -o"; exit 0; }
echo "GATE FAIL [test_gate_no_script_passes_dash_o_to_scrip]"; exit 1
