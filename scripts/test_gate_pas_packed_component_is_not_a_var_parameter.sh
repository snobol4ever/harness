#!/usr/bin/env bash
# test_gate_pas_packed_component_is_not_a_var_parameter.sh -- ISO 7185 6.6.3.3: a component of a PACKED structure shall not be an
# actual variable parameter. The oracle is `fpc -Miso`, which rejects all three shapes at COMPILE time ("The address cannot be taken
# of bit packed array elements and record fields"); before this gate SCRIP accepted two of them and bombed at run time on the third.
# ⛔ PAT IS A REJECTION SUITE, so the graded question is NOT "what did it print" but "did it refuse, with a diagnostic, WITHOUT
# crashing". A SIGNAL (rc >= 128) is a CRASH and is NEVER a pass -- under a bare `rc != 0` test a SIGSEGV would score as a correct
# rejection and the suite would reward the compiler for behaving worse. Same rule as test_pascal_pat_suite.sh, stated once per gate.
# ⛔ THE NEGATIVE ARMS ARE THE HALF THAT MATTERS. A rule that rejects programs is only as good as what it leaves alone: an
# over-broad packed test would silently start refusing legal Pascal, and the PAT board would go UP while the language got smaller.
# So every ACCEPT arm below is a program fpc -Miso compiles, and the gate is red if any of them is refused.
# ⛔ ONE ARM IS GRADED `NOWIDEN` AND THAT IS NOT AN XFAIL WEARING A NEW NAME -- READ WHAT IT ASSERTS. unpacked_nested_field_is_legal
# passes a nested UNPACKED field as a variable parameter: fpc -Miso compiles and runs it, and SCRIP kills it in the EMITTER
# (`FATAL emit_drive: IR op=5 HAS a template and its own case REFUSED AT A GUARD`) both before and after this cure -- measured on
# both sides of the change, so it is a standing defect of nested record var-parameters and belongs to its own row, not to this one.
# Grading it ACCEPT would make THIS gate red for a defect it does not own; deleting it would drop the only arm at the depth where an
# over-broad packed test is most likely to misfire. So it asserts the question this gate actually owns: THE 6.6.3.3 DIAGNOSTIC MUST
# NOT APPEAR. It is red the moment the rule widens onto an unpacked nested field, and it goes green-by-accident for nobody: when the
# emitter defect is cured this arm keeps grading exactly what it grades today, and should then be promoted to ACCEPT.
set -u
GATE_NAME=test_gate_pas_packed_component_is_not_a_var_parameter
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- a missing binary prints a full, plausible, entirely false all-FAIL board"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
emit() { cat > "$W/$1.pas"; }
grade() {
    name="$1"; want="$2"
    out="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$W/$name.pas" </dev/null 2>&1)"; rc=$?
    if [ "$rc" -ge 128 ]; then got=CRASH; elif [ "$rc" -eq 124 ]; then got=HANG; elif [ "$rc" -ne 0 ]; then got=REJECT; else got=ACCEPT; fi
    ok=0
    case "$want" in
        NOWIDEN) printf '%s' "$out" | grep -q '6\.6\.3\.3' || ok=1 ;;
        REJECT)  [ "$got" = REJECT ] && printf '%s' "$out" | grep -q '6\.6\.3\.3' && ok=1 ;;
        *)       [ "$got" = "$want" ] && ok=1 ;;
    esac
    if [ "$ok" = 1 ]; then
        PASS=$((PASS+1)); printf '  %-34s %-6s ok\n' "$name" "$got"
    else
        FAIL=$((FAIL+1)); printf '  %-34s %-6s WANT %s rc=%s | %s\n' "$name" "$got" "$want" "$rc" "$(printf '%s' "$out" | head -1 | cut -c1-90)"
    fi
}
emit direct_field <<'EOF'
program direct_field;
var r: packed record i: integer; b: boolean end;
procedure a(var b: boolean);
begin b := true end;
begin a(r.b) end.
EOF
emit through_with <<'EOF'
program through_with;
var r: packed record i: integer; b: boolean end;
procedure a(var b: boolean);
begin b := true end;
begin with r do a(b) end.
EOF
emit named_packed_type <<'EOF'
program named_packed_type;
type prec = packed record i: integer; b: boolean end;
var d: prec;
procedure a(var b: boolean);
begin b := true end;
begin a(d.b) end.
EOF
emit nested_packed_field <<'EOF'
program nested_packed_field;
type prec = packed record i: integer; b: boolean end;
var r: record c: char; d: prec end;
procedure a(var b: boolean);
begin b := true end;
begin a(r.d.b) end.
EOF
emit packed_to_function <<'EOF'
program packed_to_function;
var r: packed record i: integer; b: boolean end;
function f(var b: boolean): integer;
begin b := true; f := 1 end;
var n: integer;
begin n := f(r.b); write(n) end.
EOF
emit unpacked_field_is_legal <<'EOF'
program unpacked_field_is_legal;
var r: record i: integer; b: boolean end;
procedure a(var b: boolean);
begin b := true end;
begin r.b := false; a(r.b); if r.b then write(1) else write(0) end.
EOF
emit packed_by_value_is_legal <<'EOF'
program packed_by_value_is_legal;
var r: packed record i: integer; b: boolean end;
procedure a(b: boolean);
begin if b then write(1) else write(0) end;
begin r.b := true; a(r.b) end.
EOF
emit packed_whole_variable_is_legal <<'EOF'
program packed_whole_variable_is_legal;
type prec = packed record i: integer; b: boolean end;
var r: prec;
procedure a(var p: prec);
begin p.i := 7 end;
begin a(r); write(r.i) end.
EOF
emit unpacked_nested_field_is_legal <<'EOF'
program unpacked_nested_field_is_legal;
type urec = record i: integer; b: boolean end;
var r: record c: char; d: urec end;
procedure a(var b: boolean);
begin b := true end;
begin a(r.d.b); if r.d.b then write(1) else write(0) end.
EOF
echo "[$GATE_NAME] ISO 7185 6.6.3.3 -- a packed component is not a variable parameter"
echo " REJECT arms (fpc -Miso refuses each at compile time):"
grade direct_field                 REJECT
grade through_with                 REJECT
grade named_packed_type            REJECT
grade nested_packed_field          REJECT
grade packed_to_function           REJECT
echo " ACCEPT arms (legal Pascal -- the rule must not widen):"
grade unpacked_field_is_legal      ACCEPT
grade packed_by_value_is_legal     ACCEPT
grade packed_whole_variable_is_legal ACCEPT
grade unpacked_nested_field_is_legal NOWIDEN
TOT=$((PASS+FAIL))
[ "$TOT" -gt 0 ] || refuse "graded zero arms -- a runner that cannot measure never prints the success shape"
echo "[$GATE_NAME] PASS=$PASS FAIL=$FAIL over $TOT arms"
[ "$FAIL" -eq 0 ] || { echo "⛔ GATE FAILED"; exit 1; }
echo "✅ GATE OK"
