# harness/designs/raku_rewrite (moved from corpus/tests/raku/rewrite by the cfo 2026-11-12; each witness is now the entry rewrite__<name> of the raku master) -- the witnesses of DESIGN-PLAN: raku-rewrite (the cto, 2026-10-28, CEO-1996/1998)

Every `.raku` here is a witness of one step of `.github/ARCH-RAKU-REWRITE.md`; its `.ref` is cut from Rakudo (`rakudo_bin` of
`harness/scripts/lib_oracle_flags.sh`, rakudo-local 2026.05), the road `harness/scripts/test_design_raku_rewrite_steps.sh --cut` runs.
A step is GREEN when its witnesses equal their refs in mode 3 and mode 4 and its probes read green; every probe is a READ of a stored
measurement (the coo's results.tsv and SUITES.tsv, a grep of SCRIP/src), so a step whose witness is already equal is red by its chapter
floor until the coo's loop has graded the roast files it names.

| witness | step | what it measures | today (SCRIP 40d6d5c50, mode 3) |
|---|---|---|---|
| rr01_names | 1 | a sigilless variable, a constant, a `::T` capture used as a type | RED: the [SMX] refusal `variable 'a' is read but never assigned` |
| rr02_pod | 2 | `$=pod` as Pod::Heading and Pod::Block::Para objects, a declarator `#|` read through `.WHY` | RED: the [SMX] refusal on `=pod` |
| rr03_containers | 3 | binding between lexicals, `is rw`, `VAR(x).^name`, an element bound to a scalar, a bound literal refusing assignment, a hash value bound | RED: `error 22: undefined function called` at VAR; the first two lines equal |
| rr04_roles | 4 | hq_raku's repro: a role-body lexical per composing class (1,2,1), per (class, argument tuple) for a parametric role (1,2,1,1), `but` and `does` mixins at run time | RED: 1,2,3 and 1,2,1,3; `No such method 'tag'` |
| rr05_seq | 5 | `(1 ... *)[5000]`, an infinite gather under `.head(3)`, a lazy map/grep chain, a Seq returned from a sub, `.iterator`/`pull-one`, the fibonacci sequence, `is-lazy` | RED: no `.iterator`, `is-lazy` False for 1..Inf; the rest equal |
| rr06_regex | 6 | positional and named captures, longest-token alternation, a recursive grammar with actions, `s///`, `.subst` with a closure and `:g`, `m:g`, a lookahead | RED |
| rr07_exceptions | 7 | die/try/CATCH, a typed X::AdHoc through `$!`, `fail` as a Failure, LEAVE/KEEP/UNDO, `return` from a loop, `last LABEL`, CONTROL with `.resume` on a warn | RED: the [SMX] refusal (`CX::Warn` read) |
| rr08_dispatch | 8 | multis by type and `where`, named with defaults, `proto` with `{*}`, string and list methods on untyped parameters, `.^name`, `.can`, an `Int()` coercion, X::Multi::NoMatch | RED: `{*}` not wrapped, X::AdHoc for X::Multi::NoMatch |
| rr09_smartmatch | 9 | `~~` against a type, a regex, a WhateverCode, a range, a junction, a list and a string; given/when; junction autothreading and collapse; `.grep` with a junction | RED: `error 102: numeric expected` on `so (1|2) + 1 ~~ 2|3` |
| rr10_test | 10 | ok, is, is-deeply, throws-like, dies-ok, lives-ok, subtest, isa-ok, cmp-ok, done-testing | RED: throws-like prints nothing (no C arm) |
| rr11_eval | 11 | EVAL of an expression, of a lexical, of a sub | EQUAL today |
| rr12_concurrency | 11 | start/await, a Channel, a Supply tap, react/whenever, Promise.allof | RED |
| rr13_integration | 12 | a class with `is rw`, a grammar over a sentence, a hash of objects sorted, a gather, a Failure under `//` | EQUAL today; the step is red by its rows |
