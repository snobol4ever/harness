#!/usr/bin/env bash
# test_gate_raku_the_dynamic_variables_distro_kernel_vm_raku_and_compiler_objects_and_a_twigil_variable_in_a_string_agree_with_rakudo.sh -- $*DISTRO, $*KERNEL, $*VM, $*RAKU, $*PERL AND $*RAKU.compiler AS OBJECTS WITH RAKUDO'S FIELDS AND STRING FORMS, AND `$*NAME` INTERPOLATED IN A DOUBLE-QUOTED STRING
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by classifying the Roast files that do not compile: `$*DISTRO.is-win`, `$*KERNEL.name`, `$*VM.name`, `$*RAKU.compiler.version` guard a large share of the platform-conditional tests).
#
# THE DEFECT, measured against Rakudo: none of $*DISTRO $*KERNEL $*VM $*RAKU $*PERL existed (`$*VM.name` was "variable '*VM' is read but never assigned", the native emitter refused the program), so every test that asks the platform a question (`skip "..." if $*DISTRO.is-win`)
# did not compile; and a `*` twigil variable inside a double-quoted string was left as literal text ("$*PID" printed $*PID, "a $*X b" printed a $*X b, "$*VM" printed $*VM).
# THE CURE: (by_name_dispatch.c rk_dyn_obj, reached from rk_pre_value) each name is built as a typed data object on first read: Distro(name version auth release desc is-win path-sep) from /etc/os-release, Kernel(name version release hardware arch bits) from uname(2),
# VM(name version osname prefix precomp-ext precomp-target) and Raku(name version auth desc compiler signature) with the Compiler(name backend version auth) it carries, the constants of the Rakudo this lane grades against (moar v2022.12, Raku v6.d); `.gist` of every one is "NAME (VERSION)" with the leading v dropped
# and `.Str` is the name (rk_dyn_text, reached from rk_obj_default_raku, rk_mu_method and rk_obj_stringify, so say / put / interpolation agree); the five names are predeclared in lower_raku.c rk_predeclared; and lower_interp_str reads `$*NAME` (rk_tree.c) as the variable *NAME.
# NOT HERE (own rows, measured): `.version` is a plain string "v24.04..." where Rakudo has a Version object (.Str drops the v, .parts, cmp against Version.new("6.c")); the Version type does not exist (`v1.2.3`, `Version.new` are refused); `$*KERNEL.gist` is "linux" in Rakudo until `.version` has been read once (its version is lazy) and SCRIP always prints the version;
# `$*VM.config`, `$*KERNEL.signals`, `$*DISTRO.release` on a non-Linux host; `"$*VM.name()"` (a method call inside a string); `$?FILE` / `$?LINE` inside a string. The machine-dependent fields (Distro.version/release/desc, Kernel.version/release) are graded by their relation to each other, never by value.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP fcdaa197c before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_dynamic_variables_distro_kernel_vm_raku_and_compiler_objects_and_a_twigil_variable_in_a_string_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_dynamic_variables_distro_kernel_vm_raku_and_compiler_objects_and_a_twigil_variable_in_a_string_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say $*VM.name;
say $*VM.version;
say $*VM.osname;
say $*VM.prefix;
say $*VM.precomp-ext;
say $*VM.precomp-target;
say $*VM.gist;
say $*VM.Str;
say $*RAKU.name;
say $*RAKU.version;
say $*RAKU.auth;
say $*RAKU.desc;
say $*RAKU.gist;
say $*RAKU.Str;
say $*RAKU.compiler.name;
say $*RAKU.compiler.backend;
say $*RAKU.compiler.version;
say $*RAKU.compiler.auth;
say $*RAKU.compiler.gist;
say $*RAKU.signature;
say $*RAKU.WHAT;
say $*DISTRO.WHAT;
say $*KERNEL.WHAT;
say $*VM.WHAT;
say $*RAKU.compiler.WHAT;
say $*DISTRO.is-win ?? "win" !! "posix";
say $*DISTRO.path-sep;
say $*DISTRO.is-win;
say $*KERNEL.name;
say $*KERNEL.bits;
say $*KERNEL.bits == 64;
say $*KERNEL.arch eq $*KERNEL.hardware;
say $*DISTRO.name eq $*DISTRO.gist.words[0];
say $*DISTRO.Str eq $*DISTRO.name;
say $*KERNEL.Str eq $*KERNEL.name;
say $*DISTRO.gist eq $*DISTRO.name ~ " (" ~ $*DISTRO.version.gist.substr(1) ~ ")";
say $*DISTRO.version.gist.starts-with("v");
say "$*VM";
say "$*RAKU";
say $*DISTRO.name.chars > 0;
say $*PERL.name;
say $*PERL.version;
say $*DISTRO.defined;
say $*KERNEL.defined;
say "pid ok" if "$*PID" eq $*PID.Str;
my $*X = 5;
say "a $*X b";
say "{$*VM.name}";
EOF
cat > "$W/w.ref" <<'EOF'
moar
v2022.12
linux
/usr
moarvm
mbc
moar (2022.12)
moar
Raku
v6.d
The Perl Foundation
(Str)
Raku (6.d)
Raku
rakudo
moar
v2022.12
Yet Another Society
rakudo (2022.12)
(Blob)
(Raku)
(Distro)
(Kernel)
(VM)
(Compiler)
posix
:
False
linux
64
True
True
True
True
True
True
True
moar
Raku
True
Raku
v6.d
True
True
pid ok
a 5 b
moar
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a dynamic-variable object or twigil-interpolation result that disagrees with Rakudo"
