#!/usr/bin/env bash
# install_jvm_dotnet_perf_tools.sh -- the profiling kit for the JVM and .NET ports (Lon's ask, 2026-10-31 17:4x CDT).
#
#   sudo bash harness/scripts/install_jvm_dotnet_perf_tools.sh          # everything; re-runnable; prints a usage card at the end
#   bash harness/scripts/install_jvm_dotnet_perf_tools.sh --check      # no changes: report what is present and what is missing
#
# WHAT IT INSTALLS (Ubuntu 24.04, x86-64), and what each is for:
#   perf (linux-tools)            the CPU's own counters: `perf stat -e instructions:u` is how CEO-2035 counts WORK for the ports (callgrind
#                                 cannot follow a JIT at a usable speed); `perf record -g` is the call-graph statistical profiler for both runtimes
#                                 once the JIT publishes its symbol map (JVM: jcmd <pid> Compiler.perfmap, or -XX:+UnlockDiagnosticVMOptions
#                                 -XX:+DumpPerfMapAtExit; .NET: DOTNET_PerfMapEnabled=1). hotspot (GUI) and FlameGraph read perf's output.
#   valgrind + kcachegrind        callgrind/cachegrind for the NATIVE side (scrip, libscrip_rt, the oracles); kept for the C half of a port.
#   async-profiler (/opt)         the JVM's sampling profiler: cpu, wall, alloc, lock, and -e instructions (retired instructions by frame, the
#                                 nearest thing to callgrind on a JIT); flame graphs, collapsed stacks, JFR output. Attaches to a live pid
#                                 (asprof) or loads as an agent (-agentpath). Also the `jfrconv` converter.
#   JDK Flight Recorder           already in the JDK (jcmd, jfr): -XX:StartFlightRecording=duration=60s,filename=x.jfr; `jfr print --events
#                                 jdk.ExecutionSample x.jfr`; `jfr view hot-methods x.jfr` (JDK 21). Nothing to install; the card shows the use.
#   dotnet-trace / -counters /    the .NET EventPipe tools: `dotnet-trace collect -p <pid> --profile cpu-sampling` (speedscope or nettrace
#   -dump / -gcdump / -stack /    output), `dotnet-counters monitor`, `dotnet-stack report`, `dotnet-gcdump`, `dotnet-dump analyze` with SOS.
#   -symbol / -sos                Installed per USER (dotnet tool), for the invoking user when run under sudo.
#   perfcollect                   Microsoft's script that drives perf + LTTng for a .NET process and bundles the JIT map; `perfcollect install`
#                                 pulls lttng-tools and liblttng-ust; `perfcollect collect name -pid <pid>`; the .trace.zip opens in PerfView
#                                 (Windows) or is converted with perf script + FlameGraph here.
#   FlameGraph (/opt)             Brendan Gregg's scripts: stackcollapse-perf.pl | flamegraph.pl > x.svg, for perf, async-profiler and dotnet.
#   speedscope (npm, optional)    the browser viewer of dotnet-trace's --format speedscope and async-profiler's collapsed output; installed only
#                                 when nodejs/npm are present or can be installed by apt.
#   gprof2dot + graphviz          call GRAPHS (dot) from perf script, callgrind.out and dotnet-trace's speedscope files: a picture of who calls whom.
#   sysctl                        kernel.perf_event_paranoid stays 1 (a user profiles their own processes, hardware counters included);
#                                 kernel.kptr_restrict=0 so perf resolves kernel symbols. Persisted in /etc/sysctl.d/99-s4e-perf.conf.
# BENCHMARK HARNESSES are per project, not per box: JMH (or criterium for Clojure) goes in the JVM port's project.clj / pom; BenchmarkDotNet
# is a NuGet package of the .NET port's bench project. The card at the end says how to add them.
set -u
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1
AP_DIR=/opt/async-profiler
FG_DIR=/opt/FlameGraph
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
as_user() { if [ "$(id -un)" = "$TARGET_USER" ]; then "$@"; else sudo -u "$TARGET_USER" -H "$@"; fi; }
say()  { printf '\033[1m%s\033[0m\n' "$*"; }
have() { command -v "$1" > /dev/null 2>&1; }
status() {
    say "== profiling kit status (user $TARGET_USER)"
    for t in perf valgrind kcachegrind hotspot java jcmd jfr dotnet dot gprof2dot node npm speedscope perfcollect lttng; do
        printf '  %-12s %s\n' "$t" "$(command -v "$t" 2>/dev/null || echo MISSING)"
    done
    printf '  %-12s %s\n' "asprof" "$( [ -x "$AP_DIR/bin/asprof" ] && echo "$AP_DIR/bin/asprof ($("$AP_DIR/bin/asprof" --version 2>/dev/null | head -1))" || echo MISSING)"
    printf '  %-12s %s\n' "FlameGraph" "$( [ -x "$FG_DIR/flamegraph.pl" ] && echo "$FG_DIR" || echo MISSING)"
    printf '  %-12s %s\n' "dotnet tools" "$(as_user dotnet tool list -g 2>/dev/null | awk 'NR>2 {printf "%s ", $1}')"
    printf '  %-12s paranoid=%s kptr_restrict=%s\n' "sysctl" "$(sysctl -n kernel.perf_event_paranoid 2>/dev/null)" "$(sysctl -n kernel.kptr_restrict 2>/dev/null)"
    java -version 2>&1 | head -1 | sed 's/^/  java: /'; dotnet --version 2>/dev/null | sed 's/^/  dotnet: /'
}
if [ "$CHECK" = 1 ]; then status; exit 0; fi
[ "$(id -u)" = 0 ] || { echo "run it as root: sudo bash $0   (or --check for a report)"; exit 2; }
export DEBIAN_FRONTEND=noninteractive
say "== 1/7 apt: perf, valgrind, kcachegrind, hotspot, graphviz, lttng (for perfcollect), nodejs+npm (for speedscope)"
apt-get update -qq
apt-get install -y -qq linux-tools-common "linux-tools-$(uname -r)" linux-tools-generic valgrind kcachegrind hotspot graphviz \
    lttng-tools liblttng-ust-dev nodejs npm curl unzip python3-pip > /tmp/s4e-perf-apt.log 2>&1 || { echo "apt had trouble; the log is /tmp/s4e-perf-apt.log (continuing)"; }
say "== 2/7 async-profiler (latest release) -> $AP_DIR"
tag="$(curl -fsSL https://api.github.com/repos/async-profiler/async-profiler/releases/latest | sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p' | head -1)"
if [ -n "$tag" ]; then
    ver="${tag#v}"
    if [ -x "$AP_DIR/bin/asprof" ] && "$AP_DIR/bin/asprof" --version 2>/dev/null | grep -q "$ver"; then
        echo "  async-profiler $ver already in place"
    else
        tmp="$(mktemp -d)"
        if curl -fsSL -o "$tmp/ap.tar.gz" "https://github.com/async-profiler/async-profiler/releases/download/$tag/async-profiler-$ver-linux-x64.tar.gz"; then
            rm -rf "$AP_DIR" && mkdir -p "$AP_DIR" && tar -xzf "$tmp/ap.tar.gz" -C "$AP_DIR" --strip-components=1 && echo "  async-profiler $ver installed"
            printf 'export PATH=$PATH:%s/bin\n' "$AP_DIR" > /etc/profile.d/async-profiler.sh
        else
            echo "  download failed for $tag (continuing)"
        fi
        rm -rf "$tmp"
    fi
else
    echo "  could not read the latest release tag from GitHub (continuing)"
fi
say "== 3/7 FlameGraph -> $FG_DIR"
if [ -d "$FG_DIR/.git" ]; then git -C "$FG_DIR" pull -q --ff-only || true; else git clone -q https://github.com/brendangregg/FlameGraph "$FG_DIR" || echo "  clone failed (continuing)"; fi
[ -x "$FG_DIR/flamegraph.pl" ] && printf 'export PATH=$PATH:%s\n' "$FG_DIR" > /etc/profile.d/flamegraph.sh
say "== 4/7 .NET diagnostic tools for user $TARGET_USER (dotnet tool, per user)"
for t in dotnet-trace dotnet-counters dotnet-dump dotnet-gcdump dotnet-stack dotnet-symbol dotnet-sos; do
    if as_user dotnet tool list -g 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "$t"; then as_user dotnet tool update -g "$t" > /dev/null 2>&1 && echo "  $t up to date"; else as_user dotnet tool install -g "$t" > /dev/null 2>&1 && echo "  $t installed" || echo "  $t FAILED (continuing)"; fi
done
as_user dotnet sos install > /dev/null 2>&1 && echo "  SOS installed for dotnet-dump analyze" || true
grep -q '\.dotnet/tools' "$TARGET_HOME/.profile" 2>/dev/null || { printf '\nexport PATH="$PATH:$HOME/.dotnet/tools"\n' >> "$TARGET_HOME/.profile"; chown "$TARGET_USER" "$TARGET_HOME/.profile"; }
say "== 5/7 perfcollect -> /usr/local/bin/perfcollect"
if curl -fsSL -o /usr/local/bin/perfcollect https://aka.ms/perfcollect; then chmod +x /usr/local/bin/perfcollect; /usr/local/bin/perfcollect install > /tmp/s4e-perfcollect-install.log 2>&1 && echo "  perfcollect installed (its own prerequisites via apt)" || echo "  perfcollect install reported trouble; log /tmp/s4e-perfcollect-install.log (continuing)"; else echo "  perfcollect download failed (continuing)"; fi
say "== 6/7 speedscope (npm) and gprof2dot (pip, user $TARGET_USER)"
if have npm; then npm install -g speedscope > /tmp/s4e-speedscope.log 2>&1 && echo "  speedscope installed" || echo "  speedscope failed; log /tmp/s4e-speedscope.log (continuing)"; else echo "  no npm, speedscope skipped"; fi
as_user python3 -m pip install -q --user --break-system-packages gprof2dot > /dev/null 2>&1 && echo "  gprof2dot installed" || as_user python3 -m pip install -q --user gprof2dot > /dev/null 2>&1 && echo "  gprof2dot installed" || echo "  gprof2dot failed (continuing)"
say "== 7/7 sysctl: perf for a user's own processes with hardware counters; kernel symbols readable"
printf 'kernel.perf_event_paranoid = 1\nkernel.kptr_restrict = 0\n' > /etc/sysctl.d/99-s4e-perf.conf && sysctl -q --system > /dev/null 2>&1
status
cat <<'CARD'

== THE USAGE CARD (open a new shell first, so PATH picks up /opt/async-profiler/bin, /opt/FlameGraph and ~/.dotnet/tools)
JVM, instruction count of one run (CEO-2035's measure):   perf stat -e instructions:u -- java -jar app.jar args
JVM, statistical call graph, live pid, flame graph:        asprof -d 30 -e cpu -f /tmp/cpu.html <pid>        (-e instructions | wall | alloc | lock)
JVM, the same as collapsed stacks for gprof2dot/FlameGraph: asprof -d 30 -o collapsed -f /tmp/st.txt <pid>; flamegraph.pl /tmp/st.txt > /tmp/st.svg
JVM, from the start, as an agent:                          java -agentpath:/opt/async-profiler/lib/libasyncProfiler.so=start,event=cpu,file=/tmp/p.html -jar app.jar
JVM, JFR (no install):                                     java -XX:StartFlightRecording=duration=60s,filename=/tmp/r.jfr -jar app.jar; jfr view hot-methods /tmp/r.jfr; jfr print --events jdk.ExecutionSample /tmp/r.jfr
JVM, perf with JIT symbols:                                java -XX:+UnlockDiagnosticVMOptions -XX:+DumpPerfMapAtExit ... & perf record -g -p <pid>; perf report   (or: jcmd <pid> Compiler.perfmap)
.NET, instruction count of one run:                        perf stat -e instructions:u -- dotnet app.dll args
.NET, sampling call graph (speedscope):                    dotnet-trace collect -p <pid> --profile cpu-sampling --format speedscope -o /tmp/t.speedscope.json; speedscope /tmp/t.speedscope.json
.NET, perf with JIT symbols:                               DOTNET_PerfMapEnabled=1 dotnet app.dll & perf record -g -p <pid>; perf report
.NET, the full bundle (perf + LTTng + maps):               perfcollect collect mytrace -pid <pid>      (DOTNET_PerfMapEnabled=1 set on the target)
.NET, counters / stacks / heaps:                           dotnet-counters monitor -p <pid>; dotnet-stack report -p <pid>; dotnet-gcdump collect -p <pid>
Native (scrip, libscrip_rt, an oracle):                    valgrind --tool=callgrind ./prog; kcachegrind callgrind.out.<pid>; or perf record -g ./prog; hotspot perf.data
Call graph pictures from any of the above:                 perf script | gprof2dot -f perf | dot -Tsvg -o cg.svg;   gprof2dot -f callgrind callgrind.out.<pid> | dot -Tsvg -o cg.svg
Benchmark harnesses (per project): JVM -> JMH (org.openjdk.jmh) or criterium for Clojure, in the port's project file; .NET -> BenchmarkDotNet (dotnet add package BenchmarkDotNet) in the port's bench project.
CARD
