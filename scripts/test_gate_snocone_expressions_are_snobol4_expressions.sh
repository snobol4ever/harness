#!/bin/bash
# test_gate_snocone_expressions_are_snobol4_expressions.sh -- Lon 2026-09-28 (ceo CEO-1357): a Snocone expression is a SPITBOL
# expression. Every line of ../harness/scripts/fixtures/expression_identity_deck.txt is compiled as X = <expr> by sbl -bf (the oracle
# decides valid or invalid), by SCRIP's SNOBOL4 parser and by SCRIP's Snocone parser (X = <expr>;). Each parser's verdict
# must be SPITBOL's, and for a valid expression the two parsers' trees must be byte-identical. Two exceptions are NAMED,
# never silent: angle-bracket subscripts are out of Snocone by Lon's ruling (the Snocone verdict must be a refusal), and
# lines listed in ../harness/scripts/fixtures/expression_identity_open.tsv are printed with the row that owns them -- and still read RED (no xfail).
# SCRIP's non-ASCII identifier letters are KEPT (Lon 2026-09-28: "keep the extension"; src/parsers/snobol4/unicode_alpha_ranges.h): an
# expression holding a byte >= 0x80 outside a literal is graded as valid whatever sbl -bf says, so both parsers must accept it alike.
# rc 0 all agree · rc 1 a disagreement not named as open · rc 2 cannot measure (no oracle, no scrip, empty deck).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SCRIP="$HERE/../../SCRIP/scrip"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
DECK="$HERE/fixtures/expression_identity_deck.txt"; OPEN="$HERE/fixtures/expression_identity_open.tsv"
[ -x "$SCRIP" ] || { echo "REFUSE(2): no scrip at $SCRIP"; exit 2; }
[ -x "$SBL" ] || { echo "REFUSE(2): no SPITBOL oracle at $SBL"; exit 2; }
[ -s "$DECK" ] || { echo "REFUSE(2): empty or missing deck $DECK"; exit 2; }
python3 - "$SCRIP" "$SBL" "$DECK" "$OPEN" <<'PY'
import sys, subprocess, re, tempfile, os
scrip, sbl, deck, openf = sys.argv[1:5]
exprs = [l.rstrip("\n") for l in open(deck, encoding="utf-8") if l.strip()]
opened = {}
if os.path.exists(openf):
    for l in open(openf, encoding="utf-8"):
        if l.startswith("#") or not l.strip(): continue
        p = l.rstrip("\n").split("\t")
        if len(p) >= 2: opened[p[0]] = p[1]
d = tempfile.mkdtemp()
def run(cmd): return subprocess.run(cmd, capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL)
def oracle(e):
    p = os.path.join(d, "s.sno"); open(p, "w").write("        X = " + e + "\nEND\n")
    r = run([sbl, "-bf", p]); m = re.search(r"ERROR (\d+) -- ([^\n]*)", r.stdout + r.stderr)
    return not (m and ("syntax error" in m.group(2) or m.group(1) in ("212", "221", "225", "228", "229", "230", "233")))
def parse(e, lang):
    p = os.path.join(d, "t." + lang)
    open(p, "w").write(("        X = " + e + "\nEND\n") if lang == "sno" else ("X = " + e + ";\n"))
    ok = run([scrip, "--compile", "-o", os.devnull, p]).returncode == 0
    out = run([scrip, "--dump-ast", p]); t = out.stdout + out.stderr
    if not ok or re.search(r"parse error|syntax error|parse failed|unexpected char", t): return False, ""
    i = t.find(":repl ")
    if i < 0: return False, ""
    depth = 0; o = []
    for ch in t[i + 6:]:
        o.append(ch)
        if ch == "(": depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0: break
    return True, " ".join("".join(o).split())
red = []; named = []
for e in exprs:
    v = oracle(e) or bool(re.search(r"[\x80-\U0010ffff]", re.sub(r"'[^']*'|\"[^\"]*\"", "", e))); nok, nt = parse(e, "sno"); cok, ct = parse(e, "sc"); why = []
    if nok != v: why.append("SNOBOL4 %s where SPITBOL %s" % ("accepts" if nok else "refuses", "accepts" if v else "refuses"))
    if v and ("<" in e or ">" in e):
        if cok: why.append("Snocone accepts an angle-bracket subscript (ruled out, Lon 2026-09-28)")
    else:
        if cok != v: why.append("Snocone %s where SPITBOL %s" % ("accepts" if cok else "refuses", "accepts" if v else "refuses"))
        if v and nok and cok and nt != ct: why.append("trees differ: SNOBOL4 %s | Snocone %s" % (nt[:120], ct[:120]))
    if why: (named if e in opened else red).append((e, "; ".join(why), opened.get(e, "")))
print("expression identity: deck=%d  agree=%d  open(named)=%d  red=%d" % (len(exprs), len(exprs) - len(red) - len(named), len(named), len(red)))
for e, w, row in named: print("  OPEN %-18s %s  [row: %s]" % (e, w, row))
for e, w, row in red: print("  RED  %-18s %s" % (e, w))
sys.exit(1 if (red or named) else 0)
PY
