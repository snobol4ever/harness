# harness/fixtures/test_gate_icn_rundir_contract -- the one run-directory program the icon master cannot hold yet (the coo 2026-11-12)

Moved here from corpus/tests/icon with its sidecars, its fixtures folder and its stdin from corpus/tests/icon/config (Lon 2026-11-12 10:2x
CST: "I'm not liking #/corpus/tests/icon/{config,rung36_bullshit,unicon} folders."). `test_gate_icn_rundir_contract.sh` grades it in its
run directory, both arms, against the live Arizona oracle (GATE PASS 2026-11-12).

`rung36_jcon_recent.icn` (with `.ref`, `.argv`, `.env`, `.heap`, `.stack`, `.stdin` and `rung36_jcon_recent.fixtures/`) stays out of
the master because its answer reads its run directory and its environment: it prints `getenv("JCONT")` (`.env`: `JCONT=../bin/jcont`)
and lists the files beside it (`Makefile`, `recent.icn`, `recogn.dat`). The master has no env fence yet (Lon 2026-11-12: a test has
`.env`; the cio's harness item); once it has one, the program enters as `rung36_jcon_recent__recent` staged as `recent.icn` with its
three fixtures as file fences (`util_add_ladder_witness.py --file`, as `rung36_jcon_io__io` did), and this folder leaves.
