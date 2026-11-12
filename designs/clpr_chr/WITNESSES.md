> MOVED 2026-11-12 by the cfo (row tests-consolidation-finish-cfo) from corpus/tests/prolog/clpr_chr/KEEP.md: the witnesses this page names are now entries clpr_chr__<name> of the prolog master (corpus/tests/prolog), staged for the step harness by lib_design_witness.sh design_witness_stage; read "standalone" and "kept loose" below as history.

# corpus/tests/prolog/clpr_chr -- the witnesses of DESIGN-PLAN: clpr-chr (the cto, 2026-10-28, CEO-1996/1998)

Every `.pl` here is a witness of one step of `.github/ARCH-PROLOG-CLPR-CHR.md`; its `.ref` is cut from swipl 9.0.4 by
`swipl -q -t halt <witness>.pl < /dev/null` (stdout only; the CHR compiler's warnings on stderr are not graded), the road
`harness/scripts/test_design_clpr_chr_steps.sh --cut` runs. Each witness prints only ground terms, so no oracle variable name
is in any ref. A step is GREEN when its witnesses equal their refs in mode 3 and mode 4 and its probe reads green.

| witness | step | what it measures |
|---|---|---|
| cc01_decl | 1 | chr_constraint, chr_option, three declared constraints posted and enumerated newest first per constraint in declaration order; chr_show_store |
| cc02_simp | 2 | single-head simplification with guards, a recursive constraint (the ethiopian multiplication), a CHR constraint used as a guard |
| cc03_simpag | 3 | simpagation (gcd), a same-constraint simpagation removing duplicates, a two-head rule whose partner is found through a shared unbound variable |
| cc04_prop | 4 | propagation with the history (a(X) ==> b(X), a two-head propagation), the hailstone chain of 112 constraints and its clean-up |
| cc04b_late | 4 | chr_option(debug, off): late storage -- the store order a program prints (hailstone(27) first), a constraint that a rule body can reach as a partner stored before the body, the reachability through direct calls only |
| cc05_wake | 5 | a constraint on an unbound variable re-run at the binding; two attributed variables unified (the attribute merge) |
| cc06_store | 6 | find_chr_constraint/1, current_chr_constraint/1 and chr_show_store/1 over two constraints |
| cc07_module | 7 | the ethiopian rules inside a module with an exported driver |
| cq08_var_order | 8 | compare/3 and msort on fresh variables of one body term (creation order = textual order), and clpq dump/3 solving for the variable swipl solves for |
| cr09_linprog | 9 | exists_source(library(clpr)), the bounded flag, swi_tests clp/linprog's two checks over the vendored library(simplex) |
