/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#define _GNU_SOURCE
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/mman.h>
#include <dlfcn.h>
#include <signal.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include "pin_va.h"
#ifndef RT_UXWIN_ARENA_VA
#error "pin_va.h names no RT_UXWIN_ARENA_VA: the Unicon window arena has no window"
#endif
#define UXA_PIECE ((size_t)64 << 20)
#define UXA_LIMIT ((size_t)1 << 40)
#define UXA_CLASSES 40
#define UXA_HEAD 16
#define UXA_FOREIGN 64
typedef struct uxa_free_s { struct uxa_free_s *next; } uxa_free_t;
typedef struct { void *caller; long n; } uxa_foreign_t;
static struct {
    pthread_mutex_t mu;
    char *base, *bump, *end;
    uxa_free_t *free[UXA_CLASSES];
    long live_bytes, peak_bytes, live_blocks, peak_blocks, allocs, frees, reuses, foreign_frees, foreign_reallocs, pieces;
    uxa_foreign_t foreign[UXA_FOREIGN];
    int nforeign, refused;
} uxa = { PTHREAD_MUTEX_INITIALIZER };
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static int uxa_class_of(size_t n) { int c = 0; size_t s = 16; while (s < n && c < UXA_CLASSES - 1) { s <<= 1; c++; } return s >= n ? c : -1; }
static size_t uxa_class_size(int c) { return (size_t)16 << c; }
static int uxa_inside(const void *p) { return uxa.base && (const char *)p >= uxa.base && (const char *)p < uxa.end; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static int uxa_grow(size_t need) {
    while ((size_t)(uxa.end - uxa.bump) < need) {
        char *want = uxa.base ? uxa.end : (char *)RT_UXWIN_ARENA_VA;
        if ((size_t)(want - (char *)RT_UXWIN_ARENA_VA) + UXA_PIECE > UXA_LIMIT) return 0;
        void *p = mmap(want, UXA_PIECE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE | MAP_FIXED_NOREPLACE, -1, 0);
        if (p != (void *)want) { if (p != MAP_FAILED) munmap(p, UXA_PIECE); uxa.refused++; return 0; }
        if (!uxa.base) uxa.base = uxa.bump = want;
        uxa.end = want + UXA_PIECE;
        uxa.pieces++;
    }
    return 1;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxa_count_foreign(void *caller, int realloc_) {
    if (realloc_) uxa.foreign_reallocs++; else uxa.foreign_frees++;
    for (int i = 0; i < uxa.nforeign; i++) if (uxa.foreign[i].caller == caller) { uxa.foreign[i].n++; return; }
    if (uxa.nforeign < UXA_FOREIGN) { uxa.foreign[uxa.nforeign].caller = caller; uxa.foreign[uxa.nforeign].n = 1; uxa.nforeign++; }
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void *uxa_take(size_t n) {
    int c = uxa_class_of(n + UXA_HEAD);
    if (c < 0) return 0;
    char *h;
    if (uxa.free[c]) { h = (char *)uxa.free[c]; uxa.free[c] = uxa.free[c]->next; uxa.reuses++; }
    else {
        size_t sz = uxa_class_size(c);
        if (!uxa_grow(sz)) return 0;
        h = uxa.bump; uxa.bump += sz;
    }
    *(size_t *)h = (size_t)c;
    uxa.allocs++; uxa.live_blocks++; uxa.live_bytes += (long)uxa_class_size(c);
    if (uxa.live_blocks > uxa.peak_blocks) uxa.peak_blocks = uxa.live_blocks;
    if (uxa.live_bytes > uxa.peak_bytes) uxa.peak_bytes = uxa.live_bytes;
    return h + UXA_HEAD;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxa_give(void *p) {
    char *h = (char *)p - UXA_HEAD; int c = (int)*(size_t *)h;
    ((uxa_free_t *)h)->next = uxa.free[c]; uxa.free[c] = (uxa_free_t *)h;
    uxa.frees++; uxa.live_blocks--; uxa.live_bytes -= (long)uxa_class_size(c);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void *uxa_malloc(size_t n) { pthread_mutex_lock(&uxa.mu); void *p = uxa_take(n ? n : 1); pthread_mutex_unlock(&uxa.mu); return p; }
void *uxa_calloc(size_t k, size_t n) { if (n && k > (size_t)-1 / n) return 0; void *p = uxa_malloc(k * n); if (p) memset(p, 0, k * n); return p; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void uxa_free(void *p) {
    if (!p) return;
    pthread_mutex_lock(&uxa.mu);
    if (uxa_inside(p)) { uxa_give(p); pthread_mutex_unlock(&uxa.mu); return; }
    uxa_count_foreign(__builtin_return_address(0), 0);
    pthread_mutex_unlock(&uxa.mu);
    free(p);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void *uxa_realloc(void *p, size_t n) {
    if (!p) return uxa_malloc(n);
    if (!n) { uxa_free(p); return 0; }
    pthread_mutex_lock(&uxa.mu);
    if (!uxa_inside(p)) { uxa_count_foreign(__builtin_return_address(0), 1); pthread_mutex_unlock(&uxa.mu); return realloc(p, n); }
    int c = (int)*(size_t *)((char *)p - UXA_HEAD);
    size_t have = uxa_class_size(c) - UXA_HEAD;
    pthread_mutex_unlock(&uxa.mu);
    if (n <= have) return p;
    void *q = uxa_malloc(n);
    if (!q) return 0;
    memcpy(q, p, have);
    uxa_free(p);
    return q;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
char *uxa_strdup(const char *s) { size_t n = strlen(s) + 1; char *p = (char *)uxa_malloc(n); if (p) memcpy(p, s, n); return p; }
char *uxa_salloc(char *s) { char *p = uxa_strdup(s); if (!p) { fprintf(stderr, "salloc(%d): out of memory\n", (int)strlen(s) + 1); exit(EXIT_FAILURE); } return p; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxa_report(void) {
    const char *path = getenv("UXWIN_ARENA_STATS");
    if (!path || !*path) return;
    FILE *f = fopen(path, "a");
    if (!f) return;
    fprintf(f, "arena\tbase=%p\tpieces=%ld\tallocs=%ld\tfrees=%ld\treuses=%ld\tpeak_bytes=%ld\tpeak_blocks=%ld\tlive_blocks=%ld\tforeign_frees=%ld\tforeign_reallocs=%ld\trefused=%d\n",
            (void *)uxa.base, uxa.pieces, uxa.allocs, uxa.frees, uxa.reuses, uxa.peak_bytes, uxa.peak_blocks, uxa.live_blocks, uxa.foreign_frees, uxa.foreign_reallocs, uxa.refused);
    for (int i = 0; i < uxa.nforeign; i++) {
        Dl_info di; const char *sym = "?", *obj = "?"; unsigned long off = 0;
        if (dladdr(uxa.foreign[i].caller, &di)) { if (di.dli_sname) sym = di.dli_sname; if (di.dli_fname) obj = di.dli_fname; off = (unsigned long)((char *)uxa.foreign[i].caller - (char *)di.dli_fbase); }
        fprintf(f, "foreign\t%s\t%s\t0x%lx\t%ld\n", sym, obj, off, uxa.foreign[i].n);
    }
    fclose(f);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxa_on_term(int sig) { uxa_report(); signal(sig, SIG_DFL); raise(sig); }
__attribute__((destructor)) static void uxa_at_exit(void) { uxa_report(); }
__attribute__((constructor)) static void uxa_measure(void) { const char *s = getenv("UXWIN_ARENA_STATS"); if (s && *s) signal(SIGTERM, uxa_on_term); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int uxa_image_destroy(XImage *im) { if (im->data) uxa_free(im->data); im->data = 0; if (im->obdata) XFree(im->obdata); XFree((char *)im); return 1; }
