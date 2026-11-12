# SCRIP's source tree as it stands, and the first proposal (the cto, 2026-11-12 12:4x CST, for Lon to react to)

Asked by Lon in the cto's window (the cache-tree rulings, skill `scrip-build` reference section 4, CTO-636) and through the coo 12:3x ("let the fleet go idle. We want in a very short bit to TOTALLY re-organize the source base. Talk to CTO."). Tree: SCRIP 1a78b0c0d. Nothing in SCRIP moves until Lon says so.

## 1. The tree by directory (MEASURED: `find src` and `wc -l` per kind)

| directory | layer | owning skill | units (.c/.cpp): files / lines | headers: files / lines | data .inc: files / lines | asm |
|---|---|---|---|---|---|---|
| `driver` | driver | scrip-architecture | 14 / 8030 (`scrip.c` 3992, `kernel.c` 1468) | 11 / 281 | - | - |
| `parsers/{snobol4,snocone,rebus,icon,pascal,prolog,raku}` + `parser_main.c` | parse | the language skill | 32 / 45951 (bison/flex 7 of them, exempt) | 24 / 1572 | 4 / 95401 (`prolog_prelude_libs.inc` 38928, `rk_core_names.inc` 51439, `pascal_prelude_units.inc` 4396) | - |
| `lower` | lower | lowering + the language skill | 16 / 42081 (`lower_pascal_tree.c` 8609, `lower_raku.c` 7971, `lower_prolog.c` 7183, `lower_snobol4.c` 5682, `lower_icon.c` 4423) | 18 / 838 | - | - |
| `ir` | IR | scrip-architecture | 6 / 1298 | 23 / 1218 | 1 / 39 | - |
| `optimizer` | optimize | scrip-architecture | 11 / 849 | 11 / 179 | - | - |
| `planner` | plan | scrip-memory-model | 10 / 8050 (`frame_layout.c` 3202, `zeta_plan.cpp` 2859) | 7 / 510 | 1 / 44 (`box_cell_shapes.inc`, generated) | - |
| `emitter` | emit | scrip-memory-model, box-templates | 3 / 5684 (`emit.cpp` 5421) | 13 / 1017 | - | - |
| `templates/bb` | templates | box-templates | 140 / 14367 | 3 / 369 | - | - |
| `templates/x86` | templates | box-templates | 12 / 3851 | 13 / 638 | 2 / 3508 (`gc_allocating_table.inc`, generated) | - |
| `templates/xa` | templates | box-templates | 18 / 1446 | 2 / 33 | - | - |
| `runtime` (flat) | runtime | runtime-calls + the language skill | 28 / 48662 (`by_name_dispatch.c` 29846, `unification.c` 6266, `pattern_match.c` 3036) | 16 / 672 | 8 / 4408 (`builtin_table.inc`, `builtin_leaf.inc`, `rt_entry_table.inc`, generated) | - |
| `runtime/core` | runtime | runtime-calls | 5 / 5459 (`core.c` 5362) | 36 / 1302 (the `g_runtime_*.h` family: 20 headers) | 3 / 203 | - |
| `runtime/rt` | runtime | gc-collector (gc_*), runtime-calls | 17 / 9914 (`gc_heap.c` 4352, `rt.c` 2679) | 19 / 956 | - | 2 / 445 |
| `runtime/rtx` | runtime leaves | rtx-asm-leaves | 16 / 2011 | 1 / 54 | 1 / 35 | 16 / 10898 |
| `runtime/builtins` | runtime | runtime-calls | 1 / 275 | 3 / 64 | - | - |

The runtime directory is half by mechanism (`core`, `rt`, `rtx`) and half flat. Its flat files carry every language's builtins: `by_name_dispatch.c` holds 1766 functions, MEASURED by `util_unit_spans.py`. By name prefix, in lines: Prolog about 9,480 (`pl_`, `rt_pl_`, `plw_`, `dop_pl_`), Raku 5,670 (`rk_`), Pascal 2,763 (`pas_`), Icon 713 (`icn_`), SNOBOL4 237 (`sno_`, `rt_sno_`), and the shared dispatch. That dispatch includes `try_call_builtin_by_name_bl_s_rq`, 2,697 lines in one function. Beside it sit `rk_rat.c`, `pl_rat.c`, `pas_xr.c`, `icn_extfn.c` and `unicon_leaves.c`.

## 2. The build's view (MEASURED: `make -B -n build-all`, the Makefile)

- 305 C/C++ units plus the asm leaves. All of them are in ONE hand-written list, `RT_PIC_SRCS`, linked into `out/libscrip_rt.so` (the compiler and the runtime, because EVAL and CODE compile at run time). The driver `scrip` links against it. The four parser modules are each their own `.so`, plus the Prolog prelude `.so`.
- The Makefile is 2344 lines, 1402 of them about gates. Every split or move edits the hand list.
- Seven generated or embedded tables are spliced by `#include` into code units: `gc_allocating_table.inc` into `gc_heap.c`, `builtin_table.inc` and `builtin_leaf.inc` into `by_name_dispatch.c`, `rt_entry_table.inc` into `emit.cpp`, `box_cell_shapes.inc` into `zeta_plan.cpp`, `prolog_prelude_libs.inc` into `prolog_parse.c`, `pascal_prelude_units.inc` into `pascal_driver.c`, `rk_core_names.inc` into `rk_syntax.c`.
- One ccache serves every root and worktree. The build cache `/home/resources/builds/scrip/<key>` is all or nothing on the whole tree hash, so per-unit sharing is ccache's job.

## 3. The cross-layer includes (MEASURED: every quoted include, resolved, counted between layers)

`templates/bb -> templates/x86` 488, `templates/bb -> emitter` 277, `templates/bb -> ir` 115, `lower -> ir` 103, `runtime -> runtime/core` 85, `runtime -> runtime/rt` 65, `driver -> ir` 56, `planner -> ir` 53, `runtime -> ir` 48, `templates/x86 -> emitter` 47.

The edges that run against the pipeline: `lower -> parsers/snobol4` 14, `runtime -> emitter` 9, `runtime -> driver` 7, `runtime/core -> runtime/rt` 10, `templates/bb -> runtime/*` 43, `templates/bb -> optimizer` 8. The runtime edges are the in-process compiler that EVAL and CODE use. They are real, but today they go through headers of the layers above instead of one interface header.

## 4. What it costs the fleet (MEASURED: `util_cache_blast.py`, 2204 commits since 2026-10-12, priced on today's graph)

Each commit forces 26.93 G compile instructions through the shared cache on average, 5.9 percent of a 458.6 G full build. By instructions forced over the 30 days:

- `by_name_dispatch.c`: 11.2 T, 19 percent of the total.
- `emit.cpp`: 4.9 T.
- `stage2.h`: 4.0 T (56 units an edit).
- `descr.h`: 3.8 T (191 units an edit).
- `emit_state.h`: 3.5 T (171 units an edit).
- `g_runtime_misc.h` and `g_runtime.h`: 3.5 T and 3.2 T (82 units an edit).
- `bb_templates.h`: 2.9 T.
- `builtin_table.h`: 2.7 T.

A unit costs at least its headers: 0.1 to 0.2 G for a C unit, about 0.9 G for a template unit. The full table is `BLAST.baseline.txt`.

## 5. The first proposal (the new shape; the laws C1-C8 are in skill `scrip-build` reference section 4)

```
src/
  driver/                 scrip.c cut by job (argv, modes, the dump flags, the run loop)
  parsers/<lang>/         as now; each embedded table a data unit of its own (C1)
  lower/common/  lower/<lang>/   lower_<lang>*.c cut into cluster units of 300-800 lines (C2-C4)
  ir/  optimizer/         as now
  planner/                zeta_plan.cpp and plan_facts.cpp cut; box_cell_shapes a data unit
  emitter/                emit.cpp cut into about 20 cluster units; rt_entry_table a data unit
  templates/{bb,x86,xa}/  the three dearest bb units cut; bb_templates.h cut per family (C5)
  runtime/
    core/ rt/ rtx/        as now; gc_heap.c cut; gc_allocating_table a data unit; g_runtime_*.h cut (C5, Lon's grant)
    lib/<lang>/           by_name_dispatch.c, unification.c, pattern_match.c and the flat language files, one
    lib/shared/           directory per language, each cut into cluster units with its own export headers
    lib/dispatch.c        the strcmp chains until DESIGN-PLAN builtin-table step 2 deletes them
    lib/tables/           builtin_table, builtin_leaf as data units
  (headers beside the unit they declare; no separate include tree)
Makefile: one wildcard per directory in place of the hand list, so a split or a move never edits it.
```

PROJECTED, a HYPOTHESIS until a step lands and the blast reads it: `by_name_dispatch.c` alone falls from 11.18 T to 1.28 T, an 89 percent cut. The plan's finish is 5 G a commit or less, from 26.93. The plan is `STEPS.tsv` beside this file: step 0 the instruments, step 1 the split tool, step 2 the reader ratchet, steps 3a-3h the data units, 4-22 the hot units, 23-29 the headers, 30 the moves, 31 the joins, 32 the finish.

**The hazards, MEASURED.** 162 harness files name `by_name_dispatch.c`, 117 name `emit.cpp`, 113 `gc_heap.c` and 91 `core.c`. A gate that greps a deleted file can read a false zero, so each split repoints its readers in the same landing (C8). Origin moves about 20 commits an hour, so a split is a manifest re-applied on HEAD at landing, never a hand rebase.

**For Lon:** (1) "split C and H files": the plan reads it as cutting the headers like the units (C5). A separate `include/` tree is the other reading; it does nothing for the cache and doubles every path a seat reads. (2) Cutting the `g_runtime` sub-records out of the one by-value struct is a runtime-state change and waits on your grant.
