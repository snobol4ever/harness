# Suite run 2026-10-27: Prolog, Icon, Pascal (partial)

Partial record, written while the run was in progress. Only suites listed in `results.tsv` have finished.

- Runner: `harness/scripts/test_*_suite.sh`, one at a time, from the g4 layout (SCRIP at `main` c33d10f).
- Guard: the one-runner guard refused this session (no seat, no LANES line). It was overridden with `S4E_ONE_RUNNER_OVERRIDE` because the session runs in the cloud, not on the owner's Linux machine.
- Score rows: not written (`S4E_SCORE_WRITE` unset). The score writer refused as expected (`REFUSED(2) util_score_row`).
- Skipped by request: Logtalk (4h32m) and ProPuzzles (2h44m), as the very long suites.
- Still to run at time of writing: SWI (in progress, `--jobs 1`), GNU, ProDemo, ProRosetta, Trealla, XSB, ProRungs, ProBench, Zona, Jcon, IPL, IcnDemo, IcnRungs, IcnBench, FPC, PAT, PasRosetta, PasDemo, PasRungs, PasBench.
- Gate run (landing validation) was aborted at 176 of 294. Smokes not run.

## Final state (run ended Oct 27, 15:58 UTC)
- SWI was interrupted mid-run; its partial log is `logs/SWI.partial.log`. No SWI result.
- The other 20 suites never ran.
- Gates: `gates/gates.txt` holds 176 of 294 gate results from the landing validation. Aborted there, with the smokes and the no-spine check never run.
- `notes/` holds the working notes, the landing commit draft, and the witness comparisons (`witcmp.out`, `wittri.out`).
