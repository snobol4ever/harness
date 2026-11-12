/* bench_rusage.c — the external stopwatch, OUTSIDE both engines.
 *
 * WHY: Lon's directive s200 ("what can we do to get CPU time versus elapsed time -- actually we
 * want both; there were special system calls with nanosecond clocks, why are we not using that")
 * landed on a credibility defect, not a precision one: the cross-engine benchmark harness measured
 * each engine with ITS OWN clock (harness.inc's TIME(), self-reported -- ZT = TIME() ... ZE =
 * TIME() - ZT). Worse, the two engines' TIME() are not even the same KIND of clock: SPITBOL's is
 * CPU time (scripts/build_spitbol_oracle.sh patches zystm() to CLOCK_PROCESS_CPUTIME_ID, and
 * scripts/util_bench_snobol4_engines.sh has documented this since s13 as "patched: CPU-time ms"),
 * while SCRIP's own _TIME_ (src/runtime/core/core.c) is wall-clock (CLOCK_MONOTONIC). A "ms" figure
 * from one engine was never commensurable with a "ms" figure from the other, and self-timing is
 * the first thing hostile scrutiny attacks regardless of whose clock it is. This tool is the fix:
 * ONE external instrument, blind to which engine it is timing, that forks the target unchanged and
 * reads wait4()'s rusage on the way out -- sbl and scrip alike, same code path, same units.
 *
 * WHAT: forks argv[1..], execvp's it verbatim (the child's stdout/stderr are inherited untouched,
 * so a caller diffing a benchmark's stdout against a .ref file, or grepping a self-reported "ms:"
 * line out of it, sees nothing different), and on exit prints ONE line to ITS OWN stderr:
 *   BENCH_RUSAGE: elapsed_ns=<N> user_us=<N> sys_us=<N> maxrss_kb=<N> minflt=<N> majflt=<N> nivcsw=<N> nvcsw=<N> inblock=<N> oublock=<N> exit=<N>
 * elapsed_ns is CLOCK_MONOTONIC bracketing the fork/wait4 pair; user_us/sys_us/maxrss_kb/minflt/
 * majflt/nivcsw/nvcsw/inblock/oublock come straight out of wait4()'s rusage output for exactly this one child --
 * not a post-hoc getrusage(RUSAGE_CHILDREN) call, which would accumulate across every child a
 * process has ever reaped rather than naming this one. nivcsw (involuntary context switches) is the
 * load-contamination signal: a run the scheduler preempted mid-flight racks these up, and elapsed
 * time alone cannot tell a contaminated run from a clean one -- CPU time and nivcsw together can.
 * inblock/oublock (ru_inblock/ru_oublock, block I/O operations) are the DISK angle of the row
 * bench-triangulation-3angle three-angle law (Lon 2026-08-24: CPU/disk/elapsed, cross-proved):
 * expected ~0 for a pure in-memory kernel -- a nonzero reading is itself a finding (unexpected
 * paging or file I/O), not necessarily a defect, and is surfaced rather than silently dropped.
 *
 * HONEST LIMITS: (a) this measures ONE process invocation, not one loop iteration -- it is the
 * right layer for "how long did the whole benchmark run take", not a replacement for harness.inc's
 * internal iteration counter, which still answers "how much work got done in a fixed budget." Use
 * both, never one in place of the other. (b) maxrss_kb is the CHILD's peak alone, in kilobytes on
 * Linux (BSD reports bytes -- this tool is not tested there). (c) a single sample is one sample;
 * run it under bench_min_of_n.sh or equivalent for a number worth quoting.
 *
 * Build: gcc -O2 -o bench_rusage bench_rusage.c
 * Use:   ./bench_rusage ./scrip --run prog.sno < /dev/null       (elapsed+CPU for SCRIP)
 *        ./bench_rusage ../x64/bin/sbl -bf prog.sno < /dev/null  (elapsed+CPU for the oracle)
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: %s <cmd> [args...]\n", argv[0]); return 2; }
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    pid_t pid = fork();
    if (pid < 0) { perror("bench_rusage: fork"); return 127; }
    if (pid == 0) {
        execvp(argv[1], argv + 1);
        perror("bench_rusage: execvp");
        _exit(127);
    }
    int status;
    struct rusage ru;
    pid_t w;
    do { w = wait4(pid, &status, 0, &ru); } while (w < 0 && errno == EINTR);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    if (w < 0) { perror("bench_rusage: wait4"); return 127; }
    long long elapsed_ns = (long long)(t1.tv_sec - t0.tv_sec) * 1000000000LL + (t1.tv_nsec - t0.tv_nsec);
    long long user_us = (long long)ru.ru_utime.tv_sec * 1000000LL + ru.ru_utime.tv_usec;
    long long sys_us  = (long long)ru.ru_stime.tv_sec * 1000000LL + ru.ru_stime.tv_usec;
    int exitcode = WIFEXITED(status) ? WEXITSTATUS(status) : (WIFSIGNALED(status) ? 128 + WTERMSIG(status) : -1);
    fprintf(stderr, "BENCH_RUSAGE: elapsed_ns=%lld user_us=%lld sys_us=%lld maxrss_kb=%ld minflt=%ld majflt=%ld nivcsw=%ld nvcsw=%ld inblock=%ld oublock=%ld exit=%d\n",
            elapsed_ns, user_us, sys_us, ru.ru_maxrss, ru.ru_minflt, ru.ru_majflt, ru.ru_nivcsw, ru.ru_nvcsw, ru.ru_inblock, ru.ru_oublock, exitcode);
    return exitcode;
}
