#!/usr/bin/env bash
# test_gate_pl_a_consulted_file_loads_at_its_directive_so_its_goals_run_before_the_includers_later_ones_as_swipl.sh -- A FILE NAMED BY A consult/ensure_loaded DIRECTIVE IS
# LOADED WHERE THE DIRECTIVE STANDS (hq_prolog 2026-11-01, ProPuzzles p7_miscellaneous: it consults p6_graphs, whose initialization goals print the graph witnesses; swipl
# prints them BEFORE p7's own, SCRIP printed them after).
#
# swipl reads the including file, and at the directive loads the named file in full: its clauses, its directives and its initialization goals are queued ahead of everything
# the including file holds after that line. SCRIP compiled the named file by itself and appended its statements at the END of the including program, so its directives
# and initialization goals ran after the includer's. Now prolog_driver.c pl_splice_consults puts the compiled statements at the row of the directive.
#
# THE ARM, in mode 3 and mode 4, the want cut from swipl 9.0.4 on 2026-11-01: m.pl prints m1, consults h.pl (a directive printing h1, two initialization goals, one reading a
# fact of h.pl), then queues two initialization goals of its own; swipl prints m1 h1 h_init hp(1) m_init m_hp(1). (A consulted file's initialization goal that must run before
# the includer's LATER DIRECTIVES, not only before its initialization goals, is not covered: SCRIP queues every initialization goal to the end of the program.)
# FAIL-ONCE, measured on the parent (SCRIP 40719c97e): m1 h1 m_init m_hp(1) h_init hp(1), in both modes.
# rc=0 equal to swipl · rc=1 a divergence · rc=2 REFUSAL (no build, no gcc).  ~15 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_consulted_file_loads_at_its_directive_so_its_goals_run_before_the_includers_later_ones_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/h.pl" <<'PL'
:- writeln(h1).
hp(1).
:- initialization(writeln(h_init)).
:- initialization((hp(X), writeln(hp(X)))).
PL
cat > "$D/m.pl" <<'PL'
:- writeln(m1).
:- ensure_loaded(h).
:- initialization(writeln(m_init)).
:- initialization((hp(X), writeln(m_hp(X)))).
PL
want="$(printf '%s\n' 'm1' 'h1' 'h_init' 'hp(1)' 'm_init' 'm_hp(1)')"
red=0; arms=0
arm() {
    local label="$1" got
    arms=$((arms+1))
    got="$(cd "$D" && "${@:2}" 2>/dev/null | grep .)"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: equal to swipl"
    else echo "  $label RED: differs from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=$((red+1)); fi
}
arm "m.pl m3" timeout -k 5 60 "$B/scrip" --run m.pl < /dev/null
if ( cd "$D" && timeout -k 5 120 "$B/scrip" --compile --out=m.s m.pl < /dev/null > /dev/null 2>&1 && [ -s m.s ] \
     && gcc -m64 -no-pie m.s -o m.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm "m.pl m4" timeout -k 5 60 ./m.bin < /dev/null
else echo "  m.pl m4 RED: the program did not compile or link in mode 4"; red=$((red+1)); arms=$((arms+1)); fi
echo "PL_CONSULT_AT_DIRECTIVE_BOARD arms=$arms red=$red (tree $(git -C "$B" rev-parse --short HEAD))"
[ "$red" = 0 ] && { echo "GATE OK [$G]: $arms arms equal to swipl"; exit 0; }
echo "GATE FAIL [$G]: $red of $arms arms differ from swipl"; exit 1
