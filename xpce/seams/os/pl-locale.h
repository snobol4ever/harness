/* seam: no stream of the kernel carries a locale; a stream's locale cell stays NULL */
#ifndef XPCE_SEAM_LOCALE_H
#define XPCE_SEAM_LOCALE_H
typedef struct PL_locale PL_locale;
PL_locale *acquireLocale(PL_locale *l);
void releaseLocale(PL_locale *l);
void initStreamLocale(IOSTREAM *s);
#endif
