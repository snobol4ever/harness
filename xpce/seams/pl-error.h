/* seam: the stream file names no error term of SWI-Prolog's; its PL_ functions are declared by SWI-Prolog.h and defined in the seams file.
   THE IRI ROAD IS CLOSED: no path is an IRI, so Sopen_iri_or_file opens plain paths only (HOSTING 3.9, the hypothesis step 20 measures). */
#ifndef XPCE_SEAM_ERROR_H
#define XPCE_SEAM_ERROR_H
#define file_name_is_iri(path) ((size_t)0)
#define iri_hook(path, op, ...) (0)
#define IRI_OPEN 0
#define ATOM_read ((atom_t)0)
#define ATOM_write ((atom_t)0)
#endif
