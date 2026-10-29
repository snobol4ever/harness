#!/usr/bin/env bash
# test_gate_pl_wall_us_arity1.sh -- CEO-567's precondition: a Prolog kernel must be able to SELF-TIME.
# by_name_dispatch.c registers wall_us/wall_ms at nargs==0 only (function style, the SNOBOL4/Icon
# calling convention). Prolog calls wall_us(T) at ARITY 1 -- a predicate unifying an output argument --
# so every call raises existence_error(procedure,wall_us/1). prelude_swipl.pl's own header states the
# assumption that went unverified: it exists "to supply the self-timing hooks SCRIP has as builtins".
# Under the kernel convention (RULES.md FACT RULE -- THE KERNEL CONVENTION) every kernel self-times, so
# this one shape mismatch blocks the entire Prolog speed axis; it was measured live on 10 of the 23
# corpus/benchmarks/prolog/bench/ kernels, all raising the identical existence_error.
# ⛔ THE ARITY-0 FORM MUST KEEP ANSWERING, AND ITS OWNERS ARE RAKU AND ICON -- NOT SNOBOL4 (coo 2026-09-19,
# row instrument-the-nineteen-non-gc-blocking-arms). This arm previously wrote its witness in SNOBOL4 and
# read FAIL with the subject behaving exactly as built: wall_us has NEVER been in SNOBOL4 scope. It is
# absent from sn4_is_system_fn, no commit in the tree's history ever added it there, and no .sno or .spt
# program in the corpus calls it -- the arity-0 form arrived as a RAKU hook (SCRIP 1b40ea1af) and
# by_name_dispatch.c states the split in its own line: "$wall_us/1 UNIFIES its argument (relational,
# out-parameter), Raku's wall_us() RETURNS a value". So the old arm accused a displacement that never
# happened. The witnesses are now Raku and Icon, the two frontends that DO own the arity-0 form, each
# required to return a positive monotonic microsecond clock, plus a plant proving the arm can say no.
# ⛔ REFUSES rc=2 (never rc=1) when it cannot measure: no ./scrip, no runtime .so, or a witness that
# neither succeeds nor produces the known defect signature -- "could not measure" is not "clean".
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE(2): no ./scrip at $SCRIP"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
:- initialization(main).
main :- wall_us(U), wall_ms(M), ( integer(U) -> write(us_ok) ; write(us_bad) ), nl,
        ( integer(M) -> write(ms_ok) ; write(ms_bad) ), nl.
EOF
fail=0; examined=0
for mode in m3 m4; do
  examined=$((examined+1))
  if [ "$mode" = m3 ]; then out="$(timeout -k 5 20 "$SCRIP" "$W/w.pl" </dev/null 2>&1)"
  else out="$(timeout -k 5 30 "$SCRIP" --compile --out="$W/w.s" "$W/w.pl" </dev/null 2>&1 && cd "$W" && gcc -no-pie w.s -L"$HERE/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"$HERE/../../SCRIP/out" -o w.bin 2>&1 && timeout -k 5 20 ./w.bin </dev/null 2>&1)"; fi
  if printf '%s' "$out" | grep -q 'existence_error(procedure,wall_us/1)'; then
    echo "  FAIL  $mode -- wall_us/1 does not exist: Prolog cannot self-time, so the speed axis cannot be measured at all"; fail=$((fail+1))
  elif printf '%s' "$out" | grep -q 'us_ok' && printf '%s' "$out" | grep -q 'ms_ok'; then
    echo "  ✅ OK  $mode -- wall_us(T) and wall_ms(T) both unify T with an integer"
  else
    echo "⛔ REFUSED-TO-GRADE(2): $mode witness neither self-timed nor produced the known defect -- got: $(printf '%s' "$out" | head -2 | tr '\n' '|')"; exit 2
  fi
done
cat > "$W/a0.raku" <<'EOF'
my $a = wall_us(); my $b = wall_us(); my $m = wall_ms();
say (($a > 0) && ($b >= $a) && ($m > 0) && ($a > $m)) ?? "rk_arity0_ok" !! "rk_arity0_bad";
EOF
examined=$((examined+1))
a0rk="$(timeout -k 5 20 "$SCRIP" "$W/a0.raku" </dev/null 2>&1)"
if printf '%s' "$a0rk" | grep -q 'rk_arity0_ok'; then echo "  ✅ OK  arity-0 wall_us()/wall_ms() answer in Raku, positive and monotonic"
else echo "  FAIL  the arity-0 form stopped answering in RAKU, the frontend that introduced it -- got: $(printf '%s' "$a0rk" | head -2 | tr '\n' '|')"; fail=$((fail+1)); fi

cat > "$W/a0.icn" <<'EOF'
procedure main()
	a := wall_us(); b := wall_us(); m := wall_ms();
	if (a > 0) & (b >= a) & (m > 0) & (a > m) then write("ic_arity0_ok") else write("ic_arity0_bad");
end
EOF
examined=$((examined+1))
a0ic="$(timeout -k 5 20 "$SCRIP" "$W/a0.icn" </dev/null 2>&1)"
if printf '%s' "$a0ic" | grep -q 'ic_arity0_ok'; then echo "  ✅ OK  arity-0 wall_us()/wall_ms() answer in Icon, positive and monotonic"
else echo "  FAIL  the arity-0 form stopped answering in ICON -- got: $(printf '%s' "$a0ic" | head -2 | tr '\n' '|')"; fail=$((fail+1)); fi

cat > "$W/plant.icn" <<'EOF'
procedure main()
	write(wall_us_absent());
end
EOF
examined=$((examined+1))
plant="$(timeout -k 5 20 "$SCRIP" "$W/plant.icn" </dev/null 2>&1)"
if printf '%s' "$plant" | grep -qE '[0-9]{6}'; then
	echo "  FAIL  THE PLANT ANSWERED: an undefined wall_us_absent() produced a clock value, so these arms cannot tell answering from not answering"; fail=$((fail+1))
else echo "  ✅ OK  plant: an undefined arity-0 name does NOT answer, so the arms above can say no"; fi
echo "------------------------------------------------------------"
[ "$examined" -eq 5 ] || { echo "⛔ REFUSED-TO-GRADE(2): examined=$examined, expected 3"; exit 2; }
if [ "$fail" -eq 0 ]; then echo "✅ GATE OK: 5 of 5 -- Prolog kernels can self-time, the Raku and Icon arity-0 forms are intact, and the plant proves the arms can say no"; exit 0; fi
echo "⛔ GATE FAIL: $fail of $examined check(s) failed"; exit 1
