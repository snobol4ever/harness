/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#define DT_BLK uxw_unicon_DT_BLK
#include "h/rt.h"
#undef DT_BLK
#include "ir/descr.h"
#include <sys/select.h>
#define UXW_EXPORT __attribute__((visibility("default")))
#define UXW_LW(off, kind) (((uint64_t)(off) << 8) | (uint64_t)(kind))
#define UXW_LK_DESCR 2
#define UXW_KWD_COUNT 8
#define UXW_MOD_SHIFT 1
#define UXW_MOD_CONTROL 2
#define UXW_MOD_META 4
extern DESCR_t rt_extfn_descr_out(const void *d);
extern int core_icn_error(int code, DESCR_t val);
extern void core_icn_fatal(int code, DESCR_t val);
extern const char *rt_main_progname(void);
extern char *rt_big_str(DESCR_t d);
extern void *rt_big_icnx_block(DESCR_t d);
extern DESCR_t rt_big_from_icnx_block(const void *p);
extern DESCR_t rt_big_from_str_base(const char *s, int base);
extern void *rt_lrec_alloc(size_t nbytes, const uint64_t *layout);
extern void rt_gc_visit_icnx_descr(void *d);
extern void rt_gc_run_loc_list(const char *const *const *list, long n);
extern void rt_gc_root_fn_add(void (*fn)(void));
extern void *xwin_list_new(void) __attribute__((weak));
extern void rt_icn_set_errortext(int code) __attribute__((weak));
extern struct descrip *const uxw_root_descrs[];
extern const long uxw_root_descr_count;
extern struct descrip *const uxw_kywd[];
typedef struct uxw_collect { int (*push)(struct uxw_collect *rec, dptr v); } uxw_collect_t;
unsigned char allchars[256];
struct descrip emptystr = { 0, { .sptr = "" } };
struct descrip nullptr = { F_Ptr | F_Nqual, { .bptr = 0 } };
struct descrip onedesc = { D_Integer, { .integr = 1 } };
struct descrip zerodesc = { D_Integer, { .integr = 0 } };
static struct region uxw_noregion;
struct region *curstring = &uxw_noregion;
FILE *flog = 0;
static char uxw_room;
static const uint64_t uxw_layout_file[] = { UXW_LW(offsetof(struct b_file, fname), UXW_LK_DESCR), 0 };
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static DESCR_t uxw_err_value(int n, dptr v, int *code) {
    if (n == 0) { *code = t_errornumber; return t_have_val ? rt_extfn_descr_out(&t_errorvalue) : FAILDESCR; }
    *code = n;
    return v ? rt_extfn_descr_out(v) : FAILDESCR;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void err_msg(int n, dptr v) { int code; DESCR_t val = uxw_err_value(n, v, &code); core_icn_error(code, val); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void fatalerr(int n, dptr v) { int code; DESCR_t val = uxw_err_value(n, v, &code); core_icn_fatal(code, val); abort(); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void syserr(char *s) { fprintf(stderr, "System error\n%s\n", s ? s : ""); fflush(stderr); exit(EXIT_FAILURE); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void set_errortext(int i) { if (rt_icn_set_errortext) rt_icn_set_errortext(i); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int idelay(int n) { if (n <= 0) return Succeeded; struct timeval t = { n / 1000, (n % 1000) * 1000 }; select(0, (fd_set *)0, (fd_set *)0, (fd_set *)0, &t); return Succeeded; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int iselect(int fd, int t) {
    struct timeval tv = { t / 1000, (t % 1000) * 1000 };
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(fd, &fds);
    return select(fd + 1, &fds, (fd_set *)0, (fd_set *)0, &tv);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int getenv_r(const char *name, char *buf, size_t len) { const char *v = getenv(name); if (!v || strlen(v) >= len) return -1; memcpy(buf, v, strlen(v) + 1); return 0; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
char *qsearch(char *key, char *base, int nel, int width, int (*cmp)()) {
    long lo = 0, hi = (long)nel - 1;
    while (lo <= hi) {
        long mid = lo + (hi - lo) / 2;
        char *p = base + mid * (long)width;
        int c = (*cmp)(p, key);
        if (c == 0) return p;
        if (c > 0) hi = mid - 1; else lo = mid + 1;
    }
    return (char *)0;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
char *reserve(int region, word nbytes) { (void)region; (void)nbytes; return &uxw_room; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int interp(int fsig, dptr cargp) { uxw_collect_t *rec = ((uxw_collect_t **)(void *)cargp)[-1]; if (!rec || (fsig != G_Csusp && fsig != G_Fsusp)) return A_Resume; return rec->push(rec, cargp); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct descrip xwin_kywd_prog(void) { const char *p = rt_main_progname(); struct descrip d; if (!p) p = ""; StrLen(d) = (word)strlen(p); StrLoc(d) = (char *)p; return d; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
word bigradix(int sign, int r, char *s, char *x, union numeric *result) {
    if (r < 2 || r > 36) return CvtFail;
    char buf[(x - s) + 3];
    long k = 0, nd = 0;
    if (sign == '-') buf[k++] = '-';
    while (s < x && isalnum((unsigned char)*s)) {
        int c = isdigit((unsigned char)*s) ? *s - '0' : tolower((unsigned char)*s) - 'a' + 10;
        if (c >= r) return CvtFail;
        buf[k++] = *s++;
        nd++;
    }
    while (s < x && isspace((unsigned char)*s)) s++;
    if (s < x) return CvtFail;
    if (!nd) buf[k++] = '0';
    buf[k] = 0;
    DESCR_t v = rt_big_from_str_base(buf, r);
    if (IS_FAIL_fn(v)) return CvtFail;
    if (v.v == DT_I) { result->integer = (word)v.i; return T_Integer; }
    result->big = (struct b_bignum *)rt_big_icnx_block(v);
    return result->big ? T_Lrgint : CvtFail;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int bigtoreal(dptr da, double *d) {
    const struct b_bignum *b = (const struct b_bignum *)BlkLoc(*da);
    double r = 0;
    for (word i = b->msd; i <= b->lsd; i++) r = r * 4294967296.0 + (double)b->digits[i];
    if (isinf(r)) return 0;
    *d = b->sign ? -r : r;
    return 1;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static char *uxw_decimal(dptr d, char *small) {
    if (Type(*d) == T_Integer) { snprintf(small, 24, "%ld", (long)IntVal(*d)); return small; }
    return rt_big_str(rt_big_from_icnx_block(BlkLoc(*d)));
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int bigtos(dptr da, dptr dx) {
    char *t = rt_big_str(rt_big_from_icnx_block(BlkLoc(*da)));
    long n = t ? (long)strlen(t) : 0;
    char *q = alcstr(t, (word)n);
    if (!q) fatalerr(0, (dptr)0);
    StrLen(*dx) = n;
    StrLoc(*dx) = q;
    return NoCvt;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int bigmul(dptr da, dptr db, dptr dx) {
    char sa[24], sb[24];
    const char *a = uxw_decimal(da, sa), *b = uxw_decimal(db, sb);
    if (!a || !b) return RunError;
    int neg = (*a == '-') != (*b == '-');
    if (*a == '-') a++;
    if (*b == '-') b++;
    long na = (long)strlen(a), nb = (long)strlen(b);
    int acc[na + nb];
    char out[na + nb + 2];
    memset(acc, 0, sizeof acc);
    for (long i = na - 1; i >= 0; i--)
        for (long j = nb - 1; j >= 0; j--) {
            int p = (a[i] - '0') * (b[j] - '0') + acc[i + j + 1];
            acc[i + j + 1] = p % 10;
            acc[i + j] += p / 10;
        }
    long k = 0, i = 0;
    while (i < na + nb - 1 && acc[i] == 0) i++;
    if (neg) out[k++] = '-';
    for (; i < na + nb; i++) out[k++] = (char)('0' + acc[i]);
    out[k] = 0;
    DESCR_t v = rt_big_from_str_base(out, 10);
    if (IS_FAIL_fn(v)) return RunError;
    if (v.v == DT_I) { MakeInt((word)v.i, dx); return Succeeded; }
    void *blk = rt_big_icnx_block(v);
    if (!blk) return RunError;
    dx->dword = D_Lrgint;
    BlkLoc(*dx) = (union block *)blk;
    return Succeeded;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_file *alcfile(FILE *fd, int status, dptr name) {
    struct descrip tname = *name;
    struct b_file *b = (struct b_file *)rt_lrec_alloc(sizeof *b, uxw_layout_file);
    if (!b) return b;
    b->title = T_File;
    b->fd.fp = fd;
    b->status = status;
    b->fname = tname;
    return b;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_list *alclist(uword size, uword nslots) { (void)size; (void)nslots; return xwin_list_new ? (struct b_list *)xwin_list_new() : (struct b_list *)0; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_no3d(void) { err_msg(121, (dptr)0); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_list *alclisthdr(uword size, union block *bptr) { (void)size; (void)bptr; uxw_no3d(); return (struct b_list *)0; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_realarray *alcrealarray(uword n) { (void)n; uxw_no3d(); return (struct b_realarray *)0; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_record *alcrecd(int nflds, union block *recptr) { (void)nflds; (void)recptr; uxw_no3d(); return (struct b_record *)0; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int c_traverse(struct b_list *hp, struct descrip *res, int position) { (void)hp; (void)res; (void)position; uxw_no3d(); return 0; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int cplist2realarray(dptr dp, dptr dp2, word i, word j, word skipcopyelements) { (void)dp; (void)dp2; (void)i; (void)j; (void)skipcopyelements; uxw_no3d(); return RunError; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_proc *dynrecord(dptr s, dptr fields, int n) { (void)s; (void)fields; (void)n; uxw_no3d(); return (struct b_proc *)0; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_gc_roots(void) {
    for (long i = 0; i < uxw_root_descr_count; i++) rt_gc_visit_icnx_descr(uxw_root_descrs[i]);
    for (wsp ws = wstates; ws; ws = ws->next) { rt_gc_visit_icnx_descr(&ws->filep); rt_gc_visit_icnx_descr(&ws->listp); rt_gc_visit_icnx_descr(&ws->funclist); }
    for (wcp wc = wcntxts; wc; wc = wc->next) { const char *const *w[] = { (const char *const *)&wc->normals, (const char *const *)&wc->texcoords }; rt_gc_run_loc_list(w, 2); }
    for (wdp wd = wdsplys; wd; wd = wd->next)
        for (int i = 0; wd->stex && i < wd->ntextures; i++) rt_gc_visit_icnx_descr(&wd->stex[i].d);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
__attribute__((constructor)) static void uxw_load(void) { for (int i = 0; i < 256; i++) allchars[i] = (unsigned char)i; rt_gc_root_fn_add(uxw_gc_roots); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT void *xwin_kywd_addr(int which) { if (which < 0 || which >= UXW_KWD_COUNT) return (void *)0; return uxw_kywd[which]; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT int xwin_kywd_mods(void) { return (xmod_shift ? UXW_MOD_SHIFT : 0) | (xmod_control ? UXW_MOD_CONTROL : 0) | (xmod_meta ? UXW_MOD_META : 0); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT int xwin_lang_kywd_set(void *kywd, void *val) {
    dptr k = (dptr)kywd, v = (dptr)val;
    C_integer i;
    struct descrip var;
    if (k == &kywd_xwin[XKey_Window]) { if (v->dword != D_Null && (v->dword != D_File || !(BlkLoc(*v)->File.status & Fs_Window))) return 140; *k = *v; return 0; }
    if (k != &amperX && k != &amperY && k != &amperCol && k != &amperRow && k != &amperInterval) return -1;
    if (!cnv_c_int(v, &i)) return 101;
    IntVal(*k) = i;
    var.dword = D_Var;
    VarLoc(var) = k;
    return xyrowcol(&var) == -1 ? 140 : 0;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_poll(void) { pollctr >>= 1; pollctr++; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT void *xwin_lang_open(char *name, long nlen, void *lblk, void *attr, int n, int *err) {
    struct descrip fn;
    FILE *f = wopen(name, (struct b_list *)lblk, (dptr)attr, n, err, 0);
    if (!f) return (void *)0;
    StrLen(fn) = nlen;
    StrLoc(fn) = alcstr(name, (word)nlen);
    if (!StrLoc(fn)) return (void *)0;
    struct b_file *fl = alcfile(f, Fs_Window | Fs_Read | Fs_Write, &fn);
    if (!fl) return (void *)0;
    linkfiletowindow((wbp)f, fl);
    return fl;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT int xwin_lang_close(void *fblk) {
    struct b_file *f = (struct b_file *)fblk;
    uxw_poll();
    if (f->status == Fs_Window) return 0;
    f->status = Fs_Window;
    SETCLOSED(f->fd.wb);
    wclose(f->fd.wb);
    return 1;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT int xwin_lang_write(void *fblk, const char *s, long n) {
    struct b_file *f = (struct b_file *)fblk;
    if (!(f->status & Fs_Write)) return -1;
    uxw_poll();
    wputstr(f->fd.wb, (char *)s, (int)n);
    return 0;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT void xwin_lang_flush(void *fblk) { struct b_file *f = (struct b_file *)fblk; if (f->status & (Fs_Read | Fs_Write)) wflush(f->fd.wb); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT long xwin_lang_read(void *fblk, char *buf, long max) { struct b_file *f = (struct b_file *)fblk; uxw_poll(); return (long)wgetstrg(buf, max, f->fd.fp); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT long xwin_lang_reads(void *fblk, char *buf, long n) { struct b_file *f = (struct b_file *)fblk; uxw_poll(); return (long)wlongread(buf, 1, (int)n, f->fd.fp); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT const char *xwin_lang_image(void *fblk, int *wserial, int *cserial) {
    wbp w = ((struct b_file *)fblk)->fd.wb;
    *wserial = w->window->serial;
    *cserial = w->context->serial;
    return w->window->windowlabel ? w->window->windowlabel : "";
}
