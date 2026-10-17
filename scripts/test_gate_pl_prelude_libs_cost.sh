#!/usr/bin/env bash
# test_gate_pl_prelude_libs_cost.sh -- A PROGRAM NAMING NO VENDORED LIBRARY PAYS NOTHING FOR THEM; ONE NAMING A LIBRARY PAYS
# FOR THAT LIBRARY ALONE (cfo 2026-10-10, row prolog-swi-library-modules-rbtrees-assoc-ordsets-apply-error-pairs-aggregate-
# option-strings-516-swi-cases; CEO-1473's condition: "the compile-time cost measured on a program naming nothing and on one
# naming rbtrees, both gated fail-once pass-once").
#
# THE MECHANISM (src/parsers/prolog/prolog_parse.c pl_libs_append): a vendored library's source is parsed only when the
# program names one of its exports (or a selected library depends on it); its clauses then join the base prelude's pool
# and the existing closure keeps only what the program reaches.
#
# THE INSTRUMENT is callgrind (load-immune: instructions, not time) over `scrip --dump-ast`, which runs the parse and the
# prelude injection and skips emission (90% of a compile).  Two readings per program: the instructions inclusive of
# pl_libs_append, and the calls it makes to prolog_parse (one per library parsed).
#   ARM 1 (names nothing): 0 library parses, and pl_libs_append <= 540,000 instructions -- the scan of every vendored
#          RE-PINNED 400,000 -> 500,000 (hq_prolog 2026-10-15, row prolog-every-suite-to-100-under-tenet-ceo-1562): the selection pass scans every vendored
#          library's export table against the program's references, and seven libraries (hashtable, nb_set, solution_sequences, csv, terms, random, backcomp)
#          and the mctx helpers joined the set; measured 456,274 on c30687d4d (before the module-context helpers) and 478,329 on this landing; the cap keeps ~4% headroom.
#          RE-PINNED 500,000 -> 540,000 (cfo 2026-10-15, GNU drivers row, stream second half): gnu_builtins.pl gained seven exports (set_stream_type/2,
#          set_stream_eof_action/2, set_stream_buffering/2, stream_position/2, stream_line_column/3, set_stream_line_column/3, seek/4), about 3,700 instructions
#          each in the scan; measured 504,112 on that landing; ~7% headroom. The scan is linear in the total export count -- a hashed reference set would make
#          this arm flat (named to hq_prolog, whose selector it is).
#          ARM 2 also read 3 parses once backcomp was vendored: library(error)'s has_type(proper_list, X) is the bare atom of backcomp's proper_list/1 export,
#          so backcomp joined the generator's QUIET_BARE (dcg_basics, clpfd and gnu_builtins are there for the same reason); measured 13,162,552 with 2 parses.
#     export against the program's name/arity references, measured 177,915 over 11 libraries (0.02% of hello world's
#     935M compile).  FAIL-ONCE, two defects: with selection ablated (every vendored library parsed, the defect this arm
#     exists for) it read 1 parse and 2,556,828 instructions, red; the first cut built the base prelude's key set before
#     it knew whether any library was selected, 4,730,717 for hello world, red; the cure returned before any work (11,735
#     with 6 libraries and name-only selection; 329,587 once the scan formatted a key per export, cured to compare in place).
#   ARM 2 (names rbtrees, the largest library CEO-1473 names): exactly rbtrees and the libraries its own references need
#          RE-PINNED 25,000,000 -> 27,000,000 (cfo 2026-10-10, GNU FD row): the selection pass scans every vendored library's export
#          table against the program's references, so a thirteenth library (gnu_fd, 45 exports) costs ~1.3M instructions here --
#          measured 24,447,993 on 70f3505ed and 25,794,816 with gnu_fd embedded; the cap keeps the ~5% headroom it had.
#          RE-PINNED 27,000,000 -> 15,000,000 (hq_prolog 2026-10-10, row prolog-library-quintus-...): the two linear scans are
#          hashed -- the base-prelude check walked every base clause for every library clause, and each export was looked up by a
#          walk of the reference vector on every closure pass. The references and the user definitions are a stack key set built per
#          call, the base prelude's keys one built only once a library is parsed (the first pass keeps the walk: a program naming
#          only exports the base answers parses nothing, and building the base set would cost it more than the walk -- ARM 1
#          207,504, was 295,005). Measured 14,116,171 on c399cd256 + this landing, 14,224,525 with quintus vendored (was 25,810,564
#          by the linear scans on c399cd256, the cfo's reading; quintus cost 0.88M under them on 70f3505ed and costs 0.11M now);
#          the cap keeps ~5% over the reading.
#     are parsed -- rbtrees and error (must_be/2), 2 parses, pinned from the measurement and re-pinned with a reason when
#     the vendored set changes what rbtrees reaches -- and pl_libs_append <= 25,000,000 instructions (measured 20,842,950:
#     rbtrees is 1152 lines and error 463, parsed at ~40,000 instructions a line as the base prelude is; apply alone was
#     2,561,359 when the arm named foldl/4).  FAIL-ONCE: the first cut checked each library clause against an allocated
#     key set of the whole base prelude, 5,662,131 for apply alone, red here.
#   ARM 3 (names aggregate_all/3 only with templates SCRIP's lowerer answers itself -- count, sum, max, min, bag, set): 0
#     library parses.  library(aggregate) exports aggregate_all/3 for the templates SCRIP does not lower, and its closure
#     is ~80 predicates; pulling it for a count-only program cost 4,010,190,562 instructions to compile against 968,161,311
#     without it (hello world 935,320,040).  pl_aggregate_all_native_kind is the ONE test the lowerer and the injector
#     share.  FAIL-ONCE: with the injector's native-only suppression ablated it read 4 parses (aggregate and its deps).
#   SELECTION IS BY NAME/ARITY AND SKIPS WHAT THE BASE PRELUDE DEFINES (library(lists) exports append/3, member/2 and
#     length/2, which the base prelude answers): arm 1's program names exactly those three and must still parse nothing.
#     FAIL-ONCE: with name-only selection it read 3 parses (lists, error, option) and 10,376,063 instructions.
#   ARM 4 (names clpfd's exports only as DATA -- open/4's alias(in), a term f(sum, chain, element, label, transpose)): 0 library
#     parses (cfo 2026-10-11, row prolog-logtalk-reads-100-percent-...-ceo-1689).  A bare atom of an export's name selects its
#     library (the any-arity rule a closure such as maplist(foo, L) needs), and clpfd's export names are common atoms, so each
#     selected all of clpfd and five libraries it reaches and cost ~9 s of compile (f(in) 9.36 s, f(sum) 9.05 s); three Logtalk
#     stream_property/2 cases opening alias(in) timed out at 10 s.  The generator's QUIET_BARE now holds clpfd as it holds
#     dcg_basics.  FAIL-ONCE: this arm with the table of SCRIP 59d6aad80 (before the cure) restored and rebuilt read 7 parses
#     -- clpfd, apply, assoc, error, lists, pairs, gnu_builtins (a gdb break on register_lib_ops names them) -- red; 0 with it.
# A reading that does not find pl_libs_append in the profile refuses rc=2 (a reader that finds nothing reads 0 and passes).
# ~4 s.  rc=0 all arms · rc=1 a red · rc=2 refused (valgrind missing, a stale build, a reader that found nothing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSED(2) [test_gate_pl_prelude_libs_cost]: $*"; exit 2; }
command -v valgrind >/dev/null 2>&1 || refuse "valgrind missing -- the budget is an instruction count"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
"$HERE/util_require_fresh.sh" --gate test_gate_pl_prelude_libs_cost || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/nothing.pl" <<'PL'
:- initialization(main).
main :- append([a], [b], L), member(X, L), write(X), nl, length(L, N), write(N), nl.
PL
cat > "$D/apply.pl" <<'PL'
:- initialization(main).
main :- list_to_rbtree([k1-v1, k2-v2], T), rb_insert(T, k0, v0, T2), rb_keys(T2, Ks), write(Ks), nl.
PL
cat > "$D/native.pl" <<'PL'
:- initialization(main).
main :- aggregate_all(count, member(_, [a, b]), C), aggregate_all(sum(X), member(X, [1, 2]), S), write(C-S), nl.
PL
cat > "$D/data.pl" <<'PL'
:- initialization(main).
main :- open('data.pl', read, _, [alias(in)]), close(in), X = f(sum, chain, element, label, transpose), write(X), nl.
PL
want=2
reading() {
    ( cd "$D" && valgrind --tool=callgrind --callgrind-out-file="$D/cg.$1" "$B/scrip" --dump-ast "$D/$1.pl" < /dev/null > /dev/null 2>&1 ) || refuse "callgrind over scrip --dump-ast $1.pl failed"
    python3 - "$D/cg.$1" <<'PY'
import sys, re
names, cur, callee, parses, found = {}, None, None, 0, False
for line in open(sys.argv[1]):
    m = re.match(r'^(c?fn)=\((\d+)\)(?: (.*))?', line)
    if m:
        kind, i, nm = m.groups()
        if nm: names[i] = nm.strip()
        if kind == 'fn': cur = names[i]; found = found or cur == 'pl_libs_append'
        else: callee = names[i]
        continue
    m = re.match(r'^calls=(\d+)', line)
    if m and cur == 'pl_libs_append' and callee == 'prolog_parse': parses += int(m.group(1))
print(parses, found)
PY
}
incl_of() { callgrind_annotate --inclusive=yes --auto=no --threshold=100 "$D/cg.$1" 2>/dev/null | grep -E 'prolog_parse\.c:pl_libs_append ' | head -1 | awk '{gsub(",", "", $1); print $1}'; }
red=0
read -r p1 f1 <<< "$(reading nothing)"; i1="$(incl_of nothing)"
read -r p2 f2 <<< "$(reading apply)"; i2="$(incl_of apply)"
read -r p3 f3 <<< "$(reading native)"
read -r p4 f4 <<< "$(reading data)"
[ "$f4" = True ] || refuse "arm 4: pl_libs_append is not in the profile -- the reader found nothing"
[ "$f3" = True ] || refuse "arm 3: pl_libs_append is not in the profile -- the reader found nothing"
[ "$f1" = True ] && [ -n "$i1" ] || refuse "arm 1: pl_libs_append is not in the profile -- the reader found nothing"
[ "$f2" = True ] && [ -n "$i2" ] || refuse "arm 2: pl_libs_append is not in the profile -- the reader found nothing"
if [ "$p1" = 0 ] && [ "$i1" -le 540000 ]; then echo "  ARM 1 GREEN: a program naming no library parsed $p1 libraries, pl_libs_append $i1 instructions (<= 540,000)"
else echo "  ARM 1 RED: a program naming no library parsed $p1 libraries, pl_libs_append $i1 instructions (want 0 and <= 540,000)"; red=1; fi
b2=15000000
if [ "$p2" = "$want" ] && [ "$i2" -le "$b2" ]; then echo "  ARM 2 GREEN: naming rbtrees parsed $p2 libraries (rbtrees and error: $want), pl_libs_append $i2 instructions (<= $b2)"
else echo "  ARM 2 RED: naming rbtrees parsed $p2 libraries (want rbtrees and error, $want), pl_libs_append $i2 instructions (want <= $b2)"; red=1; fi
if [ "$p3" = 0 ]; then echo "  ARM 3 GREEN: a program whose aggregate_all/3 calls SCRIP lowers itself parsed $p3 libraries"
else echo "  ARM 3 RED: a program whose aggregate_all/3 calls SCRIP lowers itself parsed $p3 libraries (want 0)"; red=1; fi
if [ "$p4" = 0 ]; then echo "  ARM 4 GREEN: a program naming clpfd's exports only as data (alias(in), f(sum, ...)) parsed $p4 libraries"
else echo "  ARM 4 RED: a program naming clpfd's exports only as data (alias(in), f(sum, ...)) parsed $p4 libraries (want 0)"; red=1; fi
[ "$red" = 0 ] && echo "PASS test_gate_pl_prelude_libs_cost"
exit "$red"
