#!/bin/bash
# lib_flag_gate.sh -- ONE AUTHORITY for CLI flag validation across vendor/suite runners. Sourced, never
# executed.
#
# THE DEFECT THIS EXISTS TO KILL (task test-icon-arizona-suite-silently-accepts-undefined-flags, GOAL
# hq_P 2026-09-03 routed by ceo CEO-175, instrument lane hq_T): test_icon_arizona_suite.sh accepted
# --strict, and any other unrecognized flag, silently -- a harness that accepts a flag it does not
# implement will one day print a board for an arm nobody ran (the false-board class, RULES.md THE
# INSTRUMENT LAWS). Auditing the sibling runners on the same pattern found three shapes of the same
# defect, never just the one named member: ignored entirely (arizona inspected only "-v"; gnu/fpc/
# csnobol4 read no argv at all), or refused with the wrong exit code and no named implemented set (jcon
# and swi both used exit=1, not the rc=2 every one of these scripts already uses one line away for
# "cannot grade this invocation" -- missing corpus, missing binary).
#
# flaggate_reject <bad-flag> <implemented-flags-string> -- never returns.
flaggate_reject() {
    echo "⛔ REFUSED-TO-GRADE rc=2: unknown flag '$1'" >&2
    echo "   implemented flags: ${2:-(none)}" >&2
    exit 2
}
