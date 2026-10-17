#!/usr/bin/env bash
# test_gate_sno_a_name_that_is_both_a_formal_and_a_nominated_local_is_nulled_on_entry_and_restored_on_return.sh
#
# THE DEFECT (row snobol4-a-name-that-is-both-a-formal-and-a-nominated-local-keeps-its-argument-where-spitbol-nulls-it): in DEFINE('F(X)X') the name X is the formal AND a nominated
# local. sbl -bf nulls it on entry -- the local nomination wins, the argument is discarded -- and gives the caller's X back on return; SCRIP kept the argument in the body and left X NULL
# after the return (both modes). The DEFINE shim (bb_define.cpp, the fnsig role-4 shim) saved and nulled every local BEFORE it bound the formals, so a local sharing a formal's cell was
# overwritten by the argument, and restored locals BEFORE formals, so the formal's saved value (the nulled cell) won. THE CURE: a local whose cell a formal also owns is saved and nulled
# AFTER the formal chain binds (DUPL in bb_define_sr): the body sees null, the formal's slot keeps the caller's value, the local's slot the argument, and the exit order restores the caller's value.
# NOT HERE: a name with no island cell (the NV road leaf) and the SCRIP_FN_SIG=0 legacy shim.
# Every expected output is cut from sbl -bf and pinned: a program sbl no longer answers as pinned is a REFUSAL, never a green. Both modes.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/prior_value.sno" <<'SNO'
        X = 5
        DEFINE('F(X)X')
        F(7)
        OUTPUT = 'after1 ' X
        Y = 6
        DEFINE('G(Y,Z)Y,W')
        G(8, 9)
        OUTPUT = 'after2 ' Y
        G(8)
        OUTPUT = 'after3 ' Y
        :(FIN)
F       OUTPUT = 'in F [' X ']'  :(RETURN)
G       OUTPUT = 'in G [' Y '] [' Z '] [' W ']'  :(RETURN)
FIN
END
SNO
cat > "$D/prior_value.want" <<'TXT'
in F []
after1 5
in G [] [9] []
after2 6
in G [] [] []
after3 6
TXT
cat > "$D/no_args.sno" <<'SNO'
        X = 5
        DEFINE('F(X)X')
        F()
        OUTPUT = 'a ' X
        :(FIN)
F       OUTPUT = 'in [' X ']'  :(RETURN)
FIN
END
SNO
cat > "$D/no_args.want" <<'TXT'
in []
a 5
TXT
cat > "$D/both_formals.sno" <<'SNO'
        A = 1
        B = 2
        DEFINE('H(A,B)B,A')
        H(7, 8)
        OUTPUT = 'a ' A ' ' B
        :(FIN)
H       OUTPUT = 'in [' A '] [' B ']'  :(RETURN)
FIN
END
SNO
cat > "$D/both_formals.want" <<'TXT'
in [] []
a 1 2
TXT
cat > "$D/doubled_local.sno" <<'SNO'
        L = 'old'
        DEFINE('K(X)L,L')
        K(1)
        OUTPUT = 'a ' L
        :(FIN)
K       L = 'set'
        OUTPUT = 'in [' X '] [' L ']'  :(RETURN)
FIN
END
SNO
cat > "$D/doubled_local.want" <<'TXT'
in [1] [set]
a old
TXT
cat > "$D/result_value.sno" <<'SNO'
        DEFINE('V(X)X')
        Y = V(3)
        OUTPUT = 'y=[' Y ']'
        :(FIN)
V       X = 'r'
        V = X  :(RETURN)
FIN
END
SNO
cat > "$D/result_value.want" <<'TXT'
y=[r]
TXT
names="prior_value no_args both_formals doubled_local result_value"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
for p in $names; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $p.sno < /dev/null 2>/dev/null > $p.sbl )
    cmp -s "$D/$p.want" "$D/$p.sbl" || refuse "sbl -bf does not answer $p as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/$p.sbl")]"
done
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
for p in $names; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" $p.sno < /dev/null > $p.m3 2>/dev/null )
    ( cd "$D" && m4bin $p && timeout -k 5 30 ./$p.bin < /dev/null > $p.m4 2>/dev/null )
    for m in m3 m4; do
        if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then arm "$p $m" ok
        else arm "$p $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; fi
    done
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): a name that is both a formal and a nominated local is nulled on entry and the caller's value comes back on return -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
