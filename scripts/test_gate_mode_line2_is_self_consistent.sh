#!/bin/bash
# test_gate_mode_line2_is_self_consistent.sh -- MODE line 2 checked against ITSELF, with no second file.
#
# ⛔⭐ WHY THIS INSTRUMENT IS THE INVERSE OF EVERY OTHER LANE CHECK WE OWN, WHICH IS THE WHOLE POINT.
# Every lane instrument we had compares TWO readers -- the picker's table vs MODE line 2, a preflight parser
# vs MODE line 2, a seat's HQ file vs MODE line 2. All of them are blind BY CONSTRUCTION to line 2 being
# wrong about itself, because line 2 is the thing they all measure against. When CEO-723 rewrote the hq_S
# lane paragraph and missed two cross-references, line 2 said three things about Rebus at once:
#     "REBUS IS CLOSED ... so this seat carries Pascal and nothing else"   (the hq_S clause: DISCLAIMED)
#     "Rebus moves to hq_S."                                              (tail of the hq_T clause: ASSIGNED)
#     "... SNOCONE -- hq_I; REBUS -- hq_S; SNOBOL4 -- the cfo ..."        (THE SEATS list: ASSIGNED)
# test_gate_picker_lane_table_agrees_with_mode.sh printed rebus ✅ throughout. The agreement was REAL -- the
# table said hq_S and line 2 said hq_S -- and the fact underneath it was not. ⭐ THE GENERAL FORM, which is
# why this is a gate and not a one-off fix: a consistency check between A and B can never see B contradicting
# B. If a single document is the authority for N readers, SOMETHING has to grade the document alone, or its
# self-contradictions are invisible in exactly the proportion that we rely on it.
#
# ⛔ AND THE DAMAGE IS NOT PROPORTIONAL TO THE ERROR (cto -> hq_B, 2026-09-13). This is a census that names
# WORK ITEMS -- seats and languages -- not one that names numbers. A wrongly named owner is not ignored, it
# is ACTED ON: hq_I routed a Snocone co-sign to "hq_S (Rebus)" off exactly these words, and had hq_S signed,
# the Rebus arm of CEO-727 would carry a name and no owner, which reads as complete and is worse than blank.
# So this gate's cost is set by its WORST false positive, never by its rate, and every RED it prints names
# the exact substring and its byte offset in line 2 so the ceo can cure the LAW without re-deriving anything.
#
# WHAT IT CANNOT DO, STATED SO NOBODY READS MORE INTO A GREEN: it grades line 2 against line 2. A line that
# is uniformly, consistently WRONG about who owns a language is GREEN here, and correctly so -- that is what
# the two-reader gates are for. This one only ever answers "does the law agree with itself".
#
# Usage: bash ../harness/scripts/test_gate_mode_line2_is_self_consistent.sh [--selftest] [--file <MODE-path>]
#   (no args)   parses the live MODE line 2; 0 self-consistent · 1 CONTRADICTION (named) · 2 cannot parse
#   --selftest  proves the scanner BOTH WAYS on fixtures before its live verdict means anything
#               (RULES.md INSTRUMENT LAWS #2). Exits 0 only if it REDS on every dirty fixture and PASSES
#               on every clean one.
#
# ⛔ rc=2 IS NOT A PASS. "I could not find any ownership claim in line 2" and "line 2 has no contradiction"
# are the same printed output from opposite causes -- the empty-grep trap (hq_S -> hq_B, 2026-09-13: the
# shape of the answer you wanted is also the shape of the instrument failing). The anti-vacuity floor below
# is what separates them: fewer than MODE_L2_MIN_LANGS languages carrying ANY claim is a REFUSAL, because a
# parser that has stopped matching agrees with everything it can no longer see.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PO="${S4E_POST:-/home/resources/postoffice}"
MODEF="${MODE_L2_FILE:-$PO/MODE}"
MIN_LANGS="${MODE_L2_MIN_LANGS:-7}"

# ===================================================================== SHARED SCANNER (live run + selftest both call this) ===
# ⛔ The scanner is ONE function called by both arms. A selftest that exercises a second copy of the logic
# proves the copy, which is the defect this project keeps re-measuring in other clothes.
scan_line2() {  # $1 = path to a MODE-shaped file. prints a report; rc 0 clean · 1 contradiction · 2 cannot measure
  MODE_L2_MIN_LANGS="$MIN_LANGS" python3 - "$1" <<'PYEOF'
import os, re, sys

LANGS = ["snobol4", "icon", "prolog", "snocone", "rebus", "raku", "pascal"]
SEAT = r"(?:the )?(ceo|cto|coo|cfo|hq_[A-Za-z0-9]+)"
MIN = int(os.environ.get("MODE_L2_MIN_LANGS", "7"))

path = sys.argv[1]
try:
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
except OSError as e:
    print("⛔ REFUSES rc=2: cannot read %s (%s)" % (path, e)); sys.exit(2)
if len(lines) < 2 or not lines[1].strip():
    print("⛔ REFUSES rc=2: %s has no line 2 -- nothing to check against itself." % path); sys.exit(2)
L2 = lines[1]

# ---------------------------------------------------------------- the four claim shapes line 2 has actually used.
# Each yields (language, owner, shape, offset, evidence). `owner` is a seat token, or the pseudo-owner CLOSED.
# ⭐ Every shape is ANCHORED and adjacency-sensitive on purpose. "the SNOBOL4 runtime moves to the cfo" is a
# CONCERN moving, not a LANGUAGE LANE moving, and the one-word gap is the only thing that distinguishes them --
# so MOVES requires the language token immediately before "moves to". Widening that regex re-reads every
# concern hand-off as a lane reassignment and manufactures contradictions out of correct prose.
#
# ⛔⭐ AUTHORITATIVE vs MENTION -- THE DISTINCTION THIS GATE'S OWN SELFTEST FORCED ON IT, AND THE MOST
# IMPORTANT LINE IN THE FILE. The first draft treated every shape as an exclusive ownership claim and
# immediately reddened PROLOG on a perfectly correct line: NONET names "cto PROLOG, the ISO ladder",
# "hq_C PROLOG BREADTH" and "hq_R PROLOG BUILTINS AND STREAMS" -- three seats, one language, ZERO
# contradiction, because lanes are cut BY CONCERN and not only by language (Lon 2026-09-13). A roster clause
# says "this seat works on this language", which is not a claim to own it. Only THE SEATS list, an IS-CLOSED
# declaration and a MOVES-TO fragment claim the single completeness/ladder owner, so only those three can
# contradict each other. ⛔ Reddening on roster mentions would have made this gate loudest on the mode line's
# most deliberate feature -- a naming census whose worst false positive is "the ceo rewrites a correct lane
# cut to quiet an instrument", which is precisely the damage class that makes naming censuses expensive.
AUTHORITATIVE = ("SEATS-LIST", "IS-CLOSED", "MOVES-TO")
claims = []
def add(lang, owner, shape, m):
    s = max(0, m.start() - 12); e = min(len(L2), m.end() + 12)
    claims.append((lang, owner, shape, m.start(), L2[s:e].strip()))

for lang in LANGS:
    U = lang.upper()
    # (1) THE SEATS list:  "RAKU -- hq_T"  ·  "ICON -- the ceo"  ·  "REBUS -- CLOSED, NO OWNER"   [AUTHORITATIVE]
    for m in re.finditer(r"\b%s -- %s\b" % (U, SEAT), L2):      add(lang, m.group(1), "SEATS-LIST", m)
    for m in re.finditer(r"\b%s -- CLOSED\b" % U, L2):          add(lang, "CLOSED", "SEATS-LIST", m)
    # (2) the CONCERN-1 roster clause:  "ceo ICON" · "cfo SNOBOL4" · "hq_I SNOCONE"                [MENTION ONLY]
    for m in re.finditer(r"\b(ceo|cto|coo|cfo|hq_[A-Za-z0-9]+) %s\b" % U, L2): add(lang, m.group(1), "ROSTER-CLAUSE", m)
    # (3) a reassignment fragment:  "PASCAL moves to hq_S" · "Rebus moves to hq_S"                 [AUTHORITATIVE]
    for m in re.finditer(r"\b%s moves to %s\b" % (U, SEAT), L2, re.I): add(lang, m.group(1), "MOVES-TO", m)
    # (4) a closure declaration:  "REBUS IS CLOSED"                                                [AUTHORITATIVE]
    for m in re.finditer(r"\b%s IS CLOSED\b" % U, L2, re.I):    add(lang, "CLOSED", "IS-CLOSED", m)

# ---------------------------------------------------------------- disclaimers: "this seat carries Pascal and nothing else".
# A disclaimer is an EXCLUSIVITY claim by whichever seat's clause it sits in, so it needs that clause's owner.
# ⭐ It is the only positional shape here, and it is the shape that caught the real defect first: a seat
# disclaiming a language it is elsewhere handed is a contradiction no owner-vs-owner comparison can see,
# because BOTH sentences name the same seat.
#
# ⛔ THE ANCHOR IS THE LAST ROSTER CLAUSE, NEVER THE LAST SEAT TOKEN -- the second bug this gate's selftest
# caught in this gate. The nearest seat token before the live disclaimer is `cfo`, from "the SNOBOL4 runtime
# moves TO THE CFO, so this seat carries Pascal and nothing else": a seat named as the DESTINATION of a
# hand-off sits between the clause owner and its own disclaimer. Anchoring to it attributed hq_S's disclaimer
# to the cfo and then reddened SNOBOL4 -- a fabricated contradiction, on a clean line, naming the wrong seat.
# A clause OWNER is a seat token immediately followed by its language, which is exactly a ROSTER-CLAUSE match.
disclaimers = []   # (seat, kept_language, offset, evidence)
roster_at = [(c[3], c[1]) for c in claims if c[2] == "ROSTER-CLAUSE"]
for m in re.finditer(r"carries ([A-Za-z0-9]+) and nothing else", L2, re.I):
    kept = m.group(1).lower()
    before = [r for r in roster_at if r[0] < m.start()]
    if not before or kept not in LANGS:
        continue
    disclaimers.append((max(before)[1], kept, m.start(), L2[max(0, m.start()-40):m.end()+4].strip()))

# ---------------------------------------------------------------- verdict.
print("MODE line 2 self-consistency -- %s" % path)
print("  line 2: %d bytes, %d ownership claim(s) over %d language(s), %d exclusivity disclaimer(s)"
      % (len(L2.encode("utf-8")), len(claims), len({c[0] for c in claims}), len(disclaimers)))

seen_langs = sorted({c[0] for c in claims if c[2] in AUTHORITATIVE})
if len(seen_langs) < MIN:
    print("⛔ REFUSES rc=2: only %d of %d language(s) carry ANY parseable OWNER claim in line 2 (%s)."
          % (len(seen_langs), MIN, ", ".join(seen_langs) or "none"))
    print("   NOT a clean verdict. Line 2 is prose whose phrasing is reinvented at every mode cut, so a")
    print("   parser that has stopped matching it prints zero contradictions for the same reason a")
    print("   contradiction-free line does. Those two must never share an exit code.")
    sys.exit(2)

bad = 0
for lang in seen_langs:
    mine = [c for c in claims if c[0] == lang]
    owners = sorted({c[1] for c in mine if c[2] in AUTHORITATIVE})
    # a disclaimer bites an AUTHORITATIVE owner or a ROSTER mention alike: either way the seat is put on a
    # language its own clause says it does not carry.
    dis = [d for d in disclaimers if d[1] != lang and d[0] in {c[1] for c in mine}]
    if len(owners) == 1 and not dis:
        extra = sorted({c[1] for c in mine if c[2] == "ROSTER-CLAUSE" and c[1] != owners[0]})
        note = "+".join(sorted({c[2] for c in mine if c[2] in AUTHORITATIVE}))
        if extra:  # concern lanes under one owner -- reported, never red (see AUTHORITATIVE above)
            note += "   (also worked by %s -- a concern lane, not a rival owner)" % "/".join(extra)
        print("  %-8s %-28s ✅ %s" % (lang, owners[0], note))
        continue
    bad += 1
    if len(owners) > 1:
        print("  %-8s %-28s ⛔ CONTRADICTION -- line 2 claims %s for %s in the same line"
              % (lang, "/".join(owners), " AND ".join(owners), lang))
    else:
        print("  %-8s %-28s ⛔ CONTRADICTION -- assigned to %s, which elsewhere in line 2 disclaims it"
              % (lang, owners[0], owners[0]))
    for c in sorted(mine, key=lambda c: c[3]):
        print("      byte %-6d %-14s %-8s ...%s..." % (c[3], c[2], c[1], c[4]))
    for d in dis:
        print("      byte %-6d %-14s %-8s ...%s..." % (d[2], "DISCLAIMER", d[0],
              "%s carries %s AND NOTHING ELSE" % (d[0], d[1])))
        print("      ⭐ %s is handed %s above and says it carries only %s. Both sentences name %s, so no"
              % (d[0], lang, d[1], d[0]))
        print("        owner-vs-owner check can see it -- only a self-consistency pass can.")

if bad:
    print("⛔ GATE FAILED: %d of %d language(s) are claimed inconsistently by MODE line 2 ALONE." % (bad, len(seen_langs)))
    print("   THE LINE IS THE CEO'S TO EDIT AND THIS GATE DOES NOT RESOLVE IT BY PREFERRING A READING.")
    print("   Route it as an ASK to ceo/inbox quoting the byte offsets above; the other lane gates are")
    print("   comparing their tables against this contradiction and printing agreement.")
    sys.exit(1)
print("✅ GATE OK -- all %d language(s) carry one consistent owner across every claim shape in line 2" % len(seen_langs))
sys.exit(0)
PYEOF
}

# ===================================================================================== § SELF-TEST ===
if [ "${1:-}" = "--selftest" ]; then
  st_rc=0; sandbox="$(mktemp -d)"; trap 'rm -rf "$sandbox"' EXIT
  check() { if [ "$2" = "$3" ]; then echo "  SELF-TEST OK: $1"; else echo "  SELF-TEST FAIL: $1 -- got [$2] expected [$3]"; st_rc=1; fi; }
  echo "=== $(basename "$0") --selftest ==="
  echo "⭐ fixtures are VERBATIM EXCERPTS of the shapes MODE line 2 has actually carried, not invented prose."

  # ⛔ THE DIRTY FIXTURE IS THE REAL DEFECT, TRANSCRIBED. These are the three Rebus claims and the hq_S
  # exclusivity disclaimer exactly as MODE.bak-2026-09-13-2159-ceo736-line2-rebus-and-raku-residue carried
  # them, trimmed to the clauses that matter. It is embedded rather than read from the backup because
  # /home/resources/postoffice is not version-controlled: a fixture that can vanish is a selftest that can
  # go quiet, which is the failure this whole gate exists to refuse.
  _hdr='# 2026-09-13 ceo: MODE cut.'
  _clean_tail='cfo SNOBOL4, the rungs; hq_C PROLOG BREADTH; hq_I SNOCONE, A PER-LANGUAGE LADDER SEAT; hq_T RAKU, A PER-LANGUAGE LADDER SEAT; ceo ICON (and the CEO loop); cto PROLOG, the ISO ladder. THE SEATS: RAKU -- hq_T; PROLOG -- the cto; SNOCONE -- hq_I; SNOBOL4 -- the cfo; PASCAL -- hq_S; ICON -- the ceo'
  _hq_s_clause='hq_S PASCAL, A PER-LANGUAGE LADDER SEAT AND THE PASCAL COMPLETENESS OWNER; the oracle is fpc -Miso. REBUS IS CLOSED (RebRungs 43 of 43 both modes with zero xpass, coo 2026-09-13) and the SNOBOL4 runtime moves to the cfo, so this seat carries Pascal and nothing else'

  printf '%s\n%s; %s; DT_BOOL rides with it. Rebus moves to hq_S. %s; REBUS -- hq_S\n' \
      "$_hdr" "$_hq_s_clause" "$_clean_tail" "CONCERN 2, SPEED: hq_P" > "$sandbox/MODE.dirty"
  printf '%s\n%s; %s; REBUS -- CLOSED, NO OWNER\n' \
      "$_hdr" "$_hq_s_clause" "$_clean_tail" > "$sandbox/MODE.clean"
  # a line 2 that mentions two languages and nothing else -- the empty-grep case
  printf '%s\nTHE SEATS: RAKU -- hq_T; ICON -- the ceo\n' "$_hdr" > "$sandbox/MODE.vacuous"
  printf '%s\n' "$_hdr" > "$sandbox/MODE.noline2"
  # ⛔ THE CONCERN-LANE FIXTURE. Three seats named beside PROLOG, as NONET actually cuts it. This is the
  # fixture the first draft of this gate failed, and it is here to keep the AUTHORITATIVE/MENTION split
  # honest: a lane cut by concern must stay GREEN, or the gate teaches the ceo to flatten the cut.
  printf '%s\ncto PROLOG, the ISO ladder; hq_C PROLOG BREADTH, its nine Logtalk ISO families; hq_R PROLOG BUILTINS AND STREAMS; %s; REBUS -- CLOSED, NO OWNER\n' \
      "$_hdr" "$_clean_tail" > "$sandbox/MODE.concernlanes"
  # ⭐ THE DISCLAIMER CRITERION, PROVED ALONE. Here rebus has exactly ONE owner -- hq_S -- so the rival-owner
  # arm cannot fire, and only the exclusivity clause is left to catch it. Without this fixture the disclaimer
  # code could be dead and every other arm would still pass, which is how a criterion gets shipped untested.
  printf '%s\n%s; %s; REBUS -- hq_S\n' "$_hdr" \
      "$(printf '%s' "$_hq_s_clause" | sed 's/REBUS IS CLOSED (RebRungs 43 of 43 both modes with zero xpass, coo 2026-09-13) and t/T/')" \
      "$_clean_tail" > "$sandbox/MODE.disclaimonly"

  out_d="$(scan_line2 "$sandbox/MODE.dirty" 2>&1)";   rc_d=$?
  out_c="$(scan_line2 "$sandbox/MODE.clean" 2>&1)";   rc_c=$?
  out_v="$(scan_line2 "$sandbox/MODE.vacuous" 2>&1)"; rc_v=$?
  out_n="$(scan_line2 "$sandbox/MODE.noline2" 2>&1)"; rc_n=$?
  out_t="$(scan_line2 "$sandbox/MODE.concernlanes" 2>&1)"; rc_t=$?
  out_x="$(scan_line2 "$sandbox/MODE.disclaimonly" 2>&1)"; rc_x=$?

  check "REDS rc=1 on the real CEO-723 rebus contradiction"          "$rc_d" "1"
  check "  names rebus as the contradicting language"               "$(printf '%s\n' "$out_d" | grep -c '^  rebus .*CONTRADICTION')" "1"
  check "  sees CLOSED and the hq_S assignment as rival OWNERS"     "$(printf '%s\n' "$out_d" | grep -c '^  rebus .*CLOSED/hq_S')" "1"
  check "  cites all three rebus claims, not just the first two"    "$(printf '%s\n' "$out_d" | grep -cE '^      byte .*(IS-CLOSED|SEATS-LIST|MOVES-TO)')" "3"
  check "  prints a byte offset per claim + the disclaimer, so the ceo can cure the law" \
        "$(printf '%s\n' "$out_d" | grep -cE '^      byte [0-9]+')" "4"
  check "  attributes the disclaimer to hq_S, the clause owner, not to a seat named inside it" \
        "$(printf '%s\n' "$out_d" | grep -c '^      byte .*DISCLAIMER *hq_S')" "1"
  check "PASSES rc=0 on the same line with the cross-references cured" "$rc_c" "0"
  check "  and says so without naming rebus as a defect"            "$(printf '%s\n' "$out_c" | grep -c 'CONTRADICTION')" "0"
  check "  still SEES rebus (as CLOSED), it is not silently dropped" "$(printf '%s\n' "$out_c" | grep -c '^  rebus .*CLOSED')" "1"
  # ⛔ THE ANCHOR ARM. MODE.clean carries "the SNOBOL4 runtime moves to the cfo, so this seat carries Pascal
  # and nothing else" -- the cfo is named BETWEEN hq_S and hq_S's own disclaimer. The first draft anchored to
  # the nearest seat token, attributed the disclaimer to the cfo, and reddened SNOBOL4 on a clean line.
  check "  a hand-off DESTINATION between a clause and its disclaimer does not steal the disclaimer" \
        "$(printf '%s\n' "$out_c" | grep -c '^  snobol4 .*CONTRADICTION')" "0"
  check "REFUSES rc=2 when line 2 carries too few OWNER claims to measure" "$rc_v" "2"
  check "  and says NOT a clean verdict rather than printing zero"  "$(printf '%s\n' "$out_v" | grep -c 'NOT a clean verdict')" "1"
  check "REFUSES rc=2 when there is no line 2 at all"               "$rc_n" "2"
  check "THREE seats on one language by CONCERN is GREEN, not a contradiction" "$rc_t" "0"
  check "  and the concern lanes are still REPORTED beside the owner" \
        "$(printf '%s\n' "$out_t" | grep -c '^  prolog .*also worked by .*hq_C')" "1"
  check "the DISCLAIMER criterion reds ALONE, with only one owner and no rival" "$rc_x" "1"
  check "  and says the seat it is handed disclaims it, naming hq_S" \
        "$(printf '%s\n' "$out_x" | grep -c '^  rebus .*hq_S .*disclaims it')" "1"

  # ⭐ BONUS ARM, NON-BLOCKING BY CONSTRUCTION: if the real backup carrying the defect is still on disk, grade
  # the actual historical line rather than the transcription. It is reported, never required -- a selftest
  # that depends on an unversioned file is one `rm` away from passing for the wrong reason.
  _real="$PO/MODE.bak-2026-09-13-2159-ceo736-line2-rebus-and-raku-residue"
  if [ -r "$_real" ]; then
    _ro="$(scan_line2 "$_real" 2>&1)"; _rr=$?
    if [ "$_rr" = "1" ] && printf '%s\n' "$_ro" | grep -q '^  rebus .*CONTRADICTION'; then
      echo "  SELF-TEST OK: the UNEDITED historical MODE backup reds too (rc=1, names rebus) -- not just the transcription"
    else
      echo "  SELF-TEST FAIL: the real backup $_real did not red as rebus (rc=$_rr) -- the embedded fixture may have drifted from it"; st_rc=1
    fi
  else
    echo "  (skipped bonus arm: $_real is not on disk -- the embedded fixture above is the binding proof)"
  fi

  [ "$st_rc" = 0 ] && echo "✅ SELF-TEST PASSED -- the scanner is shown able to say both YES and NO before any live verdict"
  [ "$st_rc" = 0 ] || echo "⛔ SELF-TEST FAILED -- do not trust this gate's verdict on the live MODE"
  exit "$st_rc"
fi

if [ "${1:-}" = "--file" ]; then MODEF="${2:?--file needs a path}"; fi
echo "MODE line 2 self-consistency census -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "  law: $MODEF   (graded against ITSELF -- no second file is consulted, by design)"
scan_line2 "$MODEF"
exit $?
