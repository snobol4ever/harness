# harness/fixtures/unicon -- the six Unicon package witnesses the icon master cannot hold yet (the coo 2026-11-12)

Moved here from corpus/tests/icon/unicon (Lon 2026-11-12 10:2x CST: "I'm not liking #/corpus/tests/icon/{config,rung36_bullshit,unicon}
folders."). Every other witness of DESIGN-PLAN unicon is an entry `unicon__<name>` of the icon master; the plan is
`harness/designs/unicon/STEPS.tsv`, graded by `harness/scripts/test_design_unicon_steps.sh --step N`, which reads an entry first and this
folder second. These six stay because each is a program plus package files, and the unicon oracle answers it only when the package files
are compiled first (`unicon -c`) and linked: MEASURED 2026-11-12, `util_add_ladder_witness.py --oracle unicon --file <package>` cut an
EMPTY answer for the first five against their 1 to 4 line refs. They enter the master when the oracle run and the harness compile a
test's package files (the cio's item), and this folder leaves with them.

- `uni_pkg_import.icn` (`import shapes`: `uni_pkg_shapes.icn`)
- `uni_import_pkg_late.icn` (`import late`: `uni_pkg_late.icn`, which links `uni_pkg_shapes.icn`)
- `uni_link_markerless_unicon.icn` (`link uni_link_markerless_helper`: `uni_link_markerless_helper.icn`)
- `uni_pkg_invocable_before_header.icn` (`import pkinv`: `pkinv.icn`, `pkinv_more.icn`)
- `uni_pkg_two_files.icn` (`import pktwo`: `pktwo.icn`, `pktwo_more.icn`)
- `pkself/uni_pkg_named_like_the_program.icn` (`import uni_pkg_named_like_the_program`: `pkself/lib/pkself_lib.icn`)

Each ref is cut from unicon 13.3 (`unicon_bin()`, twice, identical); the package files carry no ref, being no program of their own.
