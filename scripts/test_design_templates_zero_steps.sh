#!/usr/bin/env bash
# test_design_templates_zero_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: templates-zero (the cto, 2026-11-01, R-2095;
# .github/ARCH-CALL-FORMS.md section 9). The plan is corpus/tests/shared/templates_zero/STEPS.tsv. A step's measurement is its PROBE over the
# SCRIP tree (the per-file template audit, a symbol census, a kind's dispatch, the pipeline order, the whole-set census) and its WITNESSES:
# master entries named <lang>:<entry>, each graded in both modes by corpus_suite_harness.py run --partition entry:<entry> (a handful of named
# entries is any seat's own test, never a board, R-1893).
#
#   --list       print the steps and run nothing
#   --step N     run step N's probe tokens, then grade its witnesses in both modes
#   --probe N    run step N's probe tokens only (no witness runs; the reading a landing quotes before its smokes)
#   --out DIR    where the witness runs go (default /tmp/s4e-templates_zero-<uid>)
#
# probe tokens (STEPS.tsv column 5): audit=f,g | classes=f:cls=0,cls<=N | nocall=sym,sym:bb|xa|all|lower|runtime | after=A:B (every call of B* under src has A within the 8 lines above) | nosym=sym,sym:all | sym=sym,sym |
#   kinds=IR_X,IR_Y | gone=f:entry | order=a,b,c | grand=N | -   (each defined in the table's header comment)
# VERDICT: STEP N <slug>: probe=<token:reading ...> m3=<pass>/<n> m4=<pass>/<n> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/shared/templates_zero"
STEPS="$WD/STEPS.tsv"
OUT="/tmp/s4e-templates_zero-$(id -u)"
AUDIT="$HERE/audit_bb_fixup_file.sh"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --probe) mode=probe; step="${2:-}"; [ -n "$step" ] || refuse "--probe takes a number"; shift 2 ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N | --probe N [--out DIR]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N | --probe N [--out DIR]"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: templates-zero -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses are master entries graded by corpus_suite_harness.py"
    printf '%-4s %-52s %-8s %-8s %s\n' step slug executor depends probe
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-52s %-8s %-8s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 5 | cut -c1-90)"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
[ -d "$SC/src/templates" ] || refuse "no SCRIP/src/templates beside this harness"
[ -x "$AUDIT" ] || refuse "no per-file audit at $AUDIT"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
readings=""; red=0
note() { readings="$readings $1"; }
audit_file() { ( cd "$SC" && bash "$AUDIT" "src/templates/$1" > /dev/null 2>&1 ); }
audit_class() { ( cd "$SC" && bash "$AUDIT" "src/templates/$1" 2>/dev/null ) | awk -v c="$2" '$1 == c {for (i = NF; i >= 2; i--) if ($i ~ /^[0-9]+$/) {print $i; exit}}'; }
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    case "$tok" in
        audit=*) for f in $(echo "${tok#audit=}" | tr ',' ' '); do
                     if [ ! -f "$SC/src/templates/$f" ]; then note "audit:$f=MISSING"; red=1
                     elif audit_file "$f"; then note "audit:$f=clean"; else note "audit:$f=dirty"; red=1; fi; done ;;
        classes=*) spec="${tok#classes=}"; f="${spec%%:*}"; [ -f "$SC/src/templates/$f" ] || refuse "classes: no file $f"
                   for c in $(echo "${spec#*:}" | tr ',' ' '); do
                       if echo "$c" | grep -q '<='; then name="${c%%<=*}"; want="${c#*<=}"; op=le; else name="${c%%=*}"; want="${c#*=}"; op=eq; fi
                       v="$(audit_class "$f" "$name")"; [ -n "$v" ] || refuse "classes: the audit prints no class $name for $f"
                       if { [ $op = eq ] && [ "$v" -eq "$want" ]; } || { [ $op = le ] && [ "$v" -le "$want" ]; }; then note "$name=$v"; else note "$name=$v!"; red=1; fi; done ;;
        nocall=*) spec="${tok#nocall=}"; syms="${spec%%:*}"; where="${spec#*:}"
                  case "$where" in bb) dirs="$SC/src/templates/bb";; xa) dirs="$SC/src/templates/xa";; all) dirs="$SC/src/templates";; lower) dirs="$SC/src/lower";; runtime) dirs="$SC/src/runtime";; *) refuse "nocall: where is $where";; esac
                  for s in $(echo "$syms" | tr ',' ' '); do n=$(grep -rl --include='*.c' --include='*.cpp' --include='*.h' "\b$s\b" $dirs 2>/dev/null | grep -v '/bb_templates.h$' | wc -l)
                      if [ "$n" = 0 ]; then note "nocall:$s=0"; else note "nocall:$s=$n!"; red=1; fi; done ;;
        nosym=*) spec="${tok#nosym=}"; syms="${spec%%:*}"
                 for s in $(echo "$syms" | tr ',' ' '); do n=$(grep -rl --include='*.c' --include='*.cpp' --include='*.h' "\b$s\b" "$SC/src" 2>/dev/null | wc -l)
                     if [ "$n" = 0 ]; then note "nosym:$s=0"; else note "nosym:$s=$n!"; red=1; fi; done ;;
        sym=*) for s in $(echo "${tok#sym=}" | tr ',' ' '); do
                   if grep -rq --include='*.c' --include='*.cpp' "^[A-Za-z_][A-Za-z0-9_ *\"]*[ *]$s(" "$SC/src" 2>/dev/null; then note "sym:$s=defined"; else note "sym:$s=undefined!"; red=1; fi; done ;;
        kinds=*) for k in $(echo "${tok#kinds=}" | tr ',' ' '); do
                     nm=$(grep -c "\[$k\] = \"$k\"" "$SC/src/ir/scrip_ir.c" 2>/dev/null)
                     own="bb_$(echo "$k" | sed 's/^IR_//' | tr 'A-Z' 'a-z')"
                     span=$(awk -v k="case $k:" '$0 ~ k {p=1; print; next} p && /^    case / {p=0} p' "$SC/src/emitter/emit.cpp" 2>/dev/null)
                     first=$(echo "$span" | grep -o 'bb_emit_x86(bb_[a-z0-9_]*' | head -1 | sed 's/bb_emit_x86(//')
                     boxes=$(echo "$span" | grep -o 'bb_emit_x86(bb_[a-z0-9_]*' | sort -u | wc -l)
                     twins=$(echo "$probe" | tr ' ' '\n' | grep -c "^twin=$k:")
                     cases=$(grep -c -E "case $k:" "$SC/src/emitter/emit.cpp" 2>/dev/null)
                     if [ "$nm" = 1 ] && [ "$first" = "$own" ] && [ "$boxes" = $((1 + twins)) ] && [ "$cases" -ge 1 ]; then note "kind:$k=$own${twins:++$twins}"; else note "kind:$k=named$nm/first${first:-none}/boxes$boxes!"; red=1; fi; done ;;
        twin=*) spec="${tok#twin=}"; k="${spec%%:*}"; b="${spec#*:}"
                n=$(awk -v k="case $k:" '$0 ~ k {p=1; print; next} p && /^    case / {p=0} p' "$SC/src/emitter/emit.cpp" 2>/dev/null | grep -c "bb_emit_x86($b(")
                if [ "$n" -ge 1 ]; then note "twin:$k=$b"; else note "twin:$k=$b-missing!"; red=1; fi ;;
        gone=*) spec="${tok#gone=}"; f="${spec%%:*}"; e="${spec#*:}"
                if [ -f "$SC/src/templates/$f" ]; then note "gone:$f=present!"; red=1
                elif grep -q "$e()" "$SC/src/emitter/emit.cpp" "$SC/src/templates/bb/bb_templates.h" 2>/dev/null; then note "gone:$f=named!"; red=1
                else note "gone:$f=gone"; fi ;;
        order=*) a="$(echo "${tok#order=}" | cut -d, -f1)"; b="$(echo "${tok#order=}" | cut -d, -f2)"; c="$(echo "${tok#order=}" | cut -d, -f3)"
                 drv="$SC/src/driver/scrip.c"; bad=0; nb=0
                 for ln in $(grep -n "$b(s2" "$drv" | cut -d: -f1); do nb=$((nb + 1))
                     sed -n "$((ln > 8 ? ln - 8 : 1)),$((ln - 1))p" "$drv" | grep -q "$a(s2" || bad=$((bad + 1))
                     sed -n "$((ln + 1)),$((ln + 8))p" "$drv" | grep -q "$c(s2" || bad=$((bad + 1)); done
                 [ "$nb" -gt 0 ] || refuse "order: $b is called nowhere in scrip.c"
                 if [ "$bad" = 0 ]; then note "order:$nb-sites-ok"; else note "order:$bad-of-$nb-sites-out-of-order!"; red=1; fi ;;
        after=*) a="${tok#after=}"; a="${a%%:*}"; b="${tok#*:}"; nb=0; bad=0
                 for hit in $(grep -rnP --include='*.c' --include='*.cpp' "\b$b[_a-z]*\((?!(IR_graph_t|stage2_t|const|void|struct))" "$SC/src" | grep -v '^[^:]*:[0-9]*:\(void\|int\|static\) \|^[^:]*/src/planner/' | cut -d: -f1,2); do nb=$((nb + 1)); f="${hit%%:*}"; ln="${hit##*:}"
                     sed -n "$((ln > 8 ? ln - 8 : 1)),$((ln - 1))p" "$f" | grep -q "$a" || { bad=$((bad + 1)); note "after:$(basename "$f"):$ln!"; }; done
                 [ "$nb" -gt 0 ] || { note "after:$b=0-sites!"; bad=$((bad + 1)); }
                 if [ "$bad" = 0 ]; then note "after:$nb-sites-ok"; else red=1; fi ;;
        grand=*) g=$(cd "$SC" && bash "$HERE/audit_bb_fixup_rank.sh" 2>/dev/null | awk '/GRAND TOTAL/ {print $NF}'); [ -n "$g" ] || refuse "grand: the rank audit printed no GRAND TOTAL"
                 if [ "$g" -le "${tok#grand=}" ]; then note "grand=$g"; else note "grand=$g!"; red=1; fi ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
m3p=0; m4p=0; n=0; reds=""
if [ "$mode" = step ] && [ "$wits" != "-" ]; then
    [ -x "$SC/scrip" ] || refuse "no $SC/scrip to grade the witnesses"
    mkdir -p "$OUT/step$step"
    for w in $wits; do
        lang="${w%%:*}"; e="${w#*:}"; n=$((n + 1))
        ext=$(awk -F'\t' -v l="$lang" '$1 == l {print $2}' <<'TSV'
snobol4	sno
prolog	pl
icon	icn
pascal	pas
raku	raku
snocone	sc
rebus	reb
TSV
)
        [ -n "$ext" ] || refuse "witness $w: no extension for language $lang"
        log="$OUT/step$step/$lang.$e.log"
        ( cd "$SC" && S4E_DONE_WHEN_RUN=1 timeout -k 5 900 python3 "$HERE/corpus_suite_harness.py" run "$ROOT/corpus/tests/$lang/ALL.$ext" "$ROOT/corpus/tests/$lang/ALL.ref" --lang "$lang" --modes m3,m4 --partition "entry:$e" > "$log" 2>&1 )
        board="$(grep '^SUITE_BOARD ' "$log" | tail -1)"
        [ -n "$board" ] || { reds="$reds $w(no-board)"; continue; }
        p3="$(echo "$board" | grep -o 'm3_pass=[0-9]*' | cut -d= -f2)"; p4="$(echo "$board" | grep -o 'm4_pass=[0-9]*' | cut -d= -f2)"
        [ "${p3:-0}" = 1 ] && m3p=$((m3p + 1)) || reds="$reds m3:$w"
        [ "${p4:-0}" = 1 ] && m4p=$((m4p + 1)) || reds="$reds m4:$w"
    done
fi
verdict=GREEN; [ "$red" = 1 ] && verdict=RED; [ -n "$reds" ] && verdict=RED
echo "STEP $step $slug: probe=${readings# } m3=$m3p/$n m4=$m4p/$n -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0; exit 1
