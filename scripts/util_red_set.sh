#!/usr/bin/env bash
# util_red_set.sh [--at REF] [--reds] [--suite KEY] [--vs REF] [--results FILE] -- the red set per origin hash, read in one command
# (box-scheduler step 20, CTO-496). A thin door on util_red_set.py, which reads the coo's results.tsv and writes nothing; see its header.
exec python3 -I "$(dirname "${BASH_SOURCE[0]}")/util_red_set.py" "$@"
