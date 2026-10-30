#!/usr/bin/env bash
# util_objects_identical_stripped.sh <objdirA> <objdirB> [outA outB] -- R5 OF THE HEADER SPLIT (ARCH-HEADER-SPLIT.md section 1, CEO-2032, step 1a; hq_templates):
# a header move changes no object. Every .o present in both trees is copied through objcopy --strip-debug into a scratch dir and compared byte for byte;
# the optional second pair (the out/ trees of the two roots, where the runtime's PIC objects and the parser modules live) is compared the same way.
# A build-id directory suffix (-f65f143e2f, ten hex digits) is dropped from the pairing key, so two roots built from different sources still pair.
# Prints "objects=N identical=N differing=M", then one line per differing object ("DIFF key"), and per object present in one tree only ("ONLY-A key" /
# "ONLY-B key"). rc 0 all identical and none missing, rc 1 any difference or any object in one tree only, rc 2 the instrument could not measure.
set -u
if [ "$#" -ne 2 ] && [ "$#" -ne 4 ]; then echo "usage: $0 <objdirA> <objdirB> [outA outB]" >&2; exit 2; fi
command -v objcopy >/dev/null && command -v cmp >/dev/null || { echo "REFUSE(2): objcopy or cmp is absent" >&2; exit 2; }
for d in "$@"; do [ -d "$d" ] || { echo "REFUSE(2): $d is not a directory" >&2; exit 2; }; done
scratch="$(mktemp -d)" || exit 2
trap 'rm -rf "$scratch"' EXIT
declare -A A B
collect() {
    local -n map=$1; local dir=$2 pre=$3 f rel key
    while IFS= read -r -d '' f; do
        rel="${f#"$dir"/}"
        key="$pre:$(printf '%s' "$rel" | sed -E 's/-[0-9a-f]{10}(\/|\.|$)/\1/g')"
        map["$key"]="$f"
    done < <(find "$dir" -name '*.o' -print0 | sort -z)
}
collect A "$1" obj; collect B "$2" obj
if [ "$#" -eq 4 ]; then collect A "$3" out; collect B "$4" out; fi
n=0; same=0; diff=0; one=0; lines=()
for key in $(printf '%s\n' "${!A[@]}" "${!B[@]}" | sort -u); do
    if [ -z "${A[$key]:-}" ]; then lines+=("ONLY-B $key"); one=$((one + 1)); continue; fi
    if [ -z "${B[$key]:-}" ]; then lines+=("ONLY-A $key"); one=$((one + 1)); continue; fi
    n=$((n + 1))
    objcopy --strip-debug "${A[$key]}" "$scratch/a.o" 2>/dev/null && objcopy --strip-debug "${B[$key]}" "$scratch/b.o" 2>/dev/null \
        || { echo "REFUSE(2): objcopy could not read $key" >&2; exit 2; }
    if cmp -s "$scratch/a.o" "$scratch/b.o"; then same=$((same + 1)); else lines+=("DIFF $key"); diff=$((diff + 1)); fi
done
[ "${#lines[@]}" -eq 0 ] || printf '%s\n' "${lines[@]}"
echo "objects=$n identical=$same differing=$diff"
[ "$diff" -eq 0 ] && [ "$one" -eq 0 ]
