# BUILD-BEHAVIOUR WITNESSES — PINNED, AND THEIR POINT IS THAT THEY NEVER CHANGE

These programs are compiled by `gate_require_built_from` (../harness/scripts/lib_gate.sh) with `--compile`, and the
emitted `.s` is hashed. Nothing here is graded for CORRECTNESS and no `.ref` exists — the question is not
"is the answer right", it is "does this binary emit the same code for the same tree". So:

⛔ **DO NOT EDIT A WITNESS TO FIX A FAILING PROBE.** A changed witness changes the behaviour signature for
every tree, which silently discards the whole ledger and is indistinguishable from curing the defect.
Adding a witness is legitimate (it widens template coverage); it resets the ledger and the probe says so.

⛔ **DO NOT ADD A WITNESS THAT READS STDIN, A FILE, THE CLOCK, OR RANDOM.** The probe compiles, it never
runs — but a witness whose *emission* depends on anything outside its own text makes the signature drift
and the probe becomes a flake that everyone learns to ignore.

Coverage is chosen for TEMPLATE BREADTH, not for language balance: each witness is meant to drag in as many
`bb_*` boxes as a few lines can. b1 (Icon) reaches the relop box the 2026-09-09 defect lived in
(`x === x`, FINDING-2026-09-09-hq_P), generators, list construction and scanning; b2 (SNOBOL4) reaches
pattern matching, conditional assignment and the goto trunk; b3 (Prolog) reaches the Byrd backtracking
spine and findall.
