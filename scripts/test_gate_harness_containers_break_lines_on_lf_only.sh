#!/usr/bin/env bash
# test_gate_harness_containers_break_lines_on_lf_only.sh -- A CONTAINER'S ONLY LINE BREAK IS LF (the coo 2026-09-28, on hq_snobol4's report:
# csnobol4_suite/alph read FAIL in m3 and m4 in the area smoke while SCRIP's output equalled live sbl -bf byte for byte).
# THE DEFECT: corpus_suite_harness.py read every ALL.<ext>/ALL.ref with Path.read_text().splitlines(). read_text() turns each CR into LF,
# and splitlines() also breaks on VT, FF, FS, GS, RS, NEL, LS and PS -- so a ref whose oracle output carries one of those bytes came back
# as more lines than the program wrote, and the grade compared it against the raw output. Measured over corpus e30a5d955: 13 containers,
# 5473 entries, 4 read differently -- ipl progs/filexref (a CR) and progs/puzz (a form feed), csnobol4_suite alph and crlf.
# THE ARMS:
#   1  a scratch SNOBOL4 container whose first entry prints CR, VT, FF, FS, GS, RS mid-line and a CR before its newline, the ref cut from
#      sbl -bf (the ONE oracle, through sbl_correctness_bin), grades PASS in m3 and m4 through `corpus_suite_harness.py run`;
#   2  FAIL-ONCE: the same container with the old reader planted back into a copy of the harness reads the control entry FAIL in both modes;
#   3  THE REAL CORPUS: the entries whose reading changes between the old and the new reader are EXACTLY the entries whose ref carries one
#      of those bytes (both sets derived here, from every ALL.ref with its ALL.<ext> beside it) -- nothing else moved;
#   4  _lf_lines keeps splitlines()'s one-trailing-newline convention: "a\n\nb\n" -> a,"",b; "" -> none; "x" -> x.
#   5  THE RUNGS BUILDER: util_build_rungs_suite.py --additive absorbs the control program (arm 1's) from a scratch demos folder into a scratch
#      copy of the SNOBOL4 master, and the absorbed entry's answer, read back through `corpus_suite_harness.py extract --out-ref`, equals the
#      oracle's output byte for byte (the additive road once built it with str.splitlines(), CIO-46 D: two coverage_sno_nodes answers lost
#      their VT/FF/CR/FS/GS/RS bytes and read red against a correct SCRIP); the builder refusing or absorbing nothing REFUSES rc 2.
# EXIT 0 all hold; 1 an arm failed; 2 could not measure.
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the harness over a scratch container outside the corpus, not a board (R-547)"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=harness_containers_break_lines_on_lf_only
gate_parse_args "$@"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_oracle_flags.sh"; exit 2; }
H="$HERE/corpus_suite_harness.py"; gate_require "$H" "corpus_suite_harness.py" || exit 2
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: this tree's binary is stale or unbuilt -- make"; exit 2; }
SBL="$(sbl_correctness_bin)" && [ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the SNOBOL4 oracle is not installed"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"; C="$S4E/corpus"
[ -d "$C/tests" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no corpus at $C"; exit 2; }
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }

mkdir -p "$W/s"
cat > "$W/ctl.sno" <<'EOF'
        CR = SUBSTR(&ALPHABET,14,1)
        OUTPUT = 'a' CR 'b'
        OUTPUT = 'v' SUBSTR(&ALPHABET,12,1) 'f' SUBSTR(&ALPHABET,13,1) 'x'
        OUTPUT = 'fs' SUBSTR(&ALPHABET,29,1) 'gs' SUBSTR(&ALPHABET,30,1) 'rs' SUBSTR(&ALPHABET,31,1)
        OUTPUT = 'crlf' CR
        OUTPUT =
        OUTPUT = 'last'
END
EOF
printf "        OUTPUT = 'plain'\nEND\n" > "$W/plain.sno"
for p in ctl plain; do timeout -k 5 8 "$SBL" -bf "$W/$p.sno" < /dev/null > "$W/$p.out" 2>/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl -bf refused the fixture $p.sno"; exit 2; }; done
python3 - "$HERE" "$W" <<'PY' || { echo "GATE UNPROVEN(2) [$GATE_NAME]: could not build the scratch container"; exit 2; }
import sys, pathlib
sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
W = pathlib.Path(sys.argv[2]); src = ref = b""
for i, n in enumerate(("ctl", "plain"), 1):
    b = h.make_banner(i, n).encode() + b"\n"
    src += b + (W / f"{n}.sno").read_bytes(); ref += b + (W / f"{n}.out").read_bytes()
(W / "s" / "ALL.sno").write_bytes(src); (W / "s" / "ALL.ref").write_bytes(ref)
PY
premise=$(python3 -c "import sys; b=open(sys.argv[1],'rb').read(); print(all(c in b for c in (b'\r', b'\x0b', b'\x0c', b'\x1c', b'\x1d', b'\x1e')))" "$W/ctl.out")
[ "$premise" = True ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the oracle's output does not carry the six bytes the fixture prints -- the arms would prove nothing"; exit 2; }
board() { grep -o "m$2_pass=[0-9]*" <<<"$1" | head -1 | cut -d= -f2; }

echo "--- ARM 1: a container carrying CR, VT, FF, FS, GS, RS grades PASS in both modes ---"
o1=$(S4E_PROGRESS_DB="$W/db1.tsv" timeout -k 5 300 python3 "$H" run "$W/s/ALL.sno" "$W/s/ALL.ref" --modes m3,m4 2>&1); r1=$?
b1=$(grep '^SUITE_BOARD' <<<"$o1" | head -1)
[ -n "$b1" ] || { echo "$o1" | tail -8; echo "GATE UNPROVEN(2) [$GATE_NAME]: the harness printed no SUITE_BOARD line (rc $r1)"; exit 2; }
ck "1 both entries PASS in m3 and m4 (rc $r1; m3_pass=$(board "$b1" 3) m4_pass=$(board "$b1" 4) of 2)" '[ "$r1" = 0 ] && [ "$(board "$b1" 3)" = 2 ] && [ "$(board "$b1" 4)" = 2 ]'

echo "--- ARM 2: FAIL-ONCE -- the old reader planted back ---"
. "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$W/fo" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $W/fo"; exit 2; }; rm -f "$W/fo/harness/scripts/corpus_suite_harness.py"
sed 's/^    return _lf_lines(Path(path).read_bytes().decode("utf-8"))$/    return Path(path).read_text().splitlines()  # FAIL_ONCE: the old reader/' "$H" > "$W/fo/harness/scripts/corpus_suite_harness.py"
grep -q 'FAIL_ONCE: the old reader' "$W/fo/harness/scripts/corpus_suite_harness.py" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the plant found no _read_lf_lines anchor -- re-anchor"; exit 2; }
o2=$(S4E_PROGRESS_DB="$W/db2.tsv" SCRIP="$HERE/../../SCRIP/scrip" RT_DIR="$HERE/../../SCRIP/out" timeout -k 5 300 python3 "$W/fo/harness/scripts/corpus_suite_harness.py" run "$W/s/ALL.sno" "$W/s/ALL.ref" --modes m3,m4 2>&1); r2=$?
b2=$(grep '^SUITE_BOARD' <<<"$o2" | head -1)
ck "2 with the old reader the control entry reads FAIL in both modes and the plain one still passes (rc $r2; m3_pass=$(board "$b2" 3) m4_pass=$(board "$b2" 4) of 2)" '[ -n "$b2" ] && [ "$(board "$b2" 3)" = 1 ] && [ "$(board "$b2" 4)" = 1 ]'

echo "--- ARM 3: over the real corpus only the entries whose ref carries such a byte read differently ---"
o3=$(timeout -k 5 600 python3 - "$HERE" "$C" <<'PY' 2>&1
import sys, pathlib
sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
C = pathlib.Path(sys.argv[2]); SEPS = ("\r", "\x0b", "\x0c", "\x1c", "\x1d", "\x1e", "\x85", " ", " ")
new = h._read_lf_lines
def old(path): return pathlib.Path(path).read_text().splitlines()
containers = entries = 0; changed = set(); carriers = set()
for ref in sorted(C.glob("**/ALL.ref")):
    d = ref.parent; hit = None
    for lang, cfg in h.LANG_CONFIGS.items():
        if (d / ("ALL" + cfg["ext"])).is_file(): hit = (lang, cfg); break
    if hit is None and (d / "ALL.sno").is_file(): hit = ("snobol4", {"ext": ".sno"})
    if hit is None: continue
    lang, cfg = hit; src = d / ("ALL" + cfg["ext"])
    def read(reader):
        h._read_lf_lines = reader
        try:
            if cfg["ext"] != ".sno":
                return h.read_block_suite(str(src), str(ref), h.banner_re_for(cfg["comment_open"], cfg["comment_close"]))
            return h.read_suite(str(src), str(ref))
        finally:
            h._read_lf_lines = new
    try:
        a, b = read(old), read(new)
    except Exception as e:
        print("UNREADABLE", ref.relative_to(C), type(e).__name__, str(e)[:120]); continue
    containers += 1; entries += len(b)
    key = str(d.relative_to(C))
    if len(a) != len(b): changed.add(key + ":<entry count>")
    for x, y in zip(a, b):
        if (x.name, x.sno_lines, x.ref) != (y.name, y.sno_lines, y.ref): changed.add(key + ":" + y.name)
    for y in b:
        text = "\n".join(y.ref) if isinstance(y.ref, list) else (y.ref or "")
        if any(s in text for s in SEPS): carriers.add(key + ":" + y.name)
print("CONTAINERS", containers, "ENTRIES", entries)
print("CHANGED", len(changed), " ".join(sorted(changed)))
print("CARRIERS", len(carriers), " ".join(sorted(carriers)))
print("AGREE" if changed == carriers else "DISAGREE only-changed=%s only-carrying=%s" % (sorted(changed - carriers), sorted(carriers - changed)))
PY
); r3=$?
echo "$o3" | sed 's/^/      /'
grep -q '^UNREADABLE' <<<"$o3" && { echo "GATE UNPROVEN(2) [$GATE_NAME]: a real container could not be read -- the census cannot see its population"; exit 2; }
grep -q '^CONTAINERS [1-9]' <<<"$o3" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the census read no container (rc $r3)"; exit 2; }
ck "3 the changed entries and the entries whose ref carries CR/VT/FF/FS/GS/RS/NEL/LS/PS are the same set" 'grep -q "^AGREE$" <<<"$o3"'

echo "--- ARM 4: the one-trailing-newline convention is kept ---"
o4=$(python3 -c "import sys; sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h; print(h._lf_lines('a\n\nb\n') == ['a','','b'] and h._lf_lines('') == [] and h._lf_lines('x') == ['x'] and h._lf_lines('p\x0cq\rr\n') == ['p\x0cq\rr'])" "$HERE" 2>&1)
ck "4 _lf_lines: a,'',b / none / x / one line keeping FF and CR ($o4)" '[ "$o4" = True ]'

echo "--- ARM 5: the rungs builder's additive road keeps the six bytes of an absorbed answer ---"
B="$HERE/util_build_rungs_suite.py"; gate_require "$B" "util_build_rungs_suite.py" || exit 2
D5="$W/b5"; mkdir -p "$D5/corpus/tests" "$D5/corpus/demos/snobol4" "$D5/corpus/benchmarks/snobol4" "$D5/corpus/include" || exit 2
[ -f "$C/tests/snobol4/ALL.sno" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no SNOBOL4 master at $C/tests/snobol4 to copy"; exit 2; }
cp -r "$C/tests/snobol4" "$D5/corpus/tests/snobol4" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot copy the master into scratch"; exit 2; }
cp "$W/ctl.sno" "$D5/corpus/demos/snobol4/lfgate_ctl.sno" || exit 2
( cd "$S4E/SCRIP" && S4E_HOME="$D5" timeout -k 10 900 python3 "$B" --lang snobol4 --additive --from demos < /dev/null ) > "$D5/build.log" 2>&1; b5=$?
grep -q 'new entries absorbed' "$D5/build.log" || { tail -5 "$D5/build.log"; echo "GATE UNPROVEN(2) [$GATE_NAME]: the builder printed no accounting (rc $b5) -- arm 5 cannot measure"; exit 2; }
python3 "$H" list "$D5/corpus/tests/snobol4/ALL.sno" "$D5/corpus/tests/snobol4/ALL.ref" --lang snobol4 2>/dev/null | grep -qx 'demo_lfgate_ctl' || { tail -5 "$D5/build.log"; echo "GATE UNPROVEN(2) [$GATE_NAME]: the builder absorbed nothing named demo_lfgate_ctl (rc $b5) -- arm 5 cannot measure"; exit 2; }
python3 "$H" extract "$D5/corpus/tests/snobol4/ALL.sno" "$D5/corpus/tests/snobol4/ALL.ref" demo_lfgate_ctl "$D5/x.sno" --out-ref "$D5/x.ref" > /dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the absorbed entry back"; exit 2; }
ck "5 the absorbed answer equals the oracle's output byte for byte ($(wc -c < "$W/ctl.out") bytes oracle, $(wc -c < "$D5/x.ref") bytes absorbed)" 'cmp -s "$W/ctl.out" "$D5/x.ref"'

echo "------------------------------------------------------------"
echo "population: $n check(s): one scratch container of 2 entries graded twice in 2 modes (cured, planted), one absorbed by the additive builder, $(grep -o '^CONTAINERS [0-9]* ENTRIES [0-9]*' <<<"$o3" | tr 'A-Z' 'a-z') re-read two ways"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
