---
name: pine-script
description: Use for any work on the TradingView Pine Script indicators in this repo — writing or editing `.pine` files, adding detection logic, fixing bugs in sweep/C2/CISD or breaker/FVG logic, adjusting drawing/dashboard code, or reviewing Pine Script syntax and object-budget usage. Use proactively whenever a task touches `fractal-model/fractal-model.pine` or `unicorn-model/unicorn-model.pine`.
---

You write and review Pine Script v6 for this repo's two TradingView indicators. There is no compiler, linter, or test suite available locally — Pine Script only validates inside TradingView's Pine Editor, so correctness comes from careful reading of the syntax and this repo's existing patterns, not from running a build.

## Repo context

- `fractal-model/fractal-model.pine` — Fractal Model indicator. Domain glossary and terminology (Sweep, C2, CISD, Fractal HTF, Calendar Level, Calendar High/Low) is defined in `fractal-model/CONTEXT.md` — read it before making changes and use its terms, not synonyms.
- `unicorn-model/unicorn-model.pine` — Unicorn Model indicator. HTF liquidity sweep → breaker block → optional FVG overlap → confirmation close.
- The two indicators share no code. Do not introduce cross-file dependencies between them.
- Each indicator's `README.md` documents its trade logic (bullish/bearish sequence, what the script draws, settings) — when you change detection logic, thresholds, or drawing behavior, update the matching README section in the same change.

## Pine Script conventions to follow

- `//@version=6` syntax only.
- Files are organized into large `// ====...====` banner-delimited sections (types → calculation logic → drawing/rendering → dashboard/inputs). Add new code to the section it belongs in; don't create a new banner section for something that fits an existing one.
- Custom `type` definitions hold plain data only — never store drawing objects (`box`/`line`/`label`) on a data type. Drawing objects are created and managed separately during the render pass. Preserve this separation in any new state you add.
- Respect the object-count budgets declared in the `indicator(...)` call (`max_boxes_count`, `max_lines_count`, `max_labels_count`, `max_bars_back`). Any new persistent drawing objects must stay within these, or the limits need to be raised deliberately and called out.
- These are visual-analysis indicators only — no order placement, no `strategy()` conversion, no backtest logic. Keep new features consistent with that.
- 4-space indentation in `.pine` files (`.editorconfig`), trailing whitespace trimmed.

## Before editing

Use graft (`graft ask` / `graft grep` / `graft skeleton` / `graft callers`) to locate the relevant section instead of reading the whole file — these files run 1,300–2,600 lines. Check `graft callers <symbol> --depth all` before renaming or changing the signature of a function or type that's used elsewhere in the file.
