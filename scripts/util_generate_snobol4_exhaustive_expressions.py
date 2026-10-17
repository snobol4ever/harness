#!/usr/bin/env python3
"""util_generate_snobol4_exhaustive_expressions.py -- exhaustive SNOBOL4 expression-program generator,
graded against the shared correctness oracle (seat16, row snobol4-generator-exhaustive-expressions-graded-
against-the-oracle, hq_T / GENERATORS lane, FLEET-20).

WHAT THIS IS: a grammar-based EXHAUSTIVE (not random) generator over a small, explicit vocabulary. Each
generated program is a single `OUTPUT = <expr>` statement, run through both scrip (mode-3 --run, the
default) and the shared oracle (sbl -bf, via lib_oracle_flags.sh's sbl_correctness_bin -- reimplemented
here as a plain path since this is Python, not bash; the flag and binary are the SAME ones that file names).
A mismatch is a divergence: the program and the oracle's own output are written out as a witness pair
(<name>.sno / <name>.ref) for a human or HQ to absorb into corpus/tests/snobol4/ALL.* -- this script never
writes into corpus/ itself. This seat lands generators and witnesses, never compiler fixes (task file, THE
ROW): a divergence here routes to hq_P (SNOBOL4 lane owner), or to hq_U if it implicates a shared node.

RUNGS: exhaustive-and-hand-checkable population, one rung at a time (task file, FIRST RUNG). Rung 1 is
length-1 and length-2 expressions over ONE operator ('+'): single decimal digits 0-9 as every length-1
operand (10 programs), and every ordered pair combined with '+' as every length-2 expression (10*10 = 100
programs) -- population 110, exactly, by construction. Rung 2 widens the length-2 operator vocabulary to
('+', '-', '*') over the same single-digit operands: 10 (length-1, unchanged) + 10*10*3 (length-2) = 310,
exactly. Each rung's own population is fixed at the row that adds it -- adding a later rung never changes
an earlier one's count, so a fixed rung's denominator never drifts under this script.

EXIT: 0 ran to completion (see --out-dir/report.txt and the printed SUMMARY line for pass/fail data; this
script itself does not decide gate pass/fail -- test_gate_generator_oracle_agreement.sh does) · 2 REFUSED
(could not generate or grade: scrip/oracle missing or not executable, oracle fails its -bf capability
probe, or the computed population is empty -- never a silent zero).
"""
import argparse
import os
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = (HERE.parent.parent / "SCRIP")
DEFAULT_SCRIP = ROOT / "scrip"
DEFAULT_ORACLE = pathlib.Path("/home/resources/x64/bin/sbl")
TIMEOUT_S = 10


def op_name(op):
    return {"+": "plus", "-": "minus", "*": "times"}[op]


RUNG_OPERATORS = {1: ("+",), 2: ("+", "-", "*")}


def rung_population(rung):
    if rung not in RUNG_OPERATORS:
        raise ValueError(f"no such rung: {rung} (only rung(s) {sorted(RUNG_OPERATORS)} exist so far)")
    digits = [str(d) for d in range(10)]
    programs = []
    for a in digits:
        programs.append((f"len1_{a}", f"\tOUTPUT = {a}\nEND\n"))
    for op in RUNG_OPERATORS[rung]:
        for a in digits:
            for b in digits:
                programs.append((f"len2_{a}_{op_name(op)}_{b}", f"\tOUTPUT = {a} {op} {b}\nEND\n"))
    return programs


def run_capture(binpath, extra_args, src_path):
    try:
        p = subprocess.run([str(binpath), *extra_args, str(src_path)], stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=TIMEOUT_S)
        return p.stdout.decode("utf-8", "replace"), p.returncode, None
    except subprocess.TimeoutExpired:
        return "", None, "TIMEOUT"
    except OSError as e:
        return "", None, f"OSERROR:{e}"


def oracle_is_bf_capable(oracle, work_dir):
    probe = work_dir / "_oracle_bf_capability_probe.sno"
    probe.write_text("\tOUTPUT = 'sblbfok'\nEND\n")
    out, _rc, err = run_capture(oracle, ["-bf"], probe)
    return err is None and "sblbfok" in out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--rung", type=int, default=1)
    ap.add_argument("--out-dir", required=True, help="scratch dir for generated programs, witnesses, report")
    ap.add_argument("--scrip", default=str(DEFAULT_SCRIP))
    ap.add_argument("--oracle", default=str(DEFAULT_ORACLE))
    args = ap.parse_args()

    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not os.access(args.scrip, os.X_OK):
        print(f"REFUSED-TO-GRADE rc=2: scrip is not executable at {args.scrip} -- run make", file=sys.stderr)
        return 2
    if not os.access(args.oracle, os.X_OK):
        print(f"REFUSED-TO-GRADE rc=2: oracle is not executable at {args.oracle}", file=sys.stderr)
        return 2
    if not oracle_is_bf_capable(args.oracle, out_dir):
        print(f"REFUSED-TO-GRADE rc=2: oracle at {args.oracle} failed its -bf capability probe "
              f"(dead oracle, or a build that rejects -bf -- s189/hq_P s259 shape)", file=sys.stderr)
        return 2

    try:
        population = rung_population(args.rung)
    except ValueError as e:
        print(f"REFUSED-TO-GRADE rc=2: {e}", file=sys.stderr)
        return 2

    generated = len(population)
    if generated == 0:
        print("REFUSED-TO-GRADE rc=2: computed population is empty (0 programs) -- vacuous run", file=sys.stderr)
        return 2

    graded = 0
    infra_failed = []
    diverged = []
    report_lines = [f"rung={args.rung} scrip={args.scrip} oracle={args.oracle}"]
    for name, src in population:
        srcfile = out_dir / f"{name}.sno"
        srcfile.write_text(src)
        got, got_rc, got_err = run_capture(args.scrip, [], srcfile)
        want, want_rc, want_err = run_capture(args.oracle, ["-bf"], srcfile)
        if got_err or want_err:
            infra_failed.append((name, got_err, want_err))
            report_lines.append(f"INFRA-FAIL {name}: scrip_err={got_err} oracle_err={want_err}")
            continue
        graded += 1
        if got.rstrip("\n") != want.rstrip("\n"):
            diverged.append((name, src, got, want))

    for name, src, got, want in diverged:
        (out_dir / f"{name}.ref").write_text(want)
        line = f"DIVERGE {name}: src={src!r} scrip={got!r} oracle={want!r}"
        print(f"  {line}")
        report_lines.append(line)

    report_lines.append(f"SUMMARY generated={generated} graded={graded} "
                         f"infra_failed={len(infra_failed)} diverged={len(diverged)}")
    (out_dir / "report.txt").write_text("\n".join(report_lines) + "\n")

    print(f"SUMMARY generated={generated} graded={graded} "
          f"infra_failed={len(infra_failed)} diverged={len(diverged)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
