#!/usr/bin/env bash
# test_gate_pl_meta_specs_inc_is_current.sh -- THE BUILTINS' META-PREDICATE SPECS COME FROM ONE ORACLE-CUT TABLE PER DIALECT (the cto's
# ARCH-PROLOG-DATABASE.md 4c, CEO-1964/1971; row prolog-predicate-property-meta-predicate-is-one-record-column-read-in-both-dialects-sec-4c-ceo-1964).
# harness/scripts/pl_meta_specs.tsv is what swipl 9.0.4 and gprolog 1.4.5 answer for predicate_property(H, meta_predicate(S)) over their builtins
# (util_gen_pl_meta_specs.py --cut); SCRIP/src/runtime/pl_meta_specs.inc is written from it and read through rt_pl_meta_builtin by the runtime's
# predicate_property and the lowerer's compile-time fold alike. A TSV re-cut without a regeneration, an .inc edited by hand, or a hand-typed list
# beside the table (the deleted pl_meta_template, pl_gnu_meta_spec, pl_gnu_meta_term) is the drift this gate names.
# rc 0 current · rc 1 stale, or a hand list beside the table · rc 2 cannot read the table, the .inc or the sources.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../../SCRIP/src"
for f in "$SRC/runtime/by_name_dispatch.c" "$SRC/lower/lower_prolog.c"; do [ -r "$f" ] || { echo "REFUSE(2): cannot read $f"; exit 2; }; done
python3 "$HERE/util_gen_pl_meta_specs.py" --check; rc=$?
[ "$rc" = 2 ] && exit 2
if ! grep -q '#include "pl_meta_specs.inc"' "$SRC/runtime/by_name_dispatch.c"; then echo "RED: by_name_dispatch.c does not include pl_meta_specs.inc"; rc=1; fi
for nm in pl_meta_template pl_gnu_meta_spec pl_gnu_meta_term; do
    if grep -q "\b$nm\b" "$SRC/runtime/by_name_dispatch.c" "$SRC/lower/lower_prolog.c"; then echo "RED: $nm is back -- a hand-typed list of meta specs beside the table"; rc=1; fi
done
if ! grep -q 'rt_pl_meta_builtin' "$SRC/lower/lower_prolog.c"; then echo "RED: the lowerer's compile-time fold does not read rt_pl_meta_builtin"; rc=1; fi
[ "$rc" = 0 ] && echo "GATE OK [pl_meta_specs_inc_is_current]: the builtins' meta specs come from the oracle-cut table, one per dialect" && exit 0
echo "GATE RED [pl_meta_specs_inc_is_current]"; exit 1
