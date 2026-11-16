#include <stddef.h>
#include <stdint.h>
typedef long word;
typedef struct { word dword, vword; } descr;
#define D_NULL ((word)0xA000000000000000ul)
#define D_INTEGER ((word)0xA000000000000001ul)
#define D_FILE ((word)0xB000000000000005ul)
#define D_EXTERNAL ((word)0xB000000000000013ul)
#define ST_OPEN 259
#define ST_CLOSED 256
#define LW(off, kind) (((uint64_t)(off) << 8) | (uint64_t)(kind))
#define CHECK(s) (((word)(s) * 2654435761l) ^ 0x5A5A5A5A5A5A5A5Al)
#define NREG 8
void *rt_lrec_alloc(size_t nbytes, const uint64_t *layout);
void *rt_lrec_realloc(void *p, size_t nbytes, const uint64_t *layout);
void rt_gc_root_fn_add(void (*fn)(void));
void rt_gc_run_loc_list(const char *const *const *list, long n);
void rt_gc_visit_icnx_descr(void *d);
struct node { struct node *next; word serial; descr name; word check; struct node **tab; word cap; char odd[3]; };
static const uint64_t lay_node[] = { LW(offsetof(struct node, next), 1), LW(offsetof(struct node, name), 2), LW(offsetof(struct node, tab), 1), 0 };
static const uint64_t lay_ptrs[] = { LW(0, 3), 0 };
struct fileblk { word title; struct node *fd; word status; descr fname; };
static const uint64_t lay_file[] = { LW(offsetof(struct fileblk, fd), 1), LW(offsetof(struct fileblk, fname), 2), 0 };
static struct node *reg[NREG];
static descr motto = { D_NULL, 0 };
static descr slot0 = { D_NULL, 0 };
static void lrec_roots(void) {
    static const char *const *const words[NREG] = { (const char *const *)&reg[0], (const char *const *)&reg[1], (const char *const *)&reg[2], (const char *const *)&reg[3],
        (const char *const *)&reg[4], (const char *const *)&reg[5], (const char *const *)&reg[6], (const char *const *)&reg[7] };
    rt_gc_run_loc_list(words, NREG);
    rt_gc_visit_icnx_descr(&motto);
    rt_gc_visit_icnx_descr(&slot0);
}
static int regno(const descr *d) { return d->dword == D_INTEGER && d->vword >= 1 && d->vword <= NREG ? (int)d->vword - 1 : -1; }
static struct node *held(const descr *d) { int r = regno(d); return r < 0 ? (struct node *)0 : reg[r]; }
static int sound(const struct node *n) { return n->check == CHECK(n->serial) && n->odd[0] == 'o' && n->odd[1] == 'd' && n->odd[2] == 'd'; }
static int integer(descr *r, word v) { r->dword = D_INTEGER; r->vword = v; return 0; }
int lrec_cons(int argc, descr *argv) {
    struct node *n;
    int dst = argc < 4 ? -1 : regno(&argv[1]);
    if (dst < 0 || argv[4].dword != D_INTEGER) return 101;
    rt_gc_root_fn_add(lrec_roots);
    n = (struct node *)rt_lrec_alloc(sizeof *n, lay_node);
    if (!n) return 305;
    n->next = held(&argv[2]);
    n->name = argv[3];
    n->serial = argv[4].vword;
    n->check = CHECK(n->serial);
    n->odd[0] = 'o';
    n->odd[1] = 'd';
    n->odd[2] = 'd';
    reg[dst] = n;
    return integer(&argv[0], dst + 1);
}
int lrec_step(int argc, descr *argv) {
    int dst = argc < 2 ? -1 : regno(&argv[1]);
    struct node *n = argc < 2 ? 0 : held(&argv[2]);
    if (dst < 0) return 101;
    reg[dst] = n ? n->next : 0;
    return reg[dst] ? integer(&argv[0], dst + 1) : -1;
}
int lrec_clear(int argc, descr *argv) { int dst = argc < 1 ? -1 : regno(&argv[1]); if (dst < 0) return 101; reg[dst] = 0; return integer(&argv[0], dst + 1); }
int lrec_name(int argc, descr *argv) { struct node *n = argc < 1 ? 0 : held(&argv[1]); if (!n) return -1; argv[0] = n->name; return 0; }
int lrec_rename(int argc, descr *argv) { struct node *n = argc < 2 ? 0 : held(&argv[1]); if (!n) return -1; n->name = argv[2]; return integer(&argv[0], argv[1].vword); }
int lrec_serial(int argc, descr *argv) { struct node *n = argc < 1 ? 0 : held(&argv[1]); return n ? integer(&argv[0], sound(n) ? n->serial : -999999) : -1; }
int lrec_put(int argc, descr *argv) {
    struct node *n = argc < 3 ? 0 : held(&argv[1]);
    word i;
    if (!n || argv[2].dword != D_INTEGER || argv[2].vword < 1) return -1;
    i = argv[2].vword;
    if (i > n->cap) {
        word cap = n->cap ? n->cap : 2;
        struct node **t;
        while (cap < i) cap = cap * 2 + 1;
        t = (struct node **)(n->tab ? rt_lrec_realloc(n->tab, (size_t)cap * sizeof *t, lay_ptrs) : rt_lrec_alloc((size_t)cap * sizeof *t, lay_ptrs));
        if (!t) return 305;
        n->tab = t;
        n->cap = cap;
    }
    n->tab[i - 1] = held(&argv[3]);
    return integer(&argv[0], argv[1].vword);
}
int lrec_get(int argc, descr *argv) {
    int dst = argc < 3 ? -1 : regno(&argv[1]);
    struct node *n = argc < 3 ? 0 : held(&argv[2]);
    if (dst < 0) return 101;
    reg[dst] = (n && argv[3].dword == D_INTEGER && argv[3].vword >= 1 && argv[3].vword <= n->cap) ? n->tab[argv[3].vword - 1] : 0;
    return reg[dst] ? integer(&argv[0], dst + 1) : -1;
}
int lrec_motto(int argc, descr *argv) { if (argc >= 1) { rt_gc_root_fn_add(lrec_roots); motto = argv[1]; } argv[0] = motto; return 0; }
static struct fileblk *wfile(const descr *d) { struct fileblk *f = d->dword == D_EXTERNAL ? (struct fileblk *)d->vword : (struct fileblk *)0; return f && f->title == D_FILE ? f : (struct fileblk *)0; }
static int window(descr *r, struct fileblk *f) { if (!f) return -1; r->dword = D_EXTERNAL; r->vword = (word)f; return 0; }
int lrec_wopen(int argc, descr *argv) {
    struct node *n;
    struct fileblk *f;
    if (argc < 2 || argv[2].dword != D_INTEGER) return 101;
    rt_gc_root_fn_add(lrec_roots);
    n = (struct node *)rt_lrec_alloc(sizeof *n, lay_node);
    f = (struct fileblk *)rt_lrec_alloc(sizeof *f, lay_file);
    if (!n || !f) return 305;
    n->name = argv[1];
    n->serial = argv[2].vword;
    n->check = CHECK(n->serial);
    n->odd[0] = 'o';
    n->odd[1] = 'd';
    n->odd[2] = 'd';
    f->title = D_FILE;
    f->fd = n;
    f->status = ST_OPEN;
    f->fname = argv[1];
    return window(&argv[0], f);
}
int lrec_wname(int argc, descr *argv) { struct fileblk *f = argc < 1 ? 0 : wfile(&argv[1]); if (!f) return -1; argv[0] = f->fname; return 0; }
int lrec_wserial(int argc, descr *argv) { struct fileblk *f = argc < 1 ? 0 : wfile(&argv[1]); return f ? integer(&argv[0], f->fd && sound(f->fd) ? f->fd->serial : -999999) : -1; }
int lrec_wstatus(int argc, descr *argv) { struct fileblk *f = argc < 1 ? 0 : wfile(&argv[1]); return f ? integer(&argv[0], f->status) : -1; }
int lrec_wclose(int argc, descr *argv) { struct fileblk *f = argc < 1 ? 0 : wfile(&argv[1]); if (!f) return -1; f->status = ST_CLOSED; return window(&argv[0], f); }
int lrec_wkeep(int argc, descr *argv) { struct fileblk *f = argc < 1 ? 0 : wfile(&argv[1]); if (!f) return -1; slot0.dword = D_FILE; slot0.vword = (word)f; return window(&argv[0], f); }
int lrec_wkept(int argc, descr *argv) { (void)argc; return slot0.dword == D_FILE ? window(&argv[0], (struct fileblk *)slot0.vword) : -1; }
int lrec_wsame(int argc, descr *argv) { struct fileblk *f = argc < 1 ? 0 : wfile(&argv[1]); return f ? integer(&argv[0], slot0.dword == D_FILE && slot0.vword == (word)f) : -1; }
int lrec_wbind(int argc, descr *argv) {
    int dst = argc < 2 ? -1 : regno(&argv[1]);
    struct fileblk *f = argc < 2 ? 0 : wfile(&argv[2]);
    if (dst < 0 || !f) return -1;
    reg[dst] = f->fd;
    return integer(&argv[0], dst + 1);
}
