#!/usr/bin/env bash
# test_gate_xfail_has_reason.sh -- A REASONLESS XFAIL IS A RED, NOT A PASS (row xfail-entries-carry-a-
# reason-or-are-reds, minted by hq_T 2026-09-03; GOAL MASTER-PLAN I23). An xfail line with no stated WHY is
# indistinguishable from a red somebody hid, and the plan deliberately converts uncured reds into REASONED
# xfails by H+32 -- so this gate is what keeps a 100% cell from becoming exactly that trophy-cabinet number.
#
# MECHANISM: every corpus/tests/<lang>/ALL<ext> source (ext from the driver's own frontend list -- .sno
# .icn .pl .sc .reb .raku .pas) embeds a banner comment before each xfail entry: "<dashes> <rank> <entry>
# XFAIL", wrapped in whatever comment syntax that language uses (*, #, %, /* */, { }). corpus/tests/<lang>/
# ALL.xfail (when present) repeats the SAME banner line as a plain-text header, followed by reason prose,
# one block per xfail entry, until the next banner or EOF.
# ⛔ THIS GATE IS COMMENT-SYNTAX AGNOSTIC ON PURPOSE (byte-safe pattern over authored text, THE INSTRUMENT
# LAWS): it matches the core "-{3,} RANK ENTRY XFAIL" shape wherever it sits on a line, so it needs no
# per-language comment-char table and cannot silently under-count a language whose syntax it forgot.
# A reason "counts" if the prose block is non-empty and is not a bare placeholder token (todo/tbd/unknown/
# n/a/-/?/fixme, case-insensitive, matched against the WHOLE stripped block) -- no length floor beyond that:
# this project's own ALL.xfail already carries real reasons as short as one clause, and a length floor would
# reject those alongside the placeholders it exists to catch.
# OUT OF SCOPE, NAMED SO THE NEXT READER ISN'T SURPRISED: corpus/tests/icon/rung36_jcon_*.xfail is a
# DIFFERENT mechanism (one reason file per vendor JCON suite file, not per ALL.csv entry; born of the
# icon-jcon-suite-39 census row) and is not scored by any language's 100% cell -- left to that row's owner.
# EXIT 0 every XFAIL-banner entry found has a real reason; 1 at least one does not (named, by language); 2
# REFUSED (examined nothing -- corpus/tests absent, or truly zero XFAIL banners anywhere, too suspicious to
# certify as a silent pass).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
CORPUS="${CORPUS:-$S4E/corpus/tests}"
. "$HERE/lib_gate.sh"
gate_require "$CORPUS" "the corpus/tests tree"
SUMMARY="$(python3 - "$CORPUS" <<'PY'
import io,os,re,sys
root=sys.argv[1]
SOURCE_EXTS={'.sno','.icn','.pl','.sc','.reb','.raku','.pas'}
BANNER=re.compile(r'-{3,}\s+(\d+)\s+([A-Za-z0-9_.-]+)\s+XFAIL\b')
PLACEHOLDER={'todo','tbd','unknown','n/a','na','-','?','xxx','fixme',''}
# ⭐ KEYED BY ENTRY NAME ALONE, NEVER BY (rank,entry) -- icon/ALL.xfail proved rank is NOT a shared key: its
# banner reads "#---- 1 procedure_scan_while_1 XFAIL" (LOCAL sequence number within that one-entry file)
# while the source corpus/tests/icon/ALL.icn banner for the same program reads rank 722 (the corpus-wide
# rank). A (rank,entry) key silently missed that real reason as a false gap. Entry names are verified unique
# per language (zero duplicates across all seven ALL.csv, checked live), so name alone is a safe, honest key
# -- rank is kept only as a display convenience for whichever numbering the SOURCE file uses.
def banners_in(path):
    out={}
    try: lines=io.open(path,encoding='utf-8',errors='replace').read().split('\n')
    except OSError: return out
    for l in lines:
        m=BANNER.search(l)
        if m: out[m.group(2)]=int(m.group(1))
    return out
def reasons_in(path):
    out={}
    try: lines=io.open(path,encoding='utf-8',errors='replace').read().split('\n')
    except OSError: return out
    cur=None; buf=[]
    for l in lines:
        m=BANNER.search(l)
        if m:
            if cur is not None: out[cur]='\n'.join(buf)
            cur=m.group(2); buf=[]
        elif cur is not None: buf.append(l)
    if cur is not None: out[cur]='\n'.join(buf)
    return out
langs=sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root,d)))
# ⛔⭐⭐ A LANE LON HAS PARKED CANNOT HOLD THIS GATE RED, AND ITS GAPS STILL GET COUNTED AND NAMED (ceo ->
# hq_T 2026-09-05, OCTET: "THE ORDER OF WORK IS SNOBOL4, ICON AND PROLOG; Pascal, Raku, Rebus and Snocone
# rows stay PARKED-LON-HOLD"). Blocking on a parked lane teaches the reader to ignore a red gate, which is
# strictly worse than the gap it is reporting -- and dropping those entries would be the trophy-cabinet
# number this gate exists to prevent. So they are REPORTED: counted, named, never silent, never blocking.
# ⛔⭐ THE BRIEF SAID "177, ALL SNOCONE" AND THE MEASUREMENT SAYS OTHERWISE -- 182 gaps, 156 raku, 17
# snocone, 5 snobol4, 4 rebus. Those 5 snobol4 entries sit in the FIRST lane of the order of work, so
# reporting the whole population would have hidden live work in the active lane behind a parked-lane excuse.
# That is the entire reason this partitions instead of demoting the gate wholesale.
# ⛔⭐ THE ROSTER IS POLICY, NOT A MEASUREMENT, AND THERE IS NO MACHINE-READABLE AUTHORITY FOR IT: the
# order of work lives in the MODE file's PROSE header, and CLAUDE.md's standing rule is to read MODE's first
# line and NEVER its prose. A parser over that sentence would break on the next rewording and refuse a gate
# that had nothing wrong with it. So the roster is an explicit parameter -- and the mitigation for the
# hand-typed-population trap hq_I measured today (a gate that lifts its MAP correctly and then hand-types
# its ROSTER passes green over the roots it forgot) is that this gate PRINTS THE ROSTER IT USED on every
# run. A stale roster is then visible in the output of the thing it distorts, rather than silent. Override
# with XFAIL_ACTIVE_LANGS when Lon's order moves.
ACTIVE=[x.strip() for x in os.environ.get('XFAIL_ACTIVE_LANGS','snobol4,icon,prolog').split(',') if x.strip()]
present=[l for l in ACTIVE if l in langs]
if not present:
    print("REFUSE(2): the active-lane roster [%s] names no language present under %s (found: %s) -- "
          "refusing to grade an empty blocking set, which would print a pass over nothing"
          % (','.join(ACTIVE) or '<empty>', root, ','.join(langs) or '<none>'))
    sys.exit(2)
total_x=0; total_gap=0; gaps=[]; orphan_notes=[]
for lang in langs:
    d=os.path.join(root,lang)
    xmap={}
    for f in os.listdir(d):
        base,ext=os.path.splitext(f)
        if base=='ALL' and ext in SOURCE_EXTS: xmap.update(banners_in(os.path.join(d,f)))
    reasons=reasons_in(os.path.join(d,'ALL.xfail'))
    lang_gap=0
    for entry,rank in sorted(xmap.items(),key=lambda kv:kv[1]):
        body=reasons.get(entry)
        stripped=' '.join((body or '').split())
        if body is None or stripped.lower() in PLACEHOLDER:
            lang_gap+=1; gaps.append((lang,rank,entry))
    orphans=sorted(set(reasons)-set(xmap))
    if orphans:
        orphan_notes.append(f"    NOTE [{lang}]: {len(orphans)} ALL.xfail block(s) with no matching source entry (stale?) -- e.g. entry={orphans[0]}")
    total_x+=len(xmap); total_gap+=lang_gap
    print(f"  {lang}: xfail={len(xmap)} reasoned={len(xmap)-lang_gap} gap={lang_gap}")
for note in orphan_notes: print(note)
blocking=[g for g in gaps if g[0] in ACTIVE]
parked=[g for g in gaps if g[0] not in ACTIVE]
print(f"  ACTIVE LANES (blocking): {','.join(ACTIVE)}  <- the roster this run used; if Lon's order of work has moved, this line is the stale thing")
for lang,rank,entry in blocking:
    print(f"    GAP [{lang}] rank={rank} entry={entry} -- no reason (or a placeholder) in ALL.xfail")
if parked:
    bylang={}
    for lang,rank,entry in parked: bylang.setdefault(lang,[]).append(entry)
    print(f"  REPORTED, NOT BLOCKING -- {len(parked)} gap(s) in PARKED lanes ({', '.join('%s=%d'%(k,len(v)) for k,v in sorted(bylang.items()))}).")
    print(f"      They are real debt and are counted here so the number cannot quietly become a 100% cell; they do not red this gate while their lane is parked.")
    for lang,rank,entry in parked:
        print(f"    PARKED-GAP [{lang}] rank={rank} entry={entry} -- no reason (or a placeholder) in ALL.xfail")
print(f"SUMMARY total_xfail={total_x} total_gap={total_gap} blocking_gap={len(blocking)} parked_gap={len(parked)}")
PY
)"
echo "$SUMMARY" | grep -v '^SUMMARY '
# ⛔ The python half REFUSES rc=2 on an empty active roster and says so on stdout; propagate that rather
# than falling through to a verdict computed from an unset variable (which would read as zero gaps = pass).
case "$SUMMARY" in "REFUSE(2):"*) exit 2;; esac
TOTAL_X="$(echo "$SUMMARY" | sed -n 's/^SUMMARY total_xfail=\([0-9]*\) .*/\1/p')"
BLOCK_GAP="$(echo "$SUMMARY" | sed -n 's/^SUMMARY .*blocking_gap=\([0-9]*\) .*/\1/p')"
PARKED_GAP="$(echo "$SUMMARY" | sed -n 's/^SUMMARY .*parked_gap=\([0-9]*\)$/\1/p')"
gate_floor "${TOTAL_X:-0}" 1 "XFAIL-banner entries examined"
GATE_EXAMINED="${TOTAL_X:-0} XFAIL entries, ${PARKED_GAP:-0} parked gap(s) reported not blocking"
gate_verdict "${BLOCK_GAP:-0}" "XFAIL entries in an ACTIVE lane with no real reason"
