# harness/designs/raku_roast_causes (moved from corpus/tests/raku/roast_causes by the cfo 2026-11-12; each witness is now the entry roast_causes__<name> of the raku master) -- the witnesses of DESIGN-PLAN: raku-roast-causes (the cao, 2026-11-05, CTO-514)

Every `.raku` here is a witness of one step of the plan in `STEPS.tsv` beside it: one step per CAUSE of Roast reds (the CTO-514 class
"a real not ok"), each cure proven by the cao on a scratch worktree with a base-against-cure differential over the roast programs the
construct touches before the step is written. Its `.ref` is cut from Rakudo (`rakudo_bin` of `harness/scripts/lib_oracle_flags.sh`,
rakudo-local 2026.05) by `harness/scripts/test_design_raku_roast_causes_steps.sh --cut`. A step is GREEN when its witnesses equal their
refs in mode 3 and mode 4 and its probes read green; every probe is a READ of the coo's stored readings, so a step is red by its `pass=`
programs until the coo has graded them.

| witness | step | what it measures | today (SCRIP 52f53c466, mode 3) |
|---|---|---|---|
| rc01_lone_interpolation_is_str | 1 | a string that is one interpolated value (`"$e"`, `"$!"`, `"@a[]"`, `"%h<a>"`, `"{...}"`) is a Str | RED: `"$e" ~~ Str` False, `"$!" ~~ /boom/` dies error 241 |
| rc02_colonpair_angle_named | 2 | `:x<y>` is a named argument; `EVAL(..., :lang<L>)` dies for a language but Raku | RED: `{}` and `[1, "y"]`; EVAL of Perl5 succeeds |
