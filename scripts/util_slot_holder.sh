#!/usr/bin/env bash
# util_slot_holder.sh -- THE FIXED COMMAND A GNU sem HOLDS A POOL SLOT WITH (DESIGN-PLAN fleet-queue step 18). sem runs ONLY this file, never a user's command (sem re-parses
# its argv through a shell: printf '[%s]' 'a b' 'c;d' ran d as a command, MEASURED 2026-11-05). It says HELD once the slot is taken, then holds it until stdin closes: the taker keeps the
# write end of stdin's pipe on an inherited fd, so the slot lives as long as the taker and every process that inherited the fd (the flock fd-inheritance semantic, kept).
echo HELD
exec cat > /dev/null
