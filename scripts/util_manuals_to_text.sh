#!/usr/bin/env bash
# util_manuals_to_text.sh [--force] -- EVERY MANUAL ON THE BOX AS SEARCHABLE TEXT, IN ONE SHARED FOLDER (Lon 2026-10-31, in-chat to the ceo,
# verbatim: "Yes, turn those manuals into searchable text." · "Make a nice folder in /home/resources for these converted text files and docs used by
# all seats."; ceo CEO-2071). The folder is /home/resources/manuals/<area>/ -- prolog icon pascal raku snobol4 rebus byrd-boxes gc -- each with a
# PROVENANCE.txt (output, source, tool, date, source sha256 prefix) and a README.md index at the top. The sources stay where their authors laid
# them out under /home/resources; this script only reads them. PDF -> pdftotext -layout; LaTeX and SWI's .doc -> detex; HTML -> pandoc plain;
# text already (pod, md, txt) -> copied. Idempotent: an output newer than its source is kept unless --force. Re-run after any source updates.
FORCE=0; [ "${1:-}" = "--force" ] && FORCE=1
R=/home/resources; OUT=$R/manuals; STAMP=$(date '+%Y-%m-%d %H:%M %Z')
command -v pdftotext >/dev/null && command -v detex >/dev/null && command -v pandoc >/dev/null || { echo "REFUSE(2): pdftotext, detex and pandoc are all required"; exit 2; }
mkdir -p "$OUT" || { echo "REFUSE(2): cannot create $OUT"; exit 2; }
done_n=0; kept_n=0; fail_n=0
prov() { printf '%s\t%s\t%s\t%s\t%s\n' "$(basename "$2")" "${1#$R/}" "$3" "$STAMP" "$(sha256sum "$1" | cut -c1-16)" >> "$OUT/$4/PROVENANCE.txt"; }
conv() { # conv <area> <tool> <source> <output-name>
  local area=$1 tool=$2 src=$3 dst=$OUT/$1/$4
  [ -r "$src" ] || { echo "MISSING $src"; fail_n=$((fail_n+1)); return; }
  mkdir -p "$OUT/$area"
  if [ "$FORCE" = 0 ] && [ -s "$dst" ] && [ "$dst" -nt "$src" ]; then prov "$src" "$dst" "$tool" "$area"; kept_n=$((kept_n+1)); return; fi
  case $tool in
    pdftotext) pdftotext -layout "$src" "$dst" 2>/dev/null ;;
    detex)     detex "$src" > "$dst" 2>/dev/null ;;
    pandoc)    pandoc -f html -t plain --wrap=none "$src" -o "$dst" 2>/dev/null ;;
    copy)      cp -p "$src" "$dst" ;;
  esac
  if [ -s "$dst" ]; then prov "$src" "$dst" "$tool" "$area"; done_n=$((done_n+1)); else rm -f "$dst"; echo "FAILED $tool $src"; fail_n=$((fail_n+1)); fi
}
for a in prolog icon pascal raku snobol4 rebus byrd-boxes gc; do mkdir -p "$OUT/$a"; printf 'output\tsource (under /home/resources)\ttool\tconverted\tsource sha256[:16]\n' > "$OUT/$a/PROVENANCE.txt"; done
for f in $R/swipl-devel-master/man/*.doc; do conv prolog detex "$f" "swi-$(basename "${f%.doc}").txt"; done
for f in $R/gprolog-master/doc/*.tex; do case $f in *the-index.tex) ;; *) conv prolog detex "$f" "gprolog-$(basename "${f%.tex}").txt";; esac; done
conv icon pdftotext "$R/The Icon Programming Language 3rd Edition.pdf" icon-book-3rd-edition.txt
conv icon pdftotext "$R/Simple Translation of Goal Directed Evaluation.pdf" goal-directed-evaluation-simple-translation.txt
for f in $R/icon-master/doc/*.htm; do conv icon pandoc "$f" "icon-doc-$(basename "${f%.htm}").txt"; done
for f in $R/unicon/doc/unicon/utr*.pdf; do [ -e "$f" ] && conv icon pdftotext "$f" "unicon-$(basename "${f%.pdf}").txt"; done
for f in $R/unicon/doc/book/*.tex; do [ -e "$f" ] && conv icon detex "$f" "unicon-book-$(basename "${f%.tex}").txt"; done
[ -f $R/unicon/tests/README ] && conv icon copy $R/unicon/tests/README unicon-tests-README.txt
conv pascal pandoc $R/Pascal-P5/doc/iso7185.html iso7185-standard.txt
conv pascal pandoc $R/Pascal-P5/doc/iso7185rules.html iso7185-rules.txt
conv pascal pandoc $R/Pascal-P5/doc/the_p5_compiler.html p5-compiler.txt
conv pascal pdftotext $R/Pascal-P5/doc/The_Programming_Language_Pascal_1973.pdf wirth-1973-the-programming-language-pascal.txt
conv pascal pdftotext $R/Pascal-P5/doc/The_Pascal_P_Compiler_implementation_notes.pdf pascal-p-compiler-implementation-notes.txt
for d in $R/rakudo-2026.05/docs $R/nqp/docs $R/raku-examples/doc; do
  [ -d "$d" ] || continue
  tag=$(basename "$(dirname "$d")")
  while IFS= read -r f; do rel=${f#$d/}; conv raku copy "$f" "$tag--${rel//\//--}"; done < <(find "$d" -type f \( -name '*.pod' -o -name '*.pod6' -o -name '*.rakudoc' -o -name '*.md' -o -name '*.markdown' -o -name '*.txt' \) | sort)
done
conv snobol4 pdftotext $R/spitbol-manual-v3.7.pdf spitbol-manual-v3.7.txt
conv snobol4 pdftotext $R/spitbol-docs-master/green-book.pdf green-book.txt
conv snobol4 pdftotext "$R/A Theory of Discrete Patterns and Their Implementation in SNOBOL4.pdf" discrete-patterns-theory-snobol4.txt
for f in $R/spitbol-docs-master/*.md; do conv snobol4 copy "$f" "spitbol-docs-$(basename "$f")"; done
for f in $R/csnobol4/doc/*.txt; do conv snobol4 copy "$f" "csnobol4-doc-$(basename "$f")"; done
conv snobol4 copy $R/snoflake-master/docs/manual.md snoflake-manual.md
conv rebus pdftotext "$R/REBUS tr84_9.pdf" rebus-tr84-9.txt
for f in $R/byrd-box-literature/*.txt; do conv byrd-boxes copy "$f" "$(basename "$f")"; done
for f in $R/gc-papers/*.pdf; do case $f in *appel-1989-simple-generational-gc.pdf) ;; *) conv gc pdftotext "$f" "$(basename "${f%.pdf}").txt";; esac; done
echo "appel-1989-simple-generational-gc.pdf is a scanned image with no text layer; read the PDF itself under /home/resources/gc-papers/" > "$OUT/gc/appel-1989-NOT-CONVERTED.txt"
{
  echo "# /home/resources/manuals -- the fleet's reference library as searchable text"
  echo
  echo "Every manual, standard and paper on the box, converted to plain text so any seat can grep it (Lon 2026-10-31, CEO-2071). The sources stay"
  echo "where their authors laid them out under /home/resources; this folder is generated by harness/scripts/util_manuals_to_text.sh and is re-run"
  echo "when a source updates. Each area's PROVENANCE.txt names the source, the tool and the source hash of every file. Regenerated $STAMP."
  echo
  echo "| area | what is here | the oracle it describes |"
  echo "|---|---|---|"
  echo "| prolog/ | SWI-Prolog 9 manual, one file per chapter (swi-*.txt, from swipl-devel-master/man); GNU Prolog 1.6 manual (gprolog-*.txt) | swipl 9.0.4 and gprolog 1.6.0; the ISO conformance suites are /home/resources/prolog-iso-conformance |"
  echo "| icon/ | The Icon Programming Language, 3rd edition; the Icon implementation docs (icon-doc-*.txt); the goal-directed-evaluation paper; the Unicon book by chapter (unicon-book-*.txt) and Unicon technical reports | the SCRIP-dialect build under /home/resources/icon-master |"
  echo "| pascal/ | ISO 7185 standard text and its rules; Wirth 1973; the Pascal-P compiler notes and the P5 compiler book | ISO 7185 wins over fpc -Miso (CEO-1225); fpc's own manual is not on the box |"
  echo "| raku/ | Rakudo 2026.05 design docs, NQP docs and the raku-examples docs, copied as text | rakudo 2026.05; THE SPEC IS THE ROAST, /home/resources/roast-master |"
  echo "| snobol4/ | SPITBOL manual v3.7, the green book, the discrete-patterns theory paper, the spitbol-docs notes, CSNOBOL4 docs, the Snoflake manual | /home/resources/x64/bin/sbl -bf |"
  echo "| rebus/ | REBUS technical report TR84-9 | -- |"
  echo "| byrd-boxes/ | the Byrd-box and DEC-10 Prolog literature (Byrd 1980, Pereira, Bowen, Carlsson, Finkel) | the four-port box every pattern, generator and goal compiles to |"
  echo "| gc/ | the collector papers (Boehm, Appel, Immix, type precision and liveness, write barriers, verified collectors) | ARCH-GC-COMPILE-TIME-FRAME-MAPS.md |"
  echo
  echo "Use: grep -rn 'atom_length' /home/resources/manuals/prolog/ ; grep -n 'fillchar' /home/resources/manuals/pascal/iso7185-standard.txt"
} > "$OUT/README.md"
echo "MANUALS_TO_TEXT out=$OUT converted=$done_n kept=$kept_n failed=$fail_n size=$(du -sh "$OUT" | cut -f1)"
[ "$fail_n" = 0 ]
