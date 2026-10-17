#!/usr/bin/env bash
# ISO 7.11.1.3 gives max_integer and min_integer existence ONLY when bounded is true. SCRIP answers
# current_prolog_flag(bounded,false) today and ALSO answers max_integer/min_integer -- the second face of the
# same contradiction the bignum-promotion row cures (cto ruling 2026-09-13: BIGNUMS ARE THE TARGET). When
# promotion lands, those two flags must stop existing. swipl, which is already in the cured state, answers
# bounded(false) and has NEITHER flag -- so this gate's own witness is proven to go GREEN on a cured
# implementation and RED on ours, which is what makes it a discriminator and not merely a red.
#
# ⭐ WHAT "ABSENT" MEANS, WIDENED BY THE cto 2026-09-13 WHEN THE CURE WAS WRITTEN, AND WHY IT IS NOT A
# WEAKENING. The gate as minted could only see a flag stop existing as a clean FAILURE, which is swipl's
# shape. It is not the ISO shape and it is not ours: 8.17.2.3 requires domain_error(prolog_flag, Flag) when
# Flag is an atom that is not a valid flag for the processor, and the inriasuite grades us on exactly that --
# `[current_prolog_flag(warning, V), domain_error(prolog_flag,warning)]`. A flag deleted from our table
# therefore RAISES rather than fails, and the minted witness would have read that raise as a crashed witness
# and REFUSED. So absent is now EITHER shape, and the gate still discriminates in both directions: swipl's
# failure takes the GREEN branch unchanged, today's present(9223372036854775807) is RED unchanged, and any
# OTHER error still prints bad(...) and refuses -- a crash can never be read as absence.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSE(2): ./scrip not built -- run make" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
:- initialization(main).
chk(F) :- catch(( current_prolog_flag(F, V) -> write(present(F, V)) ; write(absent(F)) ), E,
                ( E = error(domain_error(prolog_flag, F), _) -> write(absent(F)) ; write(bad(F, E)) )), nl.
main :- ( current_prolog_flag(bounded, B) -> write(bounded(B)) ; write(bounded(missing)) ), nl,
        chk(max_integer), chk(min_integer).
EOF
rc=0
for m in 3 4; do
  if [ "$m" = 3 ]; then out="$(timeout -k 5 20 ./scrip "$W/w.pl" </dev/null 2>&1)"; else
    timeout -k 5 20 ./scrip --compile -o "$W/w.s" "$W/w.pl" </dev/null >"$W/c.log" 2>&1 || { echo "⛔ m$m: compile failed"; cat "$W/c.log"; rc=1; continue; }
    gcc -no-pie "$W/w.s" -Lout -lscrip_rt -Wl,-rpath,"$PWD/out" -lm -lpthread -o "$W/w.bin" >>"$W/c.log" 2>&1 || { echo "⛔ m$m: link failed"; cat "$W/c.log"; rc=1; continue; }
    out="$(timeout -k 5 20 "$W/w.bin" </dev/null 2>&1)"; fi
  bnd="$(printf '%s\n' "$out" | sed -n 's/^bounded(\(.*\))$/\1/p')"
  mx="$(printf '%s\n' "$out" | sed -n 's/^\(present\|absent\)(max_integer.*/\1/p')"
  mn="$(printf '%s\n' "$out" | sed -n 's/^\(present\|absent\)(min_integer.*/\1/p')"
  [ -n "$bnd" ] && [ -n "$mx" ] && [ -n "$mn" ] || { echo "⛔ REFUSE(2): m$m witness did not answer all three lines; out=[$out]" >&2; exit 2; }
  case "$bnd" in
    false) if [ "$mx" = absent ] && [ "$mn" = absent ]; then echo "✅ m$m bounded=false, max_integer/min_integer both absent"
           else echo "⛔ m$m bounded=false but max_integer=$mx min_integer=$mn -- ISO 7.11.1.3 gives them existence only when bounded is true"; rc=1; fi;;
    true)  if [ "$mx" = present ] && [ "$mn" = present ]; then echo "✅ m$m bounded=true, max_integer/min_integer both present"
           else echo "⛔ m$m bounded=true but max_integer=$mx min_integer=$mn -- ISO 7.11.1.3 requires both"; rc=1; fi;;
    *)     echo "⛔ m$m bounded=$bnd is neither true nor false"; rc=1;;
  esac
done
[ "$rc" = 0 ] && echo "GATE GREEN" || echo "GATE RED"
exit $rc
