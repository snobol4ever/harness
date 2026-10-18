#!/usr/bin/env bash
# test_gate_template_form_choices_outside_lower_only_fall.sh -- A BOX SERVES ONE FORM; THE FORM IS CHOSEN IN LOWER (ceo CEO-1840;
# Lon 2026-10-18, in-chat to the ceo, verbatim: "Will you be able to properly design IR, BB, such that the templates are perfectly
# granular and which has all language specific variances encoded within?" -- "Did those last several template violations ever get
# fixed? That seems part of this mess."). THE ANSWER WAS NO: hq_templates's form census (audit_template_forms.py) read 64 boxes carrying
# more than one live form and 10 IR kinds choosing among boxes inside the emitter -- 74 form choices made outside lower over 132 boxes
# -- and the only gate wired on it proved the census could see a planted two-form box; nothing stopped the count growing. A box that
# chooses its form from a graph flag is exactly where language identity hid past lower (ARCH-IR-CARRIES-EVERY-LANGUAGE-VARIANCE.md
# section 3). THIS GATE is the ratchet: the census's two totals against FLOOR_BOXES and FLOOR_KINDS below; RED above either; a floor
# may only FALL, lowered in the landing that splits a box (one box per form, the form a node kind or attribute the lowerer sets).
# --floor-boxes N / --floor-kinds M override the floors for the fail-once proof (an instrument's own switch, CEO-1680).
# rc 0 at or below both floors, rc 1 above, rc 2 the census cannot run or prints no VERDICT line.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
CENSUS="$HERE/audit_template_forms.py"
[ -f "$CENSUS" ] || { echo "REFUSE(2): no census at $CENSUS"; exit 2; }
FLOOR_BOXES=64; FLOOR_KINDS=10
while [ $# -gt 0 ]; do case "$1" in --floor-boxes) FLOOR_BOXES="$2"; shift;; --floor-kinds) FLOOR_KINDS="$2"; shift;; *) echo "REFUSE(2): unknown argument $1"; exit 2;; esac; shift; done
OUT="$(python3 "$CENSUS" --root "$SCRIP" 2>&1)"
V="$(printf '%s\n' "$OUT" | grep -m1 'VERDICT:')"
[ -n "$V" ] || { echo "REFUSE(2): the census printed no VERDICT line"; printf '%s\n' "$OUT" | tail -3; exit 2; }
BOXES="$(printf '%s\n' "$V" | sed -n 's/.*VERDICT: \([0-9][0-9]*\) box(es).*/\1/p')"
KINDS="$(printf '%s\n' "$V" | sed -n 's/.*, \([0-9][0-9]*\) kind case(s).*/\1/p')"
[ -n "$BOXES" ] && [ -n "$KINDS" ] || { echo "REFUSE(2): could not read the two totals from: $V"; exit 2; }
POP="$(printf '%s\n' "$OUT" | grep -m1 'examined' | sed -n 's/.*(examined \([0-9]*\) boxes).*/\1/p')"
rc=0
[ "$BOXES" -le "$FLOOR_BOXES" ] || rc=1
[ "$KINDS" -le "$FLOOR_KINDS" ] || rc=1
echo "TEMPLATE_FORM_CHOICES boxes_with_more_than_one_form=$BOXES floor=$FLOOR_BOXES kinds_choosing_among_boxes=$KINDS floor=$FLOOR_KINDS boxes_examined=${POP:-?}"
if [ "$rc" = 0 ]; then echo "GATE OK [template_form_choices_outside_lower_only_fall]: no new form choice outside lower; lower a floor in the landing that splits a box"
else echo "GATE RED [template_form_choices_outside_lower_only_fall]: a box gained a form or a kind gained a box choice in the emitter -- split it: one box per form, the form chosen in lower (python3 harness/scripts/audit_template_forms.py names each)"; fi
exit $rc
