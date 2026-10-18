#!/usr/bin/env bash
# test_gate_sno_a_capture_over_an_alternation_whose_arms_each_capture_reads_its_own_save_cell.sh -- a conditional capture whose captured span holds an alternation whose arms each hold a capture reads its OWN save cell, in both modes.
#
# # ⛔ THE DEFECT (row snobol4-a-capture-of-an-alternation-whose-arms-each-capture-then-a-deferred-call-target-reads-a-corrupt-capture-entry-in-both-modes, found by hq_snocone landing the Pascal Preprocess pattern).
#   ( ( '{$' BREAK('}') . B '}' | '(*$' BREAKX('*') . B '*)' ) . T . *F(B, T) ): the outer capture's save cell is a ζ-SPINE cell read by an rsp-relative offset counted along the main chain.
#   Each arm's capture pushes its own 16-byte save cell and keeps it until the arm backtracks, so on the path through an arm the outer COND read [rsp+16] one cell too high: it read an
#   uninitialised word (the low half of a saved stack pointer) as the capture's start, and rt_dcap_pump refused the entry as CORRUPT CAPTURE ENTRY and skipped the *F call.
#   frame_need_of homed a capture in the frame only when the alternation was the FIRST node of its span (cap_save_cond_gap_has_alt); a capture of a capture of the alternation was missed.
#   THE CURE: cap_save_cond_gap_has_alt walks the span along the main chain and homes the capture in the frame when it meets an alternation whose arms push a spine cell (alt_arms_push).
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 WITNESS: the 8-line pattern over '{$def}' and '{$def}a(*$xyz*)', run 20 times each so the uninitialised word cannot be lucky   -- RED on base
#   3-4  m3 / m4 BARE SHAPE: the same chain over a bare alternation of two captured literals, no ARBNO or FENCE                      -- RED on base
#   5-6  CONTROL m3 / m4: the same pattern with no inner capture in the arms (captureless arms under the outer captures)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_capture_over_an_alternation_whose_arms_each_capture_reads_its_own_save_cell
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/hdr.sno" <<'EOS'
        DEFINE('F(b,t)')                :(FEND)
F       F = .DUMMY
        OUTPUT = 'F [' b '] [' t ']'
                                        :(NRETURN)
FEND
EOS
{ cat "$T/hdr.sno"; cat <<'EOS'
        D = ( ( '{$' BREAK('}') . B '}' | '(*$' BREAKX('*') . B '*)' ) . T . *F(B, T) )
        P = POS(0) ARBNO(FENCE(D | ANY('ab'))) RPOS(0)
        '{$def}' ? P
        '{$def}a(*$xyz*)' ? P
END
EOS
} > "$T/wit.sno"
{ cat "$T/hdr.sno"; cat <<'EOS'
        D = ( ( '{$' BREAK('}') '}' | '(*$' BREAKX('*') '*)' ) . T . *F(T, T) )
        P = POS(0) ARBNO(FENCE(D | ANY('ab'))) RPOS(0)
        '{$def}' ? P
        '{$def}a(*$xyz*)' ? P
END
EOS
} > "$T/ctl.sno"
{ cat "$T/hdr.sno"; cat <<'EOS'
        D = ( ( 'ab' . B | 'cd' . B ) . T . *F(B, T) )
        'ab' ? D
        'cd' ? D
END
EOS
} > "$T/bare.sno"
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want wit; want ctl; want bare
grep -q '^F \[xyz\] \[(\*\$xyz\*)\]$' "$T/wit.want" || refuse "sbl -bf no longer answers the witness as cut"
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
same_m3() { local i; for i in $(seq 20); do timeout -k 5 30 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>&1; cmp -s "$T/$1.want" "$T/$1.m3" || { diff "$T/$1.want" "$T/$1.m3" | head -4 | sed 's/^/      /'; echo "      (run $i of 20)"; return 1; }; done; return 0; }
same_m4() { local i
    timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
        && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null || { echo "      COMPILE-FAILED"; return 1; }
    for i in $(seq 20); do timeout -k 5 30 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>&1; cmp -s "$T/$1.want" "$T/$1.m4" || { diff "$T/$1.want" "$T/$1.m4" | head -4 | sed 's/^/      /'; echo "      (run $i of 20)"; return 1; }; done; return 0; }
same_m3 wit && arm 1 "m3 WITNESS: the outer capture's call fires with the right B and T, 20 runs" 1 || arm 1 "m3 WITNESS: the outer capture's call fires with the right B and T, 20 runs" 0
same_m4 wit && arm 2 "m4 WITNESS: the same, 20 runs" 1 || arm 2 "m4 WITNESS: the same, 20 runs" 0
same_m3 bare && arm 3 "m3 BARE SHAPE: a capture chain over an alternation of two captured literals, 20 runs" 1 || arm 3 "m3 BARE SHAPE: a capture chain over an alternation of two captured literals, 20 runs" 0
same_m4 bare && arm 4 "m4 BARE SHAPE: the same, 20 runs" 1 || arm 4 "m4 BARE SHAPE: the same, 20 runs" 0
same_m3 ctl && arm 5 "CONTROL m3: captureless arms under the outer captures" 1 || arm 5 "CONTROL m3: captureless arms under the outer captures" 0
same_m4 ctl && arm 6 "CONTROL m4: the same" 1 || arm 6 "CONTROL m4: the same" 0
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- the outer capture reads its own save cell across an alternation whose arms capture, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
