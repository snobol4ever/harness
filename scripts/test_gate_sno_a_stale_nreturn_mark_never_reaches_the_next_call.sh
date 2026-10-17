#!/usr/bin/env bash
# test_gate_sno_a_stale_nreturn_mark_never_reaches_the_next_call.sh -- the NRETURN mark (rt_g_ret_by_name) describes the most recent return
# and nothing older: every activation clears it at entry (cfo 2026-10-03, row
# snobol4-two-conditional-captures-into-nreturn-targets-in-one-pattern-leave-four-forward-references-unresolved-and-abort-the-process-under-eval).
#
# MEASURED 2026-10-03 on SCRIP 28a05e6fb, both modes: `'x' ? LEN(1) . h(gi(1)) . h(6)` with h NRETURNing .V and gi an ordinary function ABORTED the
# process in the run-time pattern compile -- bb_emit_end: 4 unresolved forward references on n1_match_assign_save_beta / n3_match_assign_cond_beta
# -- where sbl -bf assigns V; the infinite_snobol4 closed world found it through inf_eval.sno (CEO-1489). CAUSE: a by-name call whose callee
# NRETURNs leaves the mark SET for the capture code to read (rt_nret_fix keeps it under SCRIP_CAP_NAME_STRICT), and only the capture consumer
# ever cleared it. h(6) left it set, so the call-site consult after the ARGUMENT call gi(1) misread gi's plain return as an NRETURN, consumed the
# pending by-name request, and h(gi(1)) then ran by value: its NAME was dereferenced to V's value, SNO$PBC built a capture into a nameless
# TT_VAR, and the pattern compiler banked beta labels for boxes it never emitted. The same stale mark turned a later by-value call that RETURNs a
# NAME into a STRING (Y = rn(2) after any by-name statement), turned .h(gi(2)) into a STRING, and lost an immediate capture through h(gi(3)).
# CURE: every activation clears the mark at entry -- the flat park (xa_flat_wn_park_str), the SR activation's WNSAVE (bb_define.cpp) and the C
# road's rt_ab_enter_env -- so the mark at a return is that return's own. Line-neutral in both templates (their bare-poll rows are line-keyed).
# Arms, each in m3 and m4, each stream byte-identical to sbl -bf: A the abort shape and its single-capture and subscript controls; B a by-value
# call that RETURNs a NAME, before and after a by-name statement; C the name operator, a statement subject, both capture forms and a pattern
# variable over a target whose argument is a user call. FAIL_ONCE=1 corrupts arm B's expected stream to prove the comparison trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ REFUSE(2): no sbl at $SBL -- the expected output is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
HDR="        DEFINE('h(x)')                                   :(he)
h       h = .V                                           :(NRETURN)
he      DEFINE('gi(x)')                                  :(gie)
gi      gi = x                                           :(RETURN)
gie     DEFINE('rn(x)')                                  :(rne)
rn      rn = .W                                          :(RETURN)
rne     W = 'wval'"
printf '%s\n%s\nEND\n' "$HDR" "        'x' ? LEN(1) . h(gi(1)) . h(6)                  :S(A1)
        OUTPUT = 'A1 FAIL'                              :(A2)
A1      OUTPUT = 'A1 V=' V
A2      'y' ? LEN(1) . h(gi(2))                         :S(A3)
        OUTPUT = 'A2 FAIL'                              :(A4)
A3      OUTPUT = 'A2 V=' V
A4      'z' ? LEN(1) . h(1) . h(6)
        OUTPUT = 'A3 V=' V" > "$T/a.sno"
printf '%s\n%s\nEND\n' "$HDR" "        X = rn(1)
        OUTPUT = 'B1 ' DATATYPE(X)
        h(1) = 'z'
        Y = rn(2)
        OUTPUT = 'B2 ' DATATYPE(Y) ' V=' V
        'q' ? LEN(1) . h(3)
        Z = rn(3)
        OUTPUT = 'B3 ' DATATYPE(Z) ' V=' V" > "$T/b.sno"
printf '%s\n%s\nEND\n' "$HDR" "        h(gi(1)) = 'z'
        OUTPUT = 'C1 V=' V
        X = .h(gi(2))
        OUTPUT = 'C2 ' DATATYPE(X)
        'q' ? LEN(1) . h(gi(3))
        OUTPUT = 'C3 V=' V
        'r' ? LEN(1) \$ h(gi(3))
        OUTPUT = 'C4 V=' V
        P = LEN(1) . h(gi(4))
        'w' ? P
        OUTPUT = 'C5 V=' V" > "$T/c.sno"
for W in a b c; do ( cd "$T" && "$SBL" -bf $W.sno < /dev/null ) > "$T/$W.ref" 2>&1 || { echo "⛔ REFUSE(2): sbl did not run witness $W"; exit 2; }; done
[ "$(grep -c '^[ABC][0-9]' "$T/a.ref" "$T/b.ref" "$T/c.ref" | awk -F: '{s+=$2} END{print s}')" = 11 ] || { echo "⛔ REFUSE(2): sbl's streams are not the 11 lines this gate expects"; exit 2; }
grep -q '^B2 NAME V=z$' "$T/b.ref" && grep -q '^C2 NAME$' "$T/c.ref" && grep -q '^A1 V=x$' "$T/a.ref" || { echo "⛔ REFUSE(2): sbl's answers are not the ones this gate was cut on"; exit 2; }
RC=0
for M in m3 m4; do
  for W in a b c; do
    if [ "$M" = m4 ]; then ( cd "$T" && "$SCRIP" --compile -o $W.s $W.sno </dev/null && gcc $W.s -o $W.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $W did not build"; exit 2; }; fi
    ( cd "$T" && if [ "$M" = m3 ]; then timeout -k 5 30 "$SCRIP" $W.sno </dev/null; else LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 ./$W.bin </dev/null; fi ) >"$T/$M.$W.out" 2>"$T/$M.$W.err"; echo $? > "$T/$M.$W.rc"
  done
  [ -n "${FAIL_ONCE:-}" ] && sed -i 's/^B2 NAME/B2 NAMEX/' "$T/$M.b.out"
  for W in a b c; do
    if cmp -s "$T/$W.ref" "$T/$M.$W.out"; then echo "  $M arm $(echo $W | tr a-c A-C) PASS (byte-identical to sbl -bf: $(tr '\n' ';' < "$T/$M.$W.out" | cut -c1-90))"
    else echo "  $M arm $(echo $W | tr a-c A-C) FAIL (rc $(cat "$T/$M.$W.rc")): $(diff "$T/$W.ref" "$T/$M.$W.out" | head -4 | tr '\n' '|') $(head -c 160 "$T/$M.$W.err" | tr '\n' '|')"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: no NRETURN mark survives into a later call -- the two-capture shape compiles, a by-value NAME stays a NAME, and a nested argument call never takes the by-name request (3 arms x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a stale NRETURN mark still reaches a later call (examined 3 arms x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $SBL  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
