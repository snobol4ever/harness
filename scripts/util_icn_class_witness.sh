#!/usr/bin/env bash
# util_icn_class_witness.sh -- ONE runnable, oracle-anchored acceptance witness per open hq_I Icon class row.
#
# WHY THIS EXISTS (ceo 19:02 2026-09-05, "placeholder-done-whens-in-your-lane-16-rows-unpickable"): sixteen FREE
# rows in the hq_I lane carried the MINT PLACEHOLDER as their DONE-WHEN, and since mint-dispatch-refuses-a-
# placeholder-done-when landed the picker will not serve them -- they were invisible work. Each row's DONE-WHEN
# is now one line, "bash ../harness/scripts/util_icn_class_witness.sh <slug>", instead of sixteen bespoke heredocs that
# would drift apart the way the seven ladder copies did before lib_ladder.sh (ONE template, never N copies).
#
# CONTRACT: rc=0 the class is CURED (SCRIP matches the live icont oracle byte-for-byte in BOTH modes), rc=1 the
# class is LIVE (it diverges), rc=2 UNPROVEN (no oracle, no fresh binary, unknown slug, or a witness the oracle
# itself cannot build -- never printed as either answer). Grading is by VALUE against the oracle, never by rc:
# most of these classes abort at rc=0 or return a wrong answer at rc=0, so an exit-code check reads them clean.
#
# ⛔ EVERY WITNESS BELOW WAS PROVEN RED THE DAY IT WAS WRITTEN (hq_I 2026-09-05, SCRIP f3f8e252b). A slug that
# reads rc=0 here has been CURED since -- close its row, do not assume the witness rotted.
#
# ⛔ ONE SLUG SHIPS GREEN ON PURPOSE: icon-jcon-chained-swap-lvalue-not-handled reads rc=0 CURED today. It was
# red this morning (x :=: y :=: z aborted rc=134 on the bb_varslot_peek sink inside IR_SWAP's own case) and was
# cured by another lane in the interim. It is kept here as the standing regression witness, and it is the
# mixed variable/list-slot shape rather than the all-variable one BECAUSE the list slot is the operand that
# actually sank -- four shapes were graded before closing the row (3-way, 4-way, all-list-slot, mixed), all
# green in both modes, rather than closing on the first one that passed.
#
# ⭐ ONE WITNESS IS NOT A CLASS, AND THIS FILE EXISTS BECAUSE THAT NEARLY COST A LIVE ROW. The first cset-NUL
# witness written for this file, image(cset(char(0))), reads GREEN today -- and the row is NOT cured: the very
# next shape, cset(char(0) ++ "ab"), still drops the NUL member (oracle '\x00ab' size 3, SCRIP 'ab' size 2).
# Closing that row off the passing witness would have retired a live defect with a receipt saying it was fixed.
# Where a class has a passing neighbour, the witness here is the one that FAILS and the neighbour is kept
# beside it, so the next reader sees the boundary instead of rediscovering it.
#
# ⭐ IT HAPPENED A SECOND TIME IN THE SAME SITTING, which is why this is a rule and not an anecdote. The
# sortf witness first written here used the FOUR-element mix its row's own GOAL describes (two record types,
# a plain list, an integer) and read GREEN in both modes. Widening the same call to nine elements across nine
# types reads RED and badly -- the oracle sorts 7 3.5 "str" 'abc' list set table ra rb, SCRIP sorts
# 3.5 7 set table 'abc' list ra rb "str". A cross-type ORDER defect is invisible to any mix too narrow to
# contain the pair that is out of order, so a heterogeneous-compare witness must span types, not count them.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" || { echo "UNPROVEN(2): lib_oracle_flags.sh unavailable"; exit 2; }

witness_for() {
    case "$1" in
    icon-arizona-class-cset-cannot-represent-nul-member) cat <<'W'
procedure main()
   local c;
   c := cset(char(0) ++ "ab");
   write(image(c));
   write(*c);
end
W
;;
    icon-arizona-class-table-iteration-order-not-insertion|icon-key-table-iteration-order-differs-from-arizona-oracle) cat <<'W'
procedure main()
   local t, k;
   t := table();
   t["z"] := 1; t["a"] := 2; t["m"] := 3;
   every k := key(t) do writes(k, " ");
   write();
end
W
;;
    icon-arizona-class-swap-list-slot-record-field-fails) cat <<'W'
procedure main()
   local r;
   r := rec([10, 20], 99);
   r[1] :=: r.d;
   write(image(r[1]), " ", image(r.d));
end
record rec(a, d)
W
;;
    icon-ipl-system-builtin-unimplemented-error-005) cat <<'W'
procedure main()
   system("echo hi");
end
W
;;
    icon-ipl-open-pipe-mode-p-silently-produces-no-error-and-no-output) cat <<'W'
procedure main()
   local p;
   p := open("echo hello", "p") | stop("no pipe");
   while write(read(p));
   close(p);
end
W
;;
    icon-ipl-error-scoped-runerr-aborts-instead-of-failing) cat <<'W'
procedure main()
   local r;
   r := trap();
   write("after: ", image(r));
end
procedure trap()
   return 1 / 0;
end
W
;;
    icon-ipl-date-format-extra-space-before-single-digit-day) cat <<'W'
procedure main()
   write(&dateline);
end
W
;;
    icon-jcon-class-display-builtin-unimplemented) cat <<'W'
procedure main()
   local x;
   x := 1;
   display();
end
W
;;
    icon-jcon-class-sort-zero-field-record-throws-undefined-function) cat <<'W'
procedure main()
   write(image(sort(r0())));
end
record r0()
W
;;
    icon-jcon-class-sortf-heterogeneous-type-default-compare-throws) cat <<'W'
procedure main()
   local L, x;
   L := [ra(1), rb("s"), [1,2], 7, "str", set([1]), table(), 3.5, 'abc'];
   every x := !sortf(L, &null) do writes(image(x), " ");
   write();
end
record ra(p)
record rb(q)
W
;;
    icon-jcon-class-omitted-leading-arg-not-null-coerced-to-builtin-default) cat <<'W'
procedure main()
   local x, n;
   n := 0;
   every x := seq(, 4) do { writes(x, " "); n +:= 1; if n >= 4 then break };
   write();
end
W
;;
    icon-jcon-class-set-table-serial-numbering-diverges-from-oracle) cat <<'W'
procedure main()
   local s, t, L;
   s := set(); t := table(); L := [];
   write(image(s)); write(image(t)); write(image(L));
end
W
;;
    icon-jcon-class-undefined-curly-call-activates-coexpr-with-garbage-target) cat <<'W'
procedure main()
   pairs { 1 to 4, 11 to 44 by 11 };
end
W
;;
    icon-jcon-misc-coexpr-activate-corrupted-target-pointer-segv) cat <<'W'
procedure main()
   pairs { 1 to 3, 11 to 33 by 11 };
end
procedure pairs(e)
   while write(@e[1], " ", @e[2]);
end
W
;;
    icon-jcon-chained-swap-lvalue-not-handled) cat <<'W'
procedure main()
   local x, L;
   x := 9; L := [1, 2];
   x :=: L[1] :=: L[2];
   write(x, " ", L[1], " ", L[2]);
end
W
;;
    icon-ipl-function-builtin-unimplemented) cat <<'W'
procedure main()
   local x;
   x := function();
   write(x);
end
W
;;
    icon-ipl-toktab-default-options-invalid-sort-order) cat <<'W'
procedure main()
   local r;
   r := f();
   write(r);
end
procedure f(x)
   local s;
   s := case x of {
      "incr" | &null: "matched-null-or-incr";
      "decr": "matched-decr";
      default: "NO-MATCH"
   };
   return s;
end
W
;;
    icon-bal-generator-yields-one-result-not-a-backtracking-sequence) cat <<'W'
procedure main()
   local s;
   s := "(AB) ";
   s ? every write(image(tab(bal())));
end
W
;;
    *) return 1;;
    esac
}

SLUGS="icon-arizona-class-cset-cannot-represent-nul-member icon-arizona-class-table-iteration-order-not-insertion icon-key-table-iteration-order-differs-from-arizona-oracle icon-arizona-class-swap-list-slot-record-field-fails icon-ipl-system-builtin-unimplemented-error-005 icon-ipl-open-pipe-mode-p-silently-produces-no-error-and-no-output icon-ipl-error-scoped-runerr-aborts-instead-of-failing icon-ipl-date-format-extra-space-before-single-digit-day icon-jcon-class-display-builtin-unimplemented icon-jcon-class-sort-zero-field-record-throws-undefined-function icon-jcon-class-sortf-heterogeneous-type-default-compare-throws icon-jcon-class-omitted-leading-arg-not-null-coerced-to-builtin-default icon-jcon-class-set-table-serial-numbering-diverges-from-oracle icon-jcon-class-undefined-curly-call-activates-coexpr-with-garbage-target icon-jcon-misc-coexpr-activate-corrupted-target-pointer-segv icon-jcon-chained-swap-lvalue-not-handled icon-ipl-function-builtin-unimplemented icon-ipl-toktab-default-options-invalid-sort-order icon-bal-generator-yields-one-result-not-a-backtracking-sequence"

if [ "${1:-}" = "--list" ]; then for s in $SLUGS; do echo "$s"; done; exit 0; fi
if [ $# -lt 1 ]; then echo "UNPROVEN(2): usage: util_icn_class_witness.sh <class-slug> | --list"; exit 2; fi
SLUG="$1"
ICONT="$(icont_bin)" || exit 2
[ -x "$ROOT/scrip" ] || { echo "UNPROVEN(2) [$SLUG]: no $ROOT/scrip binary"; exit 2; }
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
if ! witness_for "$SLUG" > "$T/w.icn"; then
    echo "UNPROVEN(2): unknown class slug '$SLUG' -- run --list for the ones this runner knows"; exit 2
fi
( cd "$T" && timeout -k 5 30s "$ICONT" -s -o w.oracle w.icn >/dev/null 2>&1 ) && [ -x "$T/w.oracle" ] \
    || { echo "UNPROVEN(2) [$SLUG]: icont could not build the witness, so there is no oracle answer to grade against"; exit 2; }
( cd "$T" && timeout -k 5 15s ./w.oracle </dev/null >ref 2>&1 )
( cd "$T" && timeout -k 5 15s "$ROOT/scrip" w.icn </dev/null >m3 2>&1 )
m4="(m4 not built)"
if ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile --out=w.s w.icn </dev/null >/dev/null 2>&1 ) \
   && ( cd "$T" && gcc -no-pie w.s -o w.m4bin -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ); then
    ( cd "$T" && timeout -k 5 15s ./w.m4bin </dev/null >m4 2>&1 ); m4="$(tr '\n' '|' < "$T/m4")"
else
    printf 'M4-BUILD-FAILED\n' > "$T/m4"; m4="M4-BUILD-FAILED"
fi
ok3=0; ok4=0
# ONE ERROR VOICE (RULES.md, CEO-623/625): SCRIP prints its own error shape, so each mode is graded THROUGH the renderer against the oracle's text
python3 "$HERE/util_render_error_voice.py" icon < "$T/m3" > "$T/m3r" || { echo "UNPROVEN(2) [$SLUG]: the error-voice renderer refused the m3 output"; exit 2; }
python3 "$HERE/util_render_error_voice.py" icon < "$T/m4" > "$T/m4r" || { echo "UNPROVEN(2) [$SLUG]: the error-voice renderer refused the m4 output"; exit 2; }
cmp -s "$T/ref" "$T/m3r" && ok3=1
cmp -s "$T/ref" "$T/m4r" && ok4=1
printf 'class  : %s\n' "$SLUG"
printf 'oracle : %s\n' "$(tr '\n' '|' < "$T/ref")"
printf 'scrip m3: %s\n' "$(tr '\n' '|' < "$T/m3")"
printf 'scrip m4: %s\n' "$m4"
if [ "$ok3" = 1 ] && [ "$ok4" = 1 ]; then
    echo "CURED(0) [$SLUG]: SCRIP matches the icont oracle byte-for-byte in BOTH modes -- close the row"
    exit 0
fi
echo "LIVE(1) [$SLUG]: m3 matches=$ok3 m4 matches=$ok4 -- the class is still open"
exit 1
