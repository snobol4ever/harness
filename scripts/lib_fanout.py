#!/usr/bin/env python3
"""lib_fanout.py -- the python mirror of ../harness/scripts/lib_fanout.sh (ceo CEO-1333, CEO-1394): fanout_width() is
max(2, min(4, cores - demand)), where the demand is the machine's CPU demand in CPUs -- /proc/pressure/cpu "some avg10" times
cores / 100, or /proc/stat procs_running less the reader on a kernel without PSI -- and NEVER load1 (load1 read 1219 at 3 percent
PSI on 2026-10-01 when co-expression pthreads filled the run queue's count). FANOUT_TEST_LOAD plants the demand and FANOUT_PROC
plants the /proc root. A python runner that fans out (util_parser_sc_census.py's --jobs default) takes its width from here;
test_gate_fanout_ceiling.sh and test_gate_fanout_width_reads_cpu_pressure_not_load1.sh hold the two mirrors in agreement.
Run it for the number: python3 ../harness/scripts/lib_fanout.py"""
import os, sys

def _proc():
    return os.environ.get("FANOUT_PROC") or "/proc"

def fanout_cores():
    return os.cpu_count() or 1

def _read(name):
    try:
        with open(os.path.join(_proc(), name)) as f:
            return f.read().splitlines()
    except OSError:
        return []

def _pressure_avg10():
    for line in _read("pressure/cpu"):
        if line.startswith("some "):
            for field in line.split()[1:]:
                if field.startswith("avg10="):
                    return float(field[len("avg10="):])
    return None

def _procs_running():
    for line in _read("stat"):
        if line.startswith("procs_running "):
            return int(line.split()[1])
    return None

def fanout_source():
    if os.environ.get("FANOUT_TEST_LOAD"):
        return "planted"
    if _pressure_avg10() is not None:
        return "pressure"
    if _procs_running() is not None:
        return "procs_running"
    return "none"

def fanout_demand():
    src = fanout_source()
    if src == "planted":
        return float(os.environ["FANOUT_TEST_LOAD"])
    if src == "pressure":
        return round(fanout_cores() * _pressure_avg10() / 100, 2)
    if src == "procs_running":
        return float(max(0, _procs_running() - 1))
    return 0.0

def fanout_load1():
    lines = _read("loadavg")
    return float(lines[0].split()[0]) if lines else 0.0

def fanout_width():
    w = int(fanout_cores() - fanout_demand())
    return max(2, min(4, w))

if __name__ == "__main__":
    print(fanout_width())
