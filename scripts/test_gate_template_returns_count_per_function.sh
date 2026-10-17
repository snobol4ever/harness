#!/usr/bin/env bash
# test_gate_template_returns_count_per_function.sh -- the returns_plus class counts, per top-level function, every
# return beyond its first (R4: ONE return per template function, the string built from IF() terms), and never
# a lambda's own return or a return in another function of the same file (hq_templates; Lon 2026-10-01: "There is
# meant to be ONLY ONE return statement with the ONE string concatenated with IF() + IF() constructs").
# THE FIXTURE: five tiny sources planted in a scratch directory; no build, no corpus, about a second.
# FAIL-ONCE: TEMPLATE_RETURNS=<path> points the gate at another counter.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="${TEMPLATE_RETURNS:-$HERE/audit_template_returns.py}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
chk() { local want="$1" file="$2" name="$3" got; got=$(python3 "$TOOL" "$file" 2>&1); if [ "$got" = "$want" ]; then echo "  ok    $name (read $got)"; else echo "  FAIL  $name: want $want, read '$got'"; fail=1; fi; }
printf 'std::string a() {\n    return x;\n}\nstd::string b() {\n    return y;\n}\nstd::string c() {\n    return z;\n}\n' > $T/one_each.cpp
chk 0 $T/one_each.cpp "one return in each of three functions is clean (the old file-wide count read 1)"
printf 'std::string a() {\n    if (p)\n        return x;\n    return y;\n}\n' > $T/early.cpp
chk 1 $T/early.cpp "an early return and a final return in one function read 1"
printf 'std::string a() {\n    if (p) return x;\n    if (q) { return w; }\n    return y;\n}\n' > $T/three.cpp
chk 2 $T/three.cpp "three returns in one function read 2"
printf 'std::string a() {\n    return FOR(0, 3, [&](int i) {\n        return x86(i);\n    }) + FOR(0, 2, [](int j) { return x86(j); });\n}\n' > $T/lambda.cpp
chk 0 $T/lambda.cpp "a lambda's returns, multi-line and one-line, are not the function's"
printf 'extern "C" {\nint f(int a) {\n    if (a) return 1;\n    return 2;\n}\n}\nint g() { return 3; }\n' > $T/wrapped.cpp
chk 1 $T/wrapped.cpp "functions inside extern \"C\" { } are counted as functions (f reads 1, g reads 0)"
[ "$fail" = 0 ] && { echo "PASS: returns_plus counts per function"; exit 0; }
echo "GATE FAIL(1) [template_returns_count_per_function]"; exit 1
