#!/usr/bin/env bash
# test_gate_raku_aggregates_are_typed_storage.sh -- a Raku Array, List, Hash, Pair or Junction is typed DESCR-slot storage, never a string whose elements are
# joined by a separator byte (row raku-arrays-lists-and-hashes-are-typed-storage-no-delimiter-joined-strings-lon-2026-09-28; ceo CEO-1349, CEO-1479; RULES.md
# FACT RULE NO DELIMITER-JOINED AGGREGATES). Lon, in-chat to hq_pascal 2026-09-28, verbatim as relayed: "Get rid of ALL delimited based processing like the
# one I just discovered."
#
# THE DEFECT, measured on SCRIP 1a8548771: an array was one string with its elements joined by SOH (0x01), so
#   - an ELEMENT THAT HOLDS THE SEPARATOR split into two (my @a = ...; @a.push("f\x01g") read 5 elements where 4 are), and a hash key holding 0x01 was not found;
#   - a NESTED AGGREGATE flattened into its parent (my @n = [1, [2, 3]], 4 read 4 elements; Rakudo reads 2);
#   - a hash was "k STX v SOH k2 STX v2", so a nested value could not exist, say %h printed "a1 b2", and a callee's %p<q> = 5 never reached the caller;
#   - a Pair was "k SOH v", so .key and .value did not exist; a Junction was "\x03 flavour SOH ... \x04".
# Each is a silent wrong answer: the program exits 0 and prints plausible output.
#
# THE WITNESSES, each graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (lib_oracle_flags.sh rakudo_bin; /usr/bin/raku 2022.12 prints
# the same). The refs are the oracle's, never SCRIP's output. sep and nest are the row's own two; hash, pair, junction and marker carry the typed Hash, Pair,
# Junction and List/Array marker (ARBLK.proto) that replace the strings; the collector half of the marker is held by test_gate_gc_a_raku_list_array_marker_...
# FAILED ONCE, measured on SCRIP 59655e3ff with the typed-storage work absent: sep 3 2 2 4 3 3 3 Nil 11; nest 4 1 Nil 0 1 7 0 0 0; hash got
# "... Nil 1 Nil 7 2 0 only1" where Rakudo reads "... 5 3 2 7 1 3 {only => 1}"; pair printed (x:10 y:20) and (0 1 1 2) where Rakudo reads (x => 10 y => 20) and (1 2);
# marker read (Array) (Array) 4 4 "1 2 3" where Rakudo reads (Array) (List) 2 2 (1, (2, 3)); junction was already right and stays as the regression guard.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_aggregates_are_typed_storage.sh   (~6s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_aggregates_are_typed_storage"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/sep.raku" <<'EOF'
my @a = "a\x01b", "c", "d\x05e";
say @a.elems;
say @a[0].chars;
say @a[2].chars;
@a.push("f\x01g");
say @a.elems;
say @a[3].chars;
my %h = k => "v\x05w", "x\x01y" => 1;
say %h.elems;
say %h<k>.chars;
say %h{"x\x01y"};
say @a.join("|").chars;
EOF
printf '3\n2\n2\n4\n3\n2\n3\n1\n11\n' > "$W/sep.ref"
cat > "$W/nest.raku" <<'EOF'
my @n = [1, [2, 3]], 4;
say @n.elems;
say @n[0].elems;
say @n[0][1][1];
say @n[0][1].elems;
my %h = a => [1, 2, 3], b => { c => 7 };
say %h<a>.elems;
say %h<b><c>;
my @e = [], [];
say @e.elems;
say @e[1].elems;
@n[0][1].push(9);
say @n[0][1].elems;
EOF
printf '2\n2\n3\n2\n3\n7\n2\n0\n3\n' > "$W/nest.ref"
cat > "$W/hash.raku" <<'EOF'
my %h = a => 1, b => 2;
say %h.elems;
say %h<a>;
say %h{"b"};
%h<c> = 3;
say %h.elems;
say %h.keys.sort;
say %h.values.sort;
say (%h<a>:exists);
say (%h<z>:exists);
%h<a>:delete;
say %h.keys.sort;
my %g = %h;
%g<z> = 9;
say %h.elems;
say %g.elems;
sub f(%p) { %p<q> = 5 }
f(%h);
say %h<q>;
my %n = x => [1,2,3], y => {z => 7};
say %n<x>.elems;
say %n<x>[1];
say %n<y><z>;
my %s = "k\x01v" => "w\x05x";
say %s.elems;
say %s{"k\x01v"}.chars;
my %one = only => 1;
say %one;
EOF
printf '%s' '2
1
2
3
(a b c)
(1 2 3)
True
False
(b c)
2
3
5
3
2
7
1
3
{only => 1}
' > "$W/hash.ref"
cat > "$W/pair.raku" <<'EOF'
my $p = a => 1;
say $p.key;
say $p.value;
say $p;
my %h = x => 10, y => 20;
for %h.pairs.sort -> $q { say $q.key ~ "=" ~ $q.value }
say %h.pairs.sort;
say %h.kv.sort;
say "abab".trans(['a','b'] => ['x','y']);
say (1 => 2).kv;
my @ps = (c => 3, a => 1);
say @ps.sort.map({ .key }).join(",");
EOF
printf '%s' 'a
1
a => 1
x=10
y=20
(x => 10 y => 20)
(10 20 x y)
xyxy
(1 2)
a,c
' > "$W/pair.ref"
cat > "$W/junction.raku" <<'EOF'
my $j = any(1, 2, 3);
say $j == 2 ?? "yes" !! "no";
say (all(1, 2) < 3) ?? "yes" !! "no";
say (none(1, 2) == 5) ?? "yes" !! "no";
say (one(1, 2, 3) == 2) ?? "yes" !! "no";
say any(1, 2, 3);
say all("a", "b");
my $n = any(1, any(2, 3));
say $n == 3 ?? "yes" !! "no";
say (5 > any(1, 9)) ?? "yes" !! "no";
EOF
printf '%s' 'yes
yes
yes
yes
any(1, 2, 3)
all(a, b)
yes
yes
' > "$W/junction.ref"
cat > "$W/marker.raku" <<'EOF'
my @a = 1, 2;
my @b = (3, 4);
my $l = (5, 6);
say @a.WHAT;
say $l.WHAT;
say (@a, @b).elems;
say [@a, @b].elems;
say (1, (2, 3)).raku;
say [1, [2, 3]].raku;
my $ll = (1, (2, 3));
say $ll;
say [1, [2, 3]];
say (1, [2, 3]).flat.elems;
say [1, (2, 3)].flat.elems;
EOF
printf '%s' '(Array)
(List)
2
2
(1, (2, 3))
[1, [2, 3]]
(1 (2 3))
[1 [2 3]]
3
2
' > "$W/marker.ref"
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/$w.raku" 2>&1 </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-5s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-120)"; fails=$((fails + 1)); return; fi
        out="$(timeout -k 5 20 "$W/$w.bin" 2>&1 </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-5s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-5s %s\n' "$w" "$m"
    else printf '  FAIL %-5s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)" "$(tr '\n' ' ' < "$W/$w.ref")"; fails=$((fails + 1)); fi
}
for w in sep nest hash pair junction marker; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an element holding a separator byte, a nested aggregate, a Hash, a Pair, a Junction or the List/Array marker"
