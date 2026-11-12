#!/usr/bin/env bash
# util_ab_trees.sh -- THE TWO-TREE CORPUS A/B (DESIGN-PLAN box-scheduler step 25, worker_10 2026-11-05, CTO-496).
#
# A tree is a root's checkout: TREE/SCRIP/scrip (the binary) and TREE/corpus (the programs). Each program, named relative to a
# tree's corpus, runs under that tree's own scrip with AB_FLAGS (default --run), in that tree's corpus as the working directory,
# under timeout -k 5 AB_TIMEOUT (default 60 s a side). Stdout and stderr are captured together, the tree's own absolute path is
# normalised to <TREE>, and the two captures and the two exit codes are compared. A program in one corpus only is ONLY-A or
# ONLY-B; a program in neither corpus is UNPROVEN.
#
#   bash harness/scripts/util_ab_trees.sh TREE_A TREE_B PROG...
#   bash harness/scripts/util_ab_trees.sh TREE_A TREE_B --list FILE     (one program per line; blank and # lines skipped)
#   bash harness/scripts/util_ab_trees.sh --probe
#
#     AB <prog> SAME|DIFF|UNPROVEN|ONLY-A|ONLY-B rc_a=<n> rc_b=<n>      one line per program (DIFF adds the first differing lines)
#     AB SUMMARY programs=<n> same=<n> diff=<n> unproven=<n> only_a=<n> only_b=<n>
#     rc 0 when every program is SAME; rc 1 otherwise; rc 2 on usage, or a tree with no executable SCRIP/scrip or no corpus/.
#
# UNPROVEN is a timeout on either side (rc 124 or 137 under timeout -k): a program that cannot finish on both trees is not
# evidence of anything. --probe plants two stub trees (p1 same output on both, p2 differs, p3 sleeps on both, p4 in A only) and
# prints `AB probe PASS <classes>` only when the classes read back exactly as planted; otherwise a lowercase `ab probe FAIL` line.
# Scratch goes under /tmp/s4e/<seat>/ and is deleted at the verdict.
set -u

AB_FLAGS=${AB_FLAGS:---run}
AB_TIMEOUT=${AB_TIMEOUT:-60}
seat="${S4E_SEAT:-$(id -un)}"
base="${TMPDIR:-/tmp}/s4e/$seat"
W=""
TREE_A=""
TREE_B=""
RESULTS=""
CLS=""

usage() {
    echo "usage: $0 TREE_A TREE_B [PROG... | --list FILE]   or   $0 --probe" >&2
    exit 2
}

# esc STRING -- STRING as a literal sed basic regular expression
esc() { printf '%s' "$1" | sed -e 's/[][\.*^$/]/\\&/g'; }

# run_one TREE PROG OUT -- prints the exit code; OUT holds stdout and stderr with TREE's path replaced by <TREE>
run_one() {
    local tree=$1 prog=$2 out=$3 rc
    ( cd "$tree/corpus" && timeout -k 5 "$AB_TIMEOUT" "$tree/SCRIP/scrip" $AB_FLAGS "$prog" ) > "$out.raw" 2>&1 < /dev/null
    rc=$?
    sed -e "s/$(esc "$tree")/<TREE>/g" "$out.raw" > "$out"
    rm -f "$out.raw"
    echo "$rc"
}

# classify PROG N -- prints one AB line for PROG (scratch files suffixed N) and sets CLS
classify() {
    local prog=$1 n=$2 ina=0 inb=0 ra rb
    [ -f "$TREE_A/corpus/$prog" ] && ina=1
    [ -f "$TREE_B/corpus/$prog" ] && inb=1
    if [ "$ina" = 0 ] && [ "$inb" = 0 ]; then
        CLS=UNPROVEN; echo "AB $prog UNPROVEN rc_a=- rc_b=- in neither corpus"; return 0
    fi
    if [ "$inb" = 0 ]; then
        CLS=ONLY-A; echo "AB $prog ONLY-A rc_a=- rc_b=- absent from tree B"; return 0
    fi
    if [ "$ina" = 0 ]; then
        CLS=ONLY-B; echo "AB $prog ONLY-B rc_a=- rc_b=- absent from tree A"; return 0
    fi
    ra=$(run_one "$TREE_A" "$prog" "$W/a.$n")
    rb=$(run_one "$TREE_B" "$prog" "$W/b.$n")
    if [ "$ra" = 124 ] || [ "$ra" = 137 ] || [ "$rb" = 124 ] || [ "$rb" = 137 ]; then
        CLS=UNPROVEN; echo "AB $prog UNPROVEN rc_a=$ra rc_b=$rb timeout after ${AB_TIMEOUT}s on a side"
    elif [ "$ra" = "$rb" ] && cmp -s "$W/a.$n" "$W/b.$n"; then
        CLS=SAME; echo "AB $prog SAME rc_a=$ra rc_b=$rb"
    else
        CLS=DIFF; echo "AB $prog DIFF rc_a=$ra rc_b=$rb"
        diff "$W/a.$n" "$W/b.$n" | head -n 4 | sed 's/^/  /'
    fi
    rm -f "$W/a.$n" "$W/b.$n"
    return 0
}

# run_compare PROG... -- classifies each program in order, prints the summary, sets RESULTS; rc 0 only when every program is SAME
run_compare() {
    local prog n=0 same=0 ndiff=0 unp=0 oa=0 ob=0
    RESULTS=""
    for prog in "$@"; do
        n=$((n + 1))
        classify "$prog" "$n"
        RESULTS="$RESULTS $prog=$CLS"
        case $CLS in
            SAME) same=$((same + 1)) ;;
            DIFF) ndiff=$((ndiff + 1)) ;;
            UNPROVEN) unp=$((unp + 1)) ;;
            ONLY-A) oa=$((oa + 1)) ;;
            ONLY-B) ob=$((ob + 1)) ;;
        esac
    done
    echo "AB SUMMARY programs=$n same=$same diff=$ndiff unproven=$unp only_a=$oa only_b=$ob"
    [ "$n" -gt 0 ] && [ "$same" = "$n" ]
}

# plant TREE TAG -- a stub tree: its scrip prints p1 with its own path, p2 with TAG, sleeps on p3, prints p4; corpus holds p1 p2 p3
plant() {
    local t=$1 tag=$2 p
    mkdir -p "$t/SCRIP" "$t/corpus"
    cat > "$t/SCRIP/scrip" <<STUB
#!/usr/bin/env bash
for last; do :; done
case "\$(basename "\$last")" in
    p1) echo "p1 ok from \$(cd "\$(dirname "\$0")/.." && pwd)" ;;
    p2) echo "p2 value $tag" ;;
    p3) exec sleep 30 ;;
    p4) echo "p4 ok" ;;
esac
STUB
    chmod +x "$t/SCRIP/scrip"
    for p in p1 p2 p3; do : > "$t/corpus/$p"; done
}

# probe -- plants the stub trees, classifies p1..p4 and prints the one verdict line
probe() {
    local P="$W/probe" exp="p1=SAME p2=DIFF p3=UNPROVEN p4=ONLY-A" got
    plant "$P/ta" A || { echo "ab probe FAIL could not plant tree A under $P"; return 1; }
    plant "$P/tb" B || { echo "ab probe FAIL could not plant tree B under $P"; return 1; }
    : > "$P/ta/corpus/p4"
    TREE_A=$(cd "$P/ta" && pwd)
    TREE_B=$(cd "$P/tb" && pwd)
    AB_TIMEOUT=2 run_compare p1 p2 p3 p4 > "$W/probe.out" 2>&1
    got=${RESULTS# }
    if [ "$got" = "$exp" ]; then
        echo "AB probe PASS $got"
        return 0
    fi
    echo "ab probe FAIL expected [$exp] got [$got]"
    return 1
}

main() {
    local a b l progs=()
    [ $# -ge 1 ] || usage
    mkdir -p "$base" 2>/dev/null || { echo "ab: no scratch under $base (rc 2: cannot measure)" >&2; exit 2; }
    W=$(mktemp -d "$base/ab.XXXXXX") || { echo "ab: mktemp failed under $base (rc 2: cannot measure)" >&2; exit 2; }
    trap 'rm -rf "$W"' EXIT
    if [ "$1" = --probe ]; then
        [ $# = 1 ] || usage
        probe
        exit $?
    fi
    [ $# -ge 3 ] || usage
    a=$1; b=$2; shift 2
    TREE_A=$(cd "$a" 2>/dev/null && pwd)
    TREE_B=$(cd "$b" 2>/dev/null && pwd)
    if [ -z "$TREE_A" ] || [ -z "$TREE_B" ]; then
        echo "ab: no such tree: $a $b (rc 2: cannot measure)" >&2
        exit 2
    fi
    for t in "$TREE_A" "$TREE_B"; do
        if [ ! -x "$t/SCRIP/scrip" ] || [ ! -d "$t/corpus" ]; then
            echo "ab: $t has no executable SCRIP/scrip and corpus/ (rc 2: cannot measure)" >&2
            exit 2
        fi
    done
    if [ "$1" = --list ]; then
        [ $# = 2 ] && [ -f "$2" ] || usage
        while IFS= read -r l || [ -n "$l" ]; do
            l=${l%$'\r'}
            case $l in ''|'#'*) continue ;; esac
            l=${l#"${l%%[![:space:]]*}"}
            l=${l%"${l##*[![:space:]]}"}
            [ -n "$l" ] && progs+=("$l")
        done < "$2"
    else
        progs=("$@")
    fi
    [ ${#progs[@]} -gt 0 ] || { echo "ab: no programs named (rc 2: cannot measure)" >&2; exit 2; }
    run_compare "${progs[@]}"
    exit $?
}

main "$@"
