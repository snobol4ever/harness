/* ipl_pin_shim.c -- the NAME.pin sidecar's LD_PRELOAD shim (hq_icon 2026-09-27, ceo CEO-1315; Lon's word "Get IPL to 843.").        */
/* A program that reads the clock or seeds from entropy is graded by pinning both for BOTH participants: the cutter's iconx and SCRIP */
/* m3/m4 run under this one shim, so the ref and the run come from the same world. Wall clock: 2001-09-09 01:46:40 UTC (1000000000). */
/* THE CLOCK IS VIRTUAL (row instruments-the-ipl-pin-shim-advances-its-virtual-clock-through-sleeps, ceo CEO-1483): it starts at PIN_EPOCH and advances by exactly the slept duration on every sleep entry (nanosleep, clock_nanosleep, usleep, sleep, select and poll with no fds and a timeout) without sleeping for real, and every clock read answers it; a program that reads the clock more than PIN_SPIN_READS times with no sleep between is busy-waiting on it (IPL progs/hr's wait(), a loop on &clock), and each further read advances the clock by PIN_SPIN_TICK_NS, so the spin ends at the same point for both participants while a program that reads the clock a few times sees exactly the slept time -- wall clock PIN_EPOCH + v; monotonic, CPU, times(), clock() and getrusage() v -- so a paced program runs deterministically and at once. Before any sleep every clock reads as it did: wall PIN_EPOCH, the rest zero. /dev/urandom and /dev/random serve a fixed byte stream (an xorshift from a fixed seed) and     */
/* getrandom() the same stream. The host name reads "scriphost" (gethostname, uname), inherited by every command a program pipes to.  */
/* Built on demand by lib_icon_ipl_isolation.sh (ipl_pin_shim_path); never linked into SCRIP itself.                               */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <poll.h>
#include <sys/random.h>
#include <sys/select.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>
#include <sys/types.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>
#define PIN_EPOCH 1000000000L
static uint64_t pin_state = 0x9E3779B97F4A7C15ULL;
static unsigned char pin_next_byte(void) { pin_state ^= pin_state << 13; pin_state ^= pin_state >> 7; pin_state ^= pin_state << 17; return (unsigned char)(pin_state & 0xFF); }
static void pin_fill(void *buf, size_t n) { unsigned char *p = (unsigned char *)buf; for (size_t i = 0; i < n; i++) p[i] = pin_next_byte(); }
static int64_t pin_vns = 0;
static long pin_reads = 0;
#define PIN_SPIN_READS 10000L
#define PIN_SPIN_TICK_NS 1000000LL
static void pin_advance(int64_t ns) { if (ns > 0) pin_vns += ns; pin_reads = 0; }
static void pin_read(void) { if (++pin_reads > PIN_SPIN_READS) pin_vns += PIN_SPIN_TICK_NS; }
static int64_t pin_ts_ns(const struct timespec *t) { return t ? (int64_t)t->tv_sec * 1000000000LL + t->tv_nsec : 0; }
static int64_t pin_tv_ns(const struct timeval *t) { return t ? (int64_t)t->tv_sec * 1000000000LL + (int64_t)t->tv_usec * 1000LL : 0; }
time_t time(time_t *t) { pin_read(); time_t v = PIN_EPOCH + (time_t)(pin_vns / 1000000000LL); if (t) *t = v; return v; }
int gettimeofday(struct timeval *tv, void *tz) { pin_read(); (void)tz; if (tv) { tv->tv_sec = PIN_EPOCH + pin_vns / 1000000000LL; tv->tv_usec = (pin_vns % 1000000000LL) / 1000; } return 0; }
int clock_gettime(clockid_t id, struct timespec *ts) { pin_read(); if (!ts) return 0; int64_t v = pin_vns; if (id == CLOCK_REALTIME || id == CLOCK_REALTIME_COARSE) v += (int64_t)PIN_EPOCH * 1000000000LL; ts->tv_sec = v / 1000000000LL; ts->tv_nsec = v % 1000000000LL; return 0; }
clock_t clock(void) { pin_read(); return (clock_t)(pin_vns / (1000000000LL / CLOCKS_PER_SEC)); }
clock_t times(struct tms *b) { pin_read(); long hz = sysconf(_SC_CLK_TCK); clock_t c = (clock_t)(pin_vns / (1000000000LL / (hz > 0 ? hz : 100))); if (b) { memset(b, 0, sizeof *b); b->tms_utime = c; } return c; }
int getrusage(int who, struct rusage *u) { pin_read(); (void)who; if (u) { memset(u, 0, sizeof *u); u->ru_utime.tv_sec = pin_vns / 1000000000LL; u->ru_utime.tv_usec = (pin_vns % 1000000000LL) / 1000; } return 0; }
int nanosleep(const struct timespec *req, struct timespec *rem) { pin_advance(pin_ts_ns(req)); if (rem) rem->tv_sec = rem->tv_nsec = 0; return 0; }
int clock_nanosleep(clockid_t id, int flags, const struct timespec *req, struct timespec *rem) {
    if (flags & TIMER_ABSTIME) { struct timespec now; clock_gettime(id, &now); pin_advance(pin_ts_ns(req) - pin_ts_ns(&now)); }
    else pin_advance(pin_ts_ns(req));
    if (rem) rem->tv_sec = rem->tv_nsec = 0; return 0;
}
int usleep(useconds_t us) { pin_advance((int64_t)us * 1000LL); return 0; }
unsigned int sleep(unsigned int s) { pin_advance((int64_t)s * 1000000000LL); return 0; }
int select(int n, fd_set *r, fd_set *w, fd_set *e, struct timeval *tv) {
    static int (*real_select)(int, fd_set *, fd_set *, fd_set *, struct timeval *) = 0;
    if (tv && (n == 0 || (!r && !w && !e))) { pin_advance(pin_tv_ns(tv)); tv->tv_sec = tv->tv_usec = 0; return 0; }
    if (!real_select) real_select = (int (*)(int, fd_set *, fd_set *, fd_set *, struct timeval *))dlsym(RTLD_NEXT, "select");
    return real_select(n, r, w, e, tv);
}
int poll(struct pollfd *fds, nfds_t n, int ms) {
    static int (*real_poll)(struct pollfd *, nfds_t, int) = 0;
    if (n == 0 && ms > 0) { pin_advance((int64_t)ms * 1000000LL); return 0; }
    if (!real_poll) real_poll = (int (*)(struct pollfd *, nfds_t, int))dlsym(RTLD_NEXT, "poll");
    return real_poll(fds, n, ms);
}
#define PIN_HOST "scriphost"
int gethostname(char *n, size_t l) { if (!n || l == 0) return 0; strncpy(n, PIN_HOST, l); n[l - 1] = 0; return 0; }
int uname(struct utsname *u) { static int (*real_uname)(struct utsname *) = 0; if (!real_uname) real_uname = (int (*)(struct utsname *))dlsym(RTLD_NEXT, "uname"); int r = real_uname(u); if (u) { strncpy(u->nodename, PIN_HOST, sizeof u->nodename); u->nodename[sizeof u->nodename - 1] = 0; } return r; }
ssize_t getrandom(void *buf, size_t n, unsigned int flags) { (void)flags; pin_fill(buf, n); return (ssize_t)n; }
static int pin_fd = -1;
static int pin_is_entropy(const char *p) { return p && (!strcmp(p, "/dev/urandom") || !strcmp(p, "/dev/random")); }
static int pin_open_entropy(void) { static int (*real_open)(const char *, int, ...) = 0; if (!real_open) real_open = (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open"); pin_fd = real_open("/dev/null", O_RDONLY); return pin_fd; }
int open(const char *p, int fl, ...) {
    static int (*real_open)(const char *, int, ...) = 0; mode_t m = 0;
    if (fl & O_CREAT) { va_list ap; va_start(ap, fl); m = (mode_t)va_arg(ap, int); va_end(ap); }
    if (pin_is_entropy(p)) return pin_open_entropy();
    if (!real_open) real_open = (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open");
    return real_open(p, fl, m);
}
int open64(const char *p, int fl, ...) {
    static int (*real_open64)(const char *, int, ...) = 0; mode_t m = 0;
    if (fl & O_CREAT) { va_list ap; va_start(ap, fl); m = (mode_t)va_arg(ap, int); va_end(ap); }
    if (pin_is_entropy(p)) return pin_open_entropy();
    if (!real_open64) real_open64 = (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open64");
    return real_open64(p, fl, m);
}
ssize_t read(int fd, void *buf, size_t n) {
    static ssize_t (*real_read)(int, void *, size_t) = 0;
    if (fd >= 0 && fd == pin_fd) { pin_fill(buf, n); return (ssize_t)n; }
    if (!real_read) real_read = (ssize_t (*)(int, void *, size_t))dlsym(RTLD_NEXT, "read");
    return real_read(fd, buf, n);
}
FILE *fopen(const char *p, const char *mode) {
    static FILE *(*real_fopen)(const char *, const char *) = 0;
    if (!real_fopen) real_fopen = (FILE *(*)(const char *, const char *))dlsym(RTLD_NEXT, "fopen");
    if (pin_is_entropy(p)) { FILE *f = real_fopen("/dev/null", "r"); if (f) { pin_fd = fileno(f); setvbuf(f, 0, _IONBF, 0); } return f; }
    return real_fopen(p, mode);
}
FILE *fopen64(const char *p, const char *mode) { return fopen(p, mode); }
size_t fread(void *buf, size_t sz, size_t n, FILE *f) {
    static size_t (*real_fread)(void *, size_t, size_t, FILE *) = 0;
    if (f && pin_fd >= 0 && fileno(f) == pin_fd) { pin_fill(buf, sz * n); return n; }
    if (!real_fread) real_fread = (size_t (*)(void *, size_t, size_t, FILE *))dlsym(RTLD_NEXT, "fread");
    return real_fread(buf, sz, n, f);
}
int fgetc(FILE *f) {
    static int (*real_fgetc)(FILE *) = 0;
    if (f && pin_fd >= 0 && fileno(f) == pin_fd) return pin_next_byte();
    if (!real_fgetc) real_fgetc = (int (*)(FILE *))dlsym(RTLD_NEXT, "fgetc");
    return real_fgetc(f);
}
int getc(FILE *f) { return fgetc(f); }
int getc_unlocked(FILE *f) {
    static int (*real_getc_unlocked)(FILE *) = 0;
    if (f && pin_fd >= 0 && fileno(f) == pin_fd) return pin_next_byte();
    if (!real_getc_unlocked) real_getc_unlocked = (int (*)(FILE *))dlsym(RTLD_NEXT, "getc_unlocked");
    return real_getc_unlocked(f);
}
int fgetc_unlocked(FILE *f) { return getc_unlocked(f); }
char *fgets(char *s, int n, FILE *f) {
    static char *(*real_fgets)(char *, int, FILE *) = 0;
    if (f && pin_fd >= 0 && fileno(f) == pin_fd) { if (!s || n <= 0) return 0; int i = 0; while (i < n - 1) { s[i] = (char)pin_next_byte(); if (s[i++] == '\n') break; } s[i] = 0; return s; }
    if (!real_fgets) real_fgets = (char *(*)(char *, int, FILE *))dlsym(RTLD_NEXT, "fgets");
    return real_fgets(s, n, f);
}
/* A closed entropy descriptor is forgotten, so a later file the kernel hands the same number reads the file (the coo's review of 569bf02c6). */
int close(int fd) {
    static int (*real_close)(int) = 0;
    if (fd >= 0 && fd == pin_fd) pin_fd = -1;
    if (!real_close) real_close = (int (*)(int))dlsym(RTLD_NEXT, "close");
    return real_close(fd);
}
int fclose(FILE *f) {
    static int (*real_fclose)(FILE *) = 0;
    if (f && pin_fd >= 0 && fileno(f) == pin_fd) pin_fd = -1;
    if (!real_fclose) real_fclose = (int (*)(FILE *))dlsym(RTLD_NEXT, "fclose");
    return real_fclose(f);
}
