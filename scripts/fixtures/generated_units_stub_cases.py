# generated_units_stub_cases.py -- the stub generator of test_gate_generated_units_build_and_grade_by_verdict_line.sh (CIO-22 D, the coo 2026-11-10).
# CONTRACT units=generated with generator=fixtures/generated_units_stub_cases: cases(pkg_dir) yields one dict per entry of the scratch package's
# ALL.csv -- name, program, ref (one verdict line), cwd -- or name and reason for a case it cannot plan. Each case is one arm of the gate.


def cases(pkg_dir):
    yield {"name": "says_succ_among_noise", "cwd": ".", "ref": "@V succ",
           "program": ":- write(noise), nl, write('@V succ'), nl, write(more), nl.\n"}
    yield {"name": "reads_its_cwd", "cwd": "sub", "ref": "@V hello",
           "program": ":- open('data.txt', read, S), read(S, T), close(S), write('@V '), write(T), nl.\n"}
    yield {"name": "says_fail", "cwd": ".", "ref": "@V succ",
           "program": ":- write('@V fail'), nl.\n"}
    yield {"name": "says_nothing", "cwd": ".", "ref": "@V succ",
           "program": ":- write(hello), nl.\n"}
    yield {"name": "excluded_by_name", "cwd": ".", "ref": "@V succ",
           "program": ":- write('@V succ'), nl.\n"}
    yield {"name": "cannot_plan", "reason": "the stub's one case with no plan"}
