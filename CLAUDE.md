# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Collection of TradingView Pine Script (v6) indicators. Each indicator is a single self-contained `.pine` file plus a `README.md` guide and an `images/` folder of anonymized chart examples. There is no build system, package manager, linter, or test suite — Pine Script has no local compiler or CLI. Validation happens by pasting the script into TradingView's Pine Editor and checking for compile errors on the chart.

## Structure

- `fractal-model/fractal-model.pine` — "Fractal Model" indicator (~2,550 lines). Multi-timeframe sweep → C2 reversal candidate → CISD confirmation → projection/target sequence. Imports `fstarcapital/AssetCorrelationUtils/12 as ACL`.
- `unicorn-model/unicorn-model.pine` — "Unicorn Model" indicator (~1,400 lines). HTF liquidity sweep → breaker block → optional FVG overlap → confirmation close sequence. MPL-2.0 license header at top of file.
- Each indicator folder's `README.md` is the source of truth for that model's trade logic (bullish/bearish sequence, what the script draws, settings). When changing detection logic, thresholds, or drawing behavior, update the matching README section to match.
- `DONATE.md` — support/donation info, referenced from the root `README.md`.

## Working with the `.pine` files

- `//@version=6` — keep syntax compatible with Pine Script v6.
- Files are organized into large `// ====...====` banner-delimited sections (types, then calculation logic, then drawing/rendering, then dashboard/inputs). Use these banners to navigate rather than scanning line by line — grep for `// ====` or use graft to jump to the relevant section.
- Custom `type` definitions (e.g. `Candle`, `Sweep`, `ICCisd` in fractal-model; `HTFLevel`, `Setup` in unicorn-model) hold plain data only — no drawing objects (`box`/`line`/`label`) stored on them. Drawing objects are created/managed separately during the render pass. Preserve this separation when adding new state.
- Object count limits (`max_boxes_count`, `max_lines_count`, `max_labels_count`, `max_bars_back`) are set in the `indicator(...)` call — any new persistent drawing objects must stay within these budgets or the limits need to be raised deliberately.
- These are visual-analysis tools only: no order placement, no strategy/backtest logic. Keep new features consistent with that (indicator, not strategy).

## Repo tooling

- `graft/` is a prebuilt code index for this repo (gitignored, regenerate with `graft build`). Prefer `graft ask`/`graft grep`/`graft skeleton`/`graft callers` over manually grepping the large `.pine` files.
- `.editorconfig`: `.pine` files use 4-space indentation; trailing whitespace is trimmed everywhere except `.md` files.
