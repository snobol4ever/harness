#!/usr/bin/env bash
# test_smoke_raku.sh — per-frontend smoke for Raku, run in BOTH native execution modes.
#   mode 3 = --run     (in-process stackless native x86 BB blobs) — the primary mode.
#   mode 4 = --compile (standalone x86-64 asm -> as -> link libscrip_rt -> run).
# NOTE (2026-06-15): the IR-graph interpreter (mode 2 / --run) was DELETED — nothing walks an IR graph to
#    interpret it in any mode. The harness no longer invokes --run; m3 and m4 are the only modes. A program
#    either runs natively (PASS) or is cleanly refused with a loud [SMX] banner (REFUSED) — there is no oracle
#    fallback. DONE BAR: m3 AND m4 each PASS-or-REFUSED with ZERO silent FAIL (no abort, no miscompile).
# Exit 0 iff mode-3 has zero FAIL AND mode-4 has zero FAIL AND m3 PASS >= $MODE3_MIN AND m4 PASS >= $MODE4_MIN.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Sonnet · Claude Opus  DATE: 2026-05-31 (3-mode; de-interp'd to 2-mode 2026-06-15)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
RT_SO="${HERE}/../../SCRIP/out/libscrip_rt.so"
MODE3_MIN="${MODE3_MIN:-0}"
MODE4_MIN="${MODE4_MIN:-0}"
P3=0; F3=0; X3=0; P4=0; F4=0; X4=0; N=0

raku() {
    local label="$1" expected="$2"
    local tmp; tmp=$(mktemp /tmp/rk_XXXXXX.raku)
    cat > "$tmp"
    N=$((N+1))
    local a3 a4 r3 r4
    local e3 e4 s4 bin4
    local rc3=0 rc4=0
    e3=$(mktemp /tmp/rk_XXXXXX.e3); e4=$(mktemp /tmp/rk_XXXXXX.e4)
    a3=$(timeout -k 5 8 "$SCRIP" --run    "$tmp" 2>"$e3" </dev/null); rc3=$?
    a4=""
    s4=$(mktemp /tmp/rk_XXXXXX.s); bin4=$(mktemp /tmp/rk_XXXXXX.bin); rm -f "$bin4"
    if timeout -k 5 8 "$SCRIP" --compile --target=x86 "$tmp" >"$s4" 2>"$e4" </dev/null && [ -s "$s4" ] && [ -f "$RT_SO" ]; then
        if gcc -no-pie "$s4" -L"${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$bin4" 2>/dev/null; then
            a4=$(timeout -k 5 8 "$bin4" 2>/dev/null </dev/null); rc4=$?
        fi
    fi
    # [SMX] on stderr => the native mode DELIBERATELY REFUSES this rung (its bb_*.cpp template is not built
    # yet) => counted REFUSED, NOT FAIL. The done bar (interp now deleted): m3 AND m4 each PASS-or-REFUSED —
    # never a silent FAIL / abort / miscompile.
    # rc != 0 AND NOT smx => crash or bad exit => FAIL even if stdout matched (RK-ZC-7: harness sees rc).
    local smx3=0 smx4=0
    grep -qE '\[SMX\]' "$e3" && smx3=1
    grep -qE '\[SMX\]' "$e4" && smx4=1
    rm -f "$tmp" "$s4" "$bin4" "$e3" "$e4"
    if   [ "$smx3" -eq 1 ];                                           then r3="m3 EXCS"; X3=$((X3+1));
    elif [ "$a3" = "$expected" ] && [ "$rc3" -eq 0 ];                 then r3="m3 PASS"; P3=$((P3+1));
    else                                                                    r3="m3 FAIL"; F3=$((F3+1)); fi
    if   [ "$smx4" -eq 1 ];                                           then r4="m4 EXCS"; X4=$((X4+1));
    elif [ "$a4" = "$expected" ] && [ "$rc4" -eq 0 ];                 then r4="m4 PASS"; P4=$((P4+1));
    else                                                                    r4="m4 FAIL"; F4=$((F4+1)); fi
    printf "  [%s] [%s] %s\n" "$r3" "$r4" "$label"
}
# raku_dies — like raku() but expects a non-zero exit code (die/type-error/access-violation).
# stdout must match expected AND rc must be nonzero; rc=0 or stdout mismatch = FAIL.
raku_dies() {
    local label="$1" expected="$2"
    local tmp; tmp=$(mktemp /tmp/rk_XXXXXX.raku)
    cat > "$tmp"
    N=$((N+1))
    local a3 a4 r3 r4
    local e3 e4 s4 bin4
    local rc3=0 rc4=0
    e3=$(mktemp /tmp/rk_XXXXXX.e3); e4=$(mktemp /tmp/rk_XXXXXX.e4)
    a3=$(timeout -k 5 8 "$SCRIP" --run    "$tmp" 2>"$e3" </dev/null); rc3=$?
    a4=""
    local crc4=0
    s4=$(mktemp /tmp/rk_XXXXXX.s); bin4=$(mktemp /tmp/rk_XXXXXX.bin); rm -f "$bin4"
    timeout -k 5 8 "$SCRIP" --compile --target=x86 "$tmp" >"$s4" 2>"$e4" </dev/null; crc4=$?
    if [ "$crc4" -eq 0 ] && [ -s "$s4" ] && [ -f "$RT_SO" ]; then
        if gcc -no-pie "$s4" -L"${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$bin4" 2>/dev/null; then
            a4=$(timeout -k 5 8 "$bin4" 2>/dev/null </dev/null); rc4=$?
        fi
    elif [ "$crc4" -ne 0 ]; then
        rc4="$crc4"
    fi
    local smx3=0 smx4=0
    grep -qE '\[SMX\]' "$e3" && smx3=1
    grep -qE '\[SMX\]' "$e4" && smx4=1
    rm -f "$tmp" "$s4" "$bin4" "$e3" "$e4"
    if   [ "$smx3" -eq 1 ];                                           then r3="m3 EXCS"; X3=$((X3+1));
    elif [ "$a3" = "$expected" ] && [ "$rc3" -ne 0 ];                 then r3="m3 PASS"; P3=$((P3+1));
    else                                                                    r3="m3 FAIL"; F3=$((F3+1)); fi
    if   [ "$smx4" -eq 1 ];                                           then r4="m4 EXCS"; X4=$((X4+1));
    elif [ "$a4" = "$expected" ] && [ "$rc4" -ne 0 ];                 then r4="m4 PASS"; P4=$((P4+1));
    else                                                                    r4="m4 FAIL"; F4=$((F4+1)); fi
    printf "  [%s] [%s] %s\n" "$r3" "$r4" "$label"
}

echo "=== Raku smoke ==="

raku "say_str" "hello world" << 'EOF'
sub main() {
    say('hello world');
}
main();
EOF

raku "arith" "42" << 'EOF'
sub main() {
    my $x = 6 * 7;
    say($x);
}
main();
EOF

raku "var" "99" << 'EOF'
sub main() {
    my $x = 99;
    say($x);
}
main();
EOF

raku "while_loop" "$(printf '1\n2\n3')" << 'EOF'
sub main() {
    my $i = 1;
    while ($i <= 3) {
        say($i);
        $i = $i + 1;
    }
}
main();
EOF

raku "string_concat" "abcd" << 'EOF'
sub main() {
    my $s = 'ab' ~ 'cd';
    say($s);
}
main();
EOF

raku "elsif_no_else" "a" << 'EOF'
my $x = 1;
if $x == 1 { say "a" } elsif $x == 2 { say "b" }
EOF

raku "array_sort" "$(printf '1\n3\n5\n9')" << 'EOF'
sub main() {
    my @a = (5, 3, 9, 1);
    my @s = sort(@a);
    say(@s[0]);
    say(@s[1]);
    say(@s[2]);
    say(@s[3]);
}
main();
EOF

raku "hash_keys" "a,b,c" << 'EOF'
my %h = a => 1, b => 2, c => 3;
say %h.keys.sort.join(",");
EOF

raku "class_method" "$(printf '3\n4\n7\n14\nRex\nWoof from Rex')" << 'EOF'
class Point {
    has $.x;
    has $.y;
    method sum() { return $!x + $!y; }
    method scale($factor) { return ($!x + $!y) * $factor; }
}
class Dog {
    has $.name;
    has $.age;
    method greet() { return "Woof from " ~ $!name; }
}
sub main() {
    my $p = Point.new(x => 3, y => 4);
    say($p.x);
    say($p.y);
    say($p.sum());
    say($p.scale(2));
    my $d = Dog.new(name => "Rex", age => 5);
    say($d.name);
    say($d.greet());
}
main();
EOF

raku "ternary_true" "5" << 'EOF'
my $x = 1 ?? 5 !! 9; say $x;
EOF

echo "mode-3 (--run):      PASS=$P3 FAIL=$F3 REFUSED=$X3  / $N   (done bar: PASS or REFUSED, never silent FAIL)"
echo "mode-4 (--compile):  PASS=$P4 FAIL=$F4 REFUSED=$X4  / $N   (done bar: PASS or REFUSED, never silent FAIL)"
# COMPLETION BAR (interp deleted 2026-06-15 — two native modes only): ZERO silent m3/m4 FAIL — every native
# mode is either PASS or a LOUD [SMX] REFUSE (no abort, no miscompile, no oracle fallback). A rung is promoted
# only when BOTH m3 and m4 are accounted for together. Floors retained as a backstop ratchet.
# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any
# session will update the ONE LEADERBOARD"). This records the board line printed just above into
# .github/SCORE.md -- it RUNS NOTHING, it only writes down what this script already measured.
# ⛔ NON-FATAL BY DESIGN: a bookkeeping failure must never turn a real measurement into a red board,
# because a gate that goes red for a reason unrelated to the code is a gate people route around. It
# warns and names the unrecorded row instead; it has no silent path.
python3 "$HERE/util_score_row.py" write --lang raku --column floor --modes m3,m4 \
    --measurer "${S4E_SEAT:-}" --text "smoke m3 $P3/$N · m4 $P4/$N (FAIL $F3/$F4, REFUSED $X3/$X4, \`test_smoke_raku.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
[ "$F3" -eq 0 ] && [ "$F4" -eq 0 ] && [ "$P3" -ge "$MODE3_MIN" ] && [ "$P4" -ge "$MODE4_MIN" ]
