# Legacy Archive

This folder keeps old development artifacts that are useful as references but
are no longer part of the active mod or tool workflow.

## static

The `static` folder contains artifacts from the older static review workflow.
That workflow inspected the generated `material-flow.json` and produced simple
human-readable target lists such as:

```text
ingredient -> recipe -> result
```

The JSON tree viewer and active ancestry dumps replaced these lists as the main
review surface. The active runtime still uses `code/core/collector.lua` as the
baseline data-table collector and fallback, so the collector is intentionally
not archived here.

Moved static artifacts:

- `material_flow_list.py`
- `target-lists/`
- old minimal compat dumps for `angels_is`, `bobs_is`, and `bob_angels_is`

## weighted

The `weighted` folder is for artifacts from the recipe-chain scoring/evidence
experiments. That method compared current recycle targets with weighted recipe
evidence and could stage high-confidence target changes.

The live Lua implementation is still present because debug tests and the
optional `yis-use-recipe-chain-targets` setting can still use it. Only generated
offline comparison dumps that are no longer needed for the current active
ancestry review should live here.

Moved weighted artifacts:

- old `_comparisons/` dump files
