"""lib_package_keys.py -- THE ONE RULE FOR THE PROGRESS KEY OF A PACKAGE UNIT GRADED THROUGH A DRIVER (the coo 2026-10-09,
ceo CEO-1366 (b) under CEO-1269). Imported by corpus_suite_harness.py (the key it writes) and util_progress_prune_ghosts.py (the
key it expects), so the two can never disagree.

The Icon boards key a library graded through its driver by the LIBRARY: test_icon_arizona_suite.sh grades X_driver.icn as X when
X.icn is shipped beside it and X carries no .ref of its own (CEO-1269: "the identity is the library, the executable is its
driver"). A container entry stays named after the file that RUNS (the harness stages it under that name, and staging a driver as
X.icn would shadow the library it links), so the rule is applied where a key is WRITTEN or COMPARED, never to the entry's name.
"""
from pathlib import Path


def board_key(pkg_dir, lang, name):
    """The progress key a package's board writes for the container entry `name` (e.g. general/convert_driver -> general/convert)."""
    if lang != "icon" or not name.endswith("_driver"):
        return name
    lib = name[: -len("_driver")]
    d = Path(pkg_dir)
    if (d / (lib + ".icn")).is_file() and not (d / (lib + ".ref")).is_file():
        return lib
    return name
