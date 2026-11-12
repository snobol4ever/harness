#!/usr/bin/env bash
# test_gate_cross_suite_ref_agreement.sh -- TWO SUITES MUST NOT HOLD CONTRADICTORY REFS FOR A BYTE-IDENTICAL
# PROGRAM. When they do, at least one ref is wrong, and nothing in the tree says which -- so a board built on
# the wrong one reports a red that is CORRECT OUTPUT FAILING A BAD REF.
#
# ⛔ WHY THIS EXISTS, and it is a measured cost, not a hypothetical (hq_B 2026-09-03, row ICN4, R-177):
# `procedure_every_scan_replace_5` in ALL.ref said Icon's x[-3+:6] FAILS; `rung36_jcon_lists` in
# rung36_all.ref said it yields `[4] 3 4 5 6`. THE SOURCES WERE BYTE-IDENTICAL. icont agrees with the second.
# ALL.ref was wrong, so the rungs board's two reds were correct SCRIP output failing a bad ref -- and I
# "cured" the compiler to match the bad ref, landing a real regression and a FALSE GREEN at 380/381 that five
# green arms and an officer audit all missed, because not one of them asked the ORACLE.
# ⭐ A ref is evidence about a PAST ORACLE RUN, not about the oracle. This gate cannot tell which ref is right
# -- only an oracle run can -- but it can prove that a disagreement EXISTS, which is the cheap half and the
# half that was available to me for free the whole time. It converts "somebody eventually notices" into a red.
#
# METHOD (since the tests consolidation, the coo 2026-11-12): every entry of every master under corpus/tests, read through the
# harness reader in either container form, is grouped by language, program text (trailing blanks ignored), stdin, arguments, and the
# compile_args, run_args, stage_name, dialect and stderr cells; a group of two or more is one program held twice, and two different
# refs in it (the entry's own name normalised, for &progname) are a contradiction, reported by name with the first differing line.
# Until 2026-11-12 the method paired an entry with a sibling family file (<family>.icn + <family>.ref) beside the master; the
# consolidation removes every family file, and the 32 pairs that method last read (all icon rung36_all) are entries of one master now.
# FAIL ONCE (2026-11-12): a scratch copy of tests/icon with one stdout line added to procedure_while_map_replace_2 read rc 1 naming
# it against procedure_while_map_replace_1; the tree reads 311 pairs over 6346 entries of 7 masters, GATE OK.
# EXIT 0 no contradictions; 1 at least one (names them); 2 REFUSED (cannot measure -- never skip-as-success).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
CORPUS="${CORPUS:-$S4E/corpus/tests}"
[ -d "$CORPUS" ] || { echo "⛔ GATE REFUSED (rc=2): cannot see $CORPUS -- nothing was checked" >&2; exit 2; }
python3 - "$CORPUS" "$HERE" <<'PY'
import csv,os,sys
root,here=sys.argv[1],sys.argv[2]
sys.path.insert(0,here)
import corpus_suite_harness as h
# ⭐ THE POPULATION SINCE THE CONSOLIDATION (the coo 2026-11-12): every entry of every master, read through the harness reader (the old
# container or format 2 alike). Until the tests/icon regroup its 32 pairs were the rung36_all.icn family file against its own absorbed
# entries; the consolidation removes every family file, so the same question is now asked of the masters themselves: two entries of
# one language with the same program, the same stdin, the same arguments, the same compile switches and the same staged name are ONE
# program run twice, and two different refs for it mean one ref is wrong.
EXT={"snobol4":".sno","icon":".icn","prolog":".pl","raku":".raku","pascal":".pas","snocone":".sc","rebus":".reb"}
def norm(lines): return "\n".join(l.rstrip() for l in lines).strip("\n")
def reftext(e):
    r=e.ref
    return (r if isinstance(r,str) else "\n".join(r)).replace(e.name,"<PROGNAME>")
langs=sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root,d)) and d in EXT)
seen=0; pairs=0; bad=[]; read=0
for lang in langs:
    d=os.path.join(root,lang); src=os.path.join(d,"ALL"+EXT[lang]); ref=os.path.join(d,"ALL.ref")
    if not os.path.exists(os.path.join(d,"ALL.csv")): continue
    if not ((os.path.exists(src) and os.path.exists(ref)) or h.fmt2_dir_of(src) is not None): continue
    lc=next((c for c in h.LANG_CONFIGS.values() if c.get("ext")==EXT[lang]), {})
    try: ents=h.read_suite(src,ref) if EXT[lang]==".sno" else h.read_block_suite(src,ref,h.banner_re_for(lc.get("comment_open","#"),lc.get("comment_close","")))
    except Exception as x:
        sys.stderr.write(f"⛔ GATE REFUSED (rc=2): the {lang} master did not read: {x}\n"); sys.exit(2)
    read+=1
    rows={r["entry"]:r for r in csv.DictReader(open(os.path.join(d,"ALL.csv"),encoding="utf-8",errors="replace"))}
    groups={}
    for e in ents:
        seen+=1; r=rows.get(e.name,{})
        key=(norm(e.sno_lines), e.stdin or "", tuple(e.argv or ()), r.get("compile_args",""), r.get("run_args",""), r.get("stage_name",""), r.get("dialect",""), r.get("stderr",""))
        groups.setdefault(key,[]).append(e)
    for key,g in groups.items():
        if len(g)<2: continue
        a=g[0]
        for b in g[1:]:
            pairs+=1
            if reftext(a)!=reftext(b):
                x=reftext(a).split("\n"); y=reftext(b).split("\n")
                first=next((f"{p!r}  vs  {q!r}" for p,q in zip(x,y) if p!=q), "(one ref is a prefix of the other)")
                bad.append((lang,a.name,b.name,first))
print(f"cross-suite ref agreement: {pairs} byte-identical program pair(s) compared ({seen} entries of {read} master(s) read) across {len(langs)} language dir(s)")
if bad:
    sys.stderr.write("⛔ GATE FAIL (rc=1): CONTRADICTORY REFS for byte-identical programs (same stdin, arguments and switches) -- at least one ref is WRONG:\n")
    for lang,x,y,first in bad:
        sys.stderr.write(f"    [{lang}] {x}  vs  {y}\n        first difference: {first}\n")
    sys.stderr.write("  ⛔ This gate cannot say WHICH ref is right -- run the ORACLE on the program and re-cut the loser.\n")
    sys.stderr.write("     Do NOT change the compiler to satisfy a ref until the oracle has spoken (row ICN4, 2026-09-03).\n")
    sys.exit(1)
if read==0 or seen==0:
    sys.stderr.write("⛔ GATE REFUSED (rc=2): no master read -- a green here would be an empty claim\n"); sys.exit(2)
print("✅ GATE OK: every byte-identical program held twice carries the SAME ref" + ("" if pairs else " (no program is held twice: nothing contradicts)"))
PY
