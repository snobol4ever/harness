# Suite run 2026-10-27: Prolog, Icon, Pascal (partial)

Partial record, written while the run was in progress. Only suites listed in `results.tsv` have finished.

- Runner: `harness/scripts/test_*_suite.sh`, one at a time, from the g4 layout (SCRIP at `main` c33d10f).
- Guard: the one-runner guard refused this session (no seat, no LANES line). It was overridden with `S4E_ONE_RUNNER_OVERRIDE` because the session runs in the cloud, not on the owner's Linux machine.
- Score rows: not written (`S4E_SCORE_WRITE` unset). The score writer refused as expected (`REFUSED(2) util_score_row`).
- Skipped by request: Logtalk (4h32m) and ProPuzzles (2h44m), as the very long suites.
- Still to run at time of writing: SWI (in progress, `--jobs 1`), GNU, ProDemo, ProRosetta, Trealla, XSB, ProRungs, ProBench, Zona, Jcon, IPL, IcnDemo, IcnRungs, IcnBench, FPC, PAT, PasRosetta, PasDemo, PasRungs, PasBench.
- Gate run (landing validation) was aborted at 176 of 294. Smokes not run.
