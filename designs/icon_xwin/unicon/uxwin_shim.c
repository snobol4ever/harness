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
extern long xwin_list_reals(void *d, long i, long j, double *out, void *bad) __attribute__((weak));
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
static void uxw_by_value(dptr d);
int interp(int fsig, dptr cargp) { uxw_collect_t *rec = ((uxw_collect_t **)(void *)cargp)[-1]; if (!rec || (fsig != G_Csusp && fsig != G_Fsusp)) return A_Resume; uxw_by_value(cargp); return rec->push(rec, cargp); }
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
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int c_traverse(struct b_list *hp, struct descrip *res, int position) { (void)hp; (void)position; if (res) { res->dword = D_Null; res->vword.integr = 0; } return 1; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#define UXW_PRIV ((word)0x5558570000000000L)
#define UXW_OWNED ((word)0x0000000100000000L)
static word uxw_idc = 1;
static int uxw_priv_blk(union block *b, word title) { return b && *(word *)b == title && ((*((word *)b + 2)) & ~(UXW_OWNED | 0xffffffffL)) == UXW_PRIV; }
static int uxw_priv_list(struct b_list *h) { return uxw_priv_blk((union block *)h, T_List); }
static int uxw_priv_rec(struct b_record *r) { return uxw_priv_blk((union block *)r, T_Record); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static struct b_lelem *uxw_lelem(word n) {
    struct b_lelem *e = calloc(1, sizeof *e + (size_t)(n > 1 ? n - 1 : 0) * sizeof(struct descrip));
    if (!e) return (struct b_lelem *)0;
    e->title = T_Lelem; e->blksize = (word)(sizeof *e + (size_t)(n > 1 ? n - 1 : 0) * sizeof(struct descrip)); e->nslots = n;
    for (word i = 0; i < n; i++) e->lslots[i].dword = D_Null;
    return e;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_list *uxw_alclist3d(uword size, uword nslots) {
    struct b_list *h = calloc(1, sizeof *h);
    struct b_lelem *e = uxw_lelem((word)(nslots < 8 ? 8 : nslots));
    (void)size;
    if (!h || !e) { free(h); free(e); return (struct b_list *)0; }
    h->title = T_List; h->id = UXW_PRIV | UXW_OWNED | (uxw_idc++ & 0xffffffffL); h->listhead = h->listtail = (union block *)e;
    e->listprev = e->listnext = (union block *)h;
    return h;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_realarray *alcrealarray(uword n) {
    size_t sz = sizeof(struct b_realarray) + (size_t)(n > 1 ? n - 1 : 0) * sizeof(double);
    struct b_realarray *a = calloc(1, sz);
    if (!a) return (struct b_realarray *)0;
    a->title = T_Realarray; a->blksize = (word)sz;
    return a;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_list *alclisthdr(uword size, union block *bptr) {
    struct b_list *h;
    if (!bptr || BlkType(bptr) != T_Realarray) { uxw_no3d(); return (struct b_list *)0; }
    h = calloc(1, sizeof *h);
    if (!h) return (struct b_list *)0;
    h->title = T_List; h->size = (word)size; h->id = UXW_PRIV | UXW_OWNED | (uxw_idc++ & 0xffffffffL); h->listhead = h->listtail = bptr;
    ((struct b_realarray *)bptr)->listp = (union block *)h;
    return h;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int cplist2realarray(dptr dp, dptr dp2, word i, word j, word skipcopyelements) {
    word size = j - i;
    struct b_realarray *ap2 = alcrealarray((uword)size);
    if (!ap2) return RunError;
    if (!skipcopyelements) {
        if (dp->dword == D_List) {
            long r = xwin_list_reals ? xwin_list_reals(dp, (long)i, (long)j, ap2->a, (void *)0) : -2;
            if (r == -2) uxw_no3d();
            if (r != size) { free(ap2); return RunError; }
        } else {
            dp = &dp[i];
            for (word k = 0; k < size; k++) if (!cnv_c_dbl(dp++, &ap2->a[k])) { free(ap2); return RunError; }
        }
    }
    dp2->vword.bptr = (union block *)alclisthdr((uword)size, (union block *)ap2);
    dp2->dword = D_List;
    if (!dp2->vword.bptr) { free(ap2); return RunError; }
    return Succeeded;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_record *alcrecd(int nflds, union block *recptr) {
    size_t n = sizeof(struct b_record) + (size_t)(nflds > 1 ? nflds - 1 : 0) * sizeof(struct descrip);
    struct b_record *r = calloc(1, n);
    if (!r) return (struct b_record *)0;
    r->title = T_Record; r->blksize = (word)n; r->id = UXW_PRIV | (uxw_idc++ & 0xffffffffL); r->recdesc = recptr;
    for (int i = 0; i < nflds; i++) r->fields[i].dword = D_Null;
    return r;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
struct b_proc *dynrecord(dptr s, dptr fields, int n) {
    size_t sz = sizeof(struct b_proc) + (size_t)(n > 1 ? n - 1 : 0) * sizeof(struct descrip);
    struct b_proc *p = calloc(1, sz);
    if (!p) return (struct b_proc *)0;
    p->title = T_Proc; p->blksize = (word)sz; p->nfields = n; p->pname = *s;
    for (int i = 0; i < n; i++) p->lnames[i] = fields[i];
    return p;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_own(dptr d);
static void uxw_own_rec(struct b_record *r) {
    if (r->id & UXW_OWNED) return;
    r->id |= UXW_OWNED;
    word n = ((struct b_proc *)r->recdesc)->nfields;
    for (word i = 0; i < n; i++) uxw_own(&r->fields[i]);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_own(dptr d) {
    if (d->dword == D_Integer || d->dword == D_Null) return;
    if (!(d->dword & F_Nqual)) {
        char *q = malloc((size_t)d->dword + 1);
        if (!q) { d->dword = D_Null; return; }
        memcpy(q, d->vword.sptr, (size_t)d->dword); q[d->dword] = 0; d->vword.sptr = q;
        return;
    }
    if (d->dword == D_Real) { struct b_real *r = malloc(sizeof *r); if (!r) { d->dword = D_Null; return; } *r = *(struct b_real *)d->vword.bptr; d->vword.bptr = (union block *)r; return; }
    if (d->dword == D_Record && uxw_priv_rec((struct b_record *)d->vword.bptr)) { uxw_own_rec((struct b_record *)d->vword.bptr); return; }
    if (d->dword == D_List && uxw_priv_list((struct b_list *)d->vword.bptr)) return;
    d->dword = D_Null;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void uxw_c_put(dptr l, dptr v) {
    struct b_list *h = (struct b_list *)l->vword.bptr;
    struct descrip d = *v;
    if (!uxw_priv_list(h)) { c_put(l, v); return; }
    uxw_own(&d);
    struct b_lelem *t = (struct b_lelem *)h->listtail;
    if (t->nused == t->nslots) {
        struct b_lelem *e = uxw_lelem(t->nslots * 2);
        if (!e) return;
        e->listprev = (union block *)t; e->listnext = (union block *)h; t->listnext = (union block *)e; h->listtail = (union block *)e; t = e;
    }
    t->lslots[(t->first + t->nused) % t->nslots] = d; t->nused++; h->size++;
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_free_list(struct b_list *h);
static void uxw_free_rec(struct b_record *r) {
    word n = ((struct b_proc *)r->recdesc)->nfields;
    for (word i = 0; i < n; i++) {
        dptr d = &r->fields[i];
        if (d->dword == D_Real) free(d->vword.bptr);
        else if (d->dword == D_Record && uxw_priv_rec((struct b_record *)d->vword.bptr)) uxw_free_rec((struct b_record *)d->vword.bptr);
        else if (d->dword == D_List && uxw_priv_list((struct b_list *)d->vword.bptr)) uxw_free_list((struct b_list *)d->vword.bptr);
        else if (!(d->dword & F_Nqual)) free(d->vword.sptr);
    }
    free(r);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_free_list(struct b_list *h) {
    struct b_lelem *e = (struct b_lelem *)h->listhead;
    if (e && BlkType(e) == T_Realarray) { free(e); free(h); return; }
    while (e && (union block *)e != (union block *)h) {
        struct b_lelem *nx = (struct b_lelem *)e->listnext;
        for (word i = 0; i < e->nused; i++) {
            dptr d = &e->lslots[(e->first + i) % e->nslots];
            if (d->dword == D_Real) free(d->vword.bptr);
            else if (d->dword == D_Record && uxw_priv_rec((struct b_record *)d->vword.bptr)) uxw_free_rec((struct b_record *)d->vword.bptr);
            else if (d->dword == D_List && uxw_priv_list((struct b_list *)d->vword.bptr)) uxw_free_list((struct b_list *)d->vword.bptr);
            else if (!(d->dword & F_Nqual)) free(d->vword.sptr);
        }
        free(e);
        e = nx;
    }
    free(h);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_by_value(dptr d) {
    struct descrip l;
    if (d->dword == D_Record && uxw_priv_rec((struct b_record *)d->vword.bptr)) {
        struct b_record *r = (struct b_record *)d->vword.bptr;
        l.dword = D_List; l.vword.bptr = xwin_list_new ? (union block *)xwin_list_new() : (union block *)0;
        if (!l.vword.bptr) return;
        word n = ((struct b_proc *)r->recdesc)->nfields;
        for (word i = 0; i < n; i++) { struct descrip f = r->fields[i]; uxw_by_value(&f); c_put(&l, &f); }
        *d = l;
    } else if (d->dword == D_List && uxw_priv_list((struct b_list *)d->vword.bptr)) {
        struct b_list *h = (struct b_list *)d->vword.bptr;
        l.dword = D_List; l.vword.bptr = xwin_list_new ? (union block *)xwin_list_new() : (union block *)0;
        if (!l.vword.bptr) return;
        if (BlkType(h->listhead) == T_Realarray) {
            struct b_realarray *ra = (struct b_realarray *)h->listhead;
            for (word i = 0; i < h->size; i++) { struct b_real r; struct descrip f; r.title = T_Real; r.realval = ra->a[i]; f.dword = D_Real; f.vword.bptr = (union block *)&r; c_put(&l, &f); }
            *d = l;
            return;
        }
        for (struct b_lelem *e = (struct b_lelem *)h->listhead; e && (union block *)e != (union block *)h; e = (struct b_lelem *)e->listnext)
            for (word i = 0; i < e->nused; i++) { struct descrip f = e->lslots[(e->first + i) % e->nslots]; uxw_by_value(&f); c_put(&l, &f); }
        *d = l;
    }
}
extern int ZDrawCube(int, dptr);
int uxw3d_DrawCube(int n, dptr a) { int r = ZDrawCube(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZDrawCylinder(int, dptr);
int uxw3d_DrawCylinder(int n, dptr a) { int r = ZDrawCylinder(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZDrawDisk(int, dptr);
int uxw3d_DrawDisk(int n, dptr a) { int r = ZDrawDisk(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZDrawSphere(int, dptr);
int uxw3d_DrawSphere(int n, dptr a) { int r = ZDrawSphere(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZDrawTorus(int, dptr);
int uxw3d_DrawTorus(int n, dptr a) { int r = ZDrawTorus(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZEye(int, dptr);
int uxw3d_Eye(int n, dptr a) { int r = ZEye(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZIdentityMatrix(int, dptr);
int uxw3d_IdentityMatrix(int n, dptr a) { int r = ZIdentityMatrix(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZMatrixMode(int, dptr);
int uxw3d_MatrixMode(int n, dptr a) { int r = ZMatrixMode(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZMultMatrix(int, dptr);
int uxw3d_MultMatrix(int n, dptr a) { int r = ZMultMatrix(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZNormals(int, dptr);
int uxw3d_Normals(int n, dptr a) { int r = ZNormals(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZPopMatrix(int, dptr);
int uxw3d_PopMatrix(int n, dptr a) { int r = ZPopMatrix(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZPushMatrix(int, dptr);
int uxw3d_PushMatrix(int n, dptr a) { int r = ZPushMatrix(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZPushRotate(int, dptr);
int uxw3d_PushRotate(int n, dptr a) { int r = ZPushRotate(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZPushScale(int, dptr);
int uxw3d_PushScale(int n, dptr a) { int r = ZPushScale(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZPushTranslate(int, dptr);
int uxw3d_PushTranslate(int n, dptr a) { int r = ZPushTranslate(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZRefresh(int, dptr);
int uxw3d_Refresh(int n, dptr a) { int r = ZRefresh(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZRotate(int, dptr);
int uxw3d_Rotate(int n, dptr a) { int r = ZRotate(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZScale(int, dptr);
int uxw3d_Scale(int n, dptr a) { int r = ZScale(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZTexcoord(int, dptr);
int uxw3d_Texcoord(int n, dptr a) { int r = ZTexcoord(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZTexture(int, dptr);
int uxw3d_Texture(int n, dptr a) { int r = ZTexture(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZTranslate(int, dptr);
int uxw3d_Translate(int n, dptr a) { int r = ZTranslate(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZWindowContents(int, dptr);
int uxw3d_WindowContents(int n, dptr a) { int r = ZWindowContents(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
extern int ZWSection(int, dptr);
int uxw3d_WSection(int n, dptr a) { int r = ZWSection(n, a); if (r == A_Continue) uxw_by_value(a); return r; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void uxw_gc_roots(void) {
    for (long i = 0; i < uxw_root_descr_count; i++) rt_gc_visit_icnx_descr(uxw_root_descrs[i]);
    for (wsp ws = wstates; ws; ws = ws->next) { rt_gc_visit_icnx_descr(&ws->filep); rt_gc_visit_icnx_descr(&ws->listp); }
    for (wcp wc = wcntxts; wc; wc = wc->next) { const char *const *w[] = { (const char *const *)&wc->normals, (const char *const *)&wc->texcoords }; rt_gc_run_loc_list(w, 2); }
    for (wdp wd = wdsplys; wd; wd = wd->next)
        for (int i = 0; wd->stex && i < wd->ntextures; i++) rt_gc_visit_icnx_descr(&wd->stex[i].d);
}
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
__attribute__((constructor)) static void uxw_load(void) { for (int i = 0; i < 256; i++) allchars[i] = (unsigned char)i; rt_gc_root_fn_add(uxw_gc_roots); }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT void *xwin_kywd_addr(int which) { if (which < 0 || which >= UXW_KWD_COUNT) return (void *)0; return uxw_kywd[which]; }
/*----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
UXW_EXPORT int xwin_poll(void) { return pollevent(); }
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
UXW_EXPORT void *xwin_lang_open3d(char *name, long nlen, void *lblk, void *attr, int n, int *err) {
    struct descrip fn;
    FILE *f = wopengl(name, (struct b_list *)lblk, (dptr)attr, n, err);
    if (!f) return (void *)0;
    StrLen(fn) = nlen;
    StrLoc(fn) = alcstr(name, (word)nlen);
    if (!StrLoc(fn)) return (void *)0;
    struct b_file *fl = alcfile(f, Fs_Window | Fs_Window3D | Fs_Read | Fs_Write, &fn);
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
    if (f->fd.wb->window->refcount == 1 && uxw_priv_list((struct b_list *)f->fd.wb->window->funclist.vword.bptr)) { uxw_free_list((struct b_list *)f->fd.wb->window->funclist.vword.bptr); f->fd.wb->window->funclist.dword = D_Null; }
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
