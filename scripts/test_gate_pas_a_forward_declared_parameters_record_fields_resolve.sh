#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_a_forward_declared_parameters_record_fields_resolve.sh -- a parameter declared ONLY in a `forward`
# heading is in scope for FIELD RESOLUTION in the body (ISO 7185 6.6.1: the body repeats the name and no parameter
# list, and the forward heading's parameters are the body's parameters).
# ⛔ WHY THIS IS NOT COVERED BY test_gate_pas_boolean_write_iso_mod_and_forward_params.sh, WHICH IS GREEN: that gate
# proves a forward-declared parameter ARRIVES, using SCALAR parameters (`n: integer`, `var k: integer`). It is the
# reason this gap reads as covered. The break is narrower -- a RECORD-typed forward parameter, whose `x.field` the
# parser cannot resolve, so it emits a raw TT_FIELD that `lower_pascal.c`'s `default:` arm turns into an IR_GOTO
# USED AS A VALUE. An ordinary local of the identical record type in the identical procedure resolves fine; that
# asymmetry is the defect. FINDING-2026-09-13-hq_S-a-parameter-declared-only-in-a-forward-heading-is-invisible-
# to-field-resolution-so-its-record-fields-read-blank-and-assign-nowhere.md
# ⛔ THE CRASH IS THE SMALL HALF. Only a relop over the field aborts (rc=134, emit_drive guard). A read prints a
# BLANK LINE and an assignment through the var parameter SILENTLY DOES NOTHING, both at rc=0 -- so this gate grades
# OUTPUT against the `fpc -Miso` oracle and never an exit status. A gate here that checked rc would read green.
# ORACLE: fpc -Miso (ISO Pascal is CASE-INSENSITIVE; that is Pascal's rule, not SNOBOL4's).
# EXIT: 0 both witnesses match the oracle in both modes; 1 a mismatch; 2 REFUSED -- cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
refuse() { echo "GATE UNPROVEN(2) [pas-forward-param-record-fields]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no ./scrip at $SCRIP -- run make"
command -v fpc >/dev/null 2>&1 || refuse "no fpc oracle on PATH; this gate grades against fpc -Miso and cannot self-pin"
WD="$(mktemp -d)"; trap 'rm -rf "$WD"' EXIT
cat > "$WD/w0.pas" <<'EOF'
program w0;
type item = record typ: integer end;
var g: item;
procedure p(var x: item);
  var y: item;
begin
  y.typ := 1;
  writeln(x.typ);
  x.typ := 9;
  if x.typ = y.typ then writeln('eq') else writeln('ne')
end;
begin
  g.typ := 1; p(g); writeln(g.typ)
end.
EOF
cat > "$WD/w1.pas" <<'EOF'
program w1;
type item = record typ: integer end;
var g: item;
procedure p(var x: item); forward;
procedure p;
  var y: item;
begin
  y.typ := 1;
  if x.typ = y.typ then writeln('eq') else writeln('ne')
end;
begin
  g.typ := 1; p(g)
end.
EOF
cat > "$WD/w2.pas" <<'EOF'
program w2;
type item = record typ: integer end;
var g: item;
procedure p(var x: item); forward;
procedure p;
begin
  writeln(x.typ);
  x.typ := 9;
  writeln(x.typ)
end;
begin
  g.typ := 4; p(g); writeln(g.typ)
end.
EOF
PASS=0; FAIL=0; GRADED=0; CTRL_FAIL=0
for w in w0 w1 w2; do
    ( cd "$WD" && fpc -Miso "$w.pas" >/dev/null 2>&1 ) || refuse "fpc -Miso refused $w.pas -- the witness must be legal ISO Pascal or this gate grades nothing"
    [ -x "$WD/$w" ] || refuse "fpc produced no executable for $w"
    want="$( cd "$WD" && ./"$w" 2>&1 )"
    for mode in m3 m4; do
        GRADED=$((GRADED+1))
        if [ "$mode" = m3 ]; then got="$( cd "$WD" && timeout -k 5 20s "$SCRIP" "$w.pas" </dev/null 2>&1 )"
        else
            if ! ( cd "$WD" && timeout -k 5 20s "$SCRIP" --compile -o "$w.s" "$w.pas" >/dev/null 2>&1 ); then
                echo "  $w/$mode FAIL: --compile refused (this is the emit_drive guard arm)"; FAIL=$((FAIL+1)); [ "$w" = w0 ] && CTRL_FAIL=$((CTRL_FAIL+1)); continue
            fi
            if ! ( cd "$WD" && gcc -m64 -no-pie "$w.s" -o "$w.x" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1 ); then
                echo "  $w/$mode FAIL: assembling the emitted .s failed"; FAIL=$((FAIL+1)); [ "$w" = w0 ] && CTRL_FAIL=$((CTRL_FAIL+1)); continue
            fi
            got="$( cd "$WD" && timeout -k 5 20s ./"$w.x" </dev/null 2>&1 )"
        fi
        if [ "$got" = "$want" ]; then PASS=$((PASS+1)); else
            FAIL=$((FAIL+1)); [ "$w" = w0 ] && CTRL_FAIL=$((CTRL_FAIL+1))
            echo "  $w/$mode FAIL -- output differs from fpc -Miso"
            diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /' | head -12
        fi
    done
done
[ "$GRADED" -gt 0 ] || refuse "graded zero witness-modes"
# w0 is the CONTROL: the identical program with the parameter list ON THE BODY instead of forward-declared.
# It must PASS, or this gate's own machinery (compile, assemble, diff against fpc) is broken and its reds mean
# nothing -- a stuck-red instrument and a real defect print the same thing.
[ "$CTRL_FAIL" -eq 0 ] || refuse "the CONTROL witness w0 failed ($CTRL_FAIL of 2 modes) -- the harness itself is not measuring; every red below is unproven"
echo "pas-forward-param-record-fields: PASS=$PASS FAIL=$FAIL (population: 3 programs x 2 modes = $GRADED witness-modes, oracle fpc -Miso)"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
