#!/usr/bin/env bash
# util_rsp_restore_census.sh -- WHERE DOES THE EMITTED CODE LOAD rsp FROM MEMORY? (ceo CEO-1830/1832, ARCH-ZETA-ONE-COORDINATE.md
# section 4, the second instrument). A FORTH stack loads its pointer from memory only at a DISCARD (CEO-1759: a retry never
# restores rsp; a discard may). ZD-CHECK reads the PLAN; this census reads the ASM: for every PARTITION core entry of a master
# it compiles mode 4 and counts `mov rsp, [memory]` sites by the port the nearest label above them names (the label's suffix
# after its last underscore: alpha, beta, gamma, omega, or a number/other), plus `lea rsp, [rbp ...]` frame-base restores.
# A beta site is a RETRY restoring rsp from a record -- the thing the conversion removes; an omega or a cut/commit site is a
# discard. It judges nothing (rc 0 when it measured, rc 2 when it could not); its board line is a ledger for the conversion.
#   RSP_RESTORE_BOARD lang=<l> entries=<n> compiled=<c> loads=<t> alpha=<a> beta=<b> gamma=<g> omega=<w> other=<o> lea_rbp=<x>
# USE: bash harness/scripts/util_rsp_restore_census.sh [--lang <l>] [--file <prog>...]
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
ONLY=""; FILES=()
while [ $# -gt 0 ]; do case "$1" in --lang) ONLY="$2"; shift;; --file) FILES+=("$2"); shift;; *) echo "REFUSE(2): unknown argument $1"; exit 2;; esac; shift; done
W="$(mktemp -d "${TMPDIR:-/tmp}/rsp_census.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
count_s() { awk '
    /^[A-Za-z_.$][^ \t]*:/ { l = $0; sub(/:.*/, "", l) }
    /^[[:space:]]*mov[[:space:]]+rsp,[[:space:]]*(qword ptr )?\[/ { n = split(l, a, "_"); k = a[n]; t++;
        if (k == "\xce\xb1") al++; else if (k == "\xce\xb2") be++; else if (k == "\xce\xb3") ga++; else if (k == "\xcf\x89") om++; else ot++ }
    /^[[:space:]]*lea[[:space:]]+rsp,[[:space:]]*\[rbp/ { lr++ }
    END { printf "%d %d %d %d %d %d %d\n", t+0, al+0, be+0, ga+0, om+0, ot+0, lr+0 }' "$1"; }
if [ "${#FILES[@]}" -gt 0 ]; then
    for f in "${FILES[@]}"; do
        ( cd "$SCRIP" && timeout -k 2 60 ./scrip --compile --out="$W/f.s" "$f" < /dev/null > /dev/null 2>&1 ) || { echo "RSP_RESTORE_FILE file=$f compiled=0"; continue; }
        read -r t al be ga om ot lr <<< "$(count_s "$W/f.s")"
        echo "RSP_RESTORE_FILE file=$f loads=$t alpha=$al beta=$be gamma=$ga omega=$om other=$ot lea_rbp=$lr"
    done
    exit 0
fi
for pair in snobol4:sno icon:icn prolog:pl raku:raku pascal:pas snocone:sc rebus:reb; do
    lang="${pair%%:*}"; ext="${pair##*:}"
    [ -z "$ONLY" ] || [ "$ONLY" = "$lang" ] || continue
    D="$CORPUS/tests/$lang"
    [ -f "$D/PARTITION.tsv" ] && [ -f "$D/ALL.$ext" ] || { echo "REFUSE(2): $D has no PARTITION.tsv or ALL.$ext"; exit 2; }
    n=0; c=0; T=0; AL=0; BE=0; GA=0; OM=0; OT=0; LR=0
    while IFS=$'\t' read -r entry cls rest; do
        case "$entry" in ''|'#'*|entry) continue;; esac
        [ "$cls" = "core" ] || continue
        n=$((n+1)); src="$W/$lang.$n.$ext"
        python3 "$HERE/corpus_suite_harness.py" extract "$D/ALL.$ext" "$D/ALL.ref" "$entry" "$src" --out-ref "$W/$lang.$n.ref" > /dev/null 2>&1 || continue
        ( cd "$SCRIP" && timeout -k 2 60 ./scrip --compile --out="$W/$lang.$n.s" "$src" < /dev/null > /dev/null 2>&1 ) || continue
        c=$((c+1))
        read -r t al be ga om ot lr <<< "$(count_s "$W/$lang.$n.s")"
        T=$((T+t)); AL=$((AL+al)); BE=$((BE+be)); GA=$((GA+ga)); OM=$((OM+om)); OT=$((OT+ot)); LR=$((LR+lr))
    done < "$D/PARTITION.tsv"
    [ "$c" -gt 0 ] || { echo "REFUSE(2): $lang core compiled 0 entries of $n"; exit 2; }
    echo "RSP_RESTORE_BOARD lang=$lang entries=$n compiled=$c loads=$T alpha=$AL beta=$BE gamma=$GA omega=$OM other=$OT lea_rbp=$LR"
done
exit 0
