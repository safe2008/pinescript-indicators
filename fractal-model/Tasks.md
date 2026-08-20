# Tasks — Calendar Level feature (`fractal-model.pine`)

Implements the Calendar Level concept defined in [`CONTEXT.md`](./CONTEXT.md): Day/Week/Month sweep sources, independent of the `Fractal` selector, wired into the existing Sweep → C2 → CISD → projection engine.

Key finding from investigating the current code before writing this list: `Setup` creation is tied directly to `candleSet.candles` (the projected HTF candle series via `prev_htf` / `isNewHTFCandle`, see `fractal-model.pine:1262-1300`). Calendar Levels have no candle series (no candle-projection panel), so detection needs its own lightweight period-high/low tracker feeding the same downstream `Setup` / C2 / CISD / projection machinery — not a parameter swap on existing functions.

## 1. Settings scaffolding
- [x] New `group_calendar` settings group (alongside `group_general`, `group_htf` at `:273-277`)
- [x] 3 toggles: Day / Week / Month (High + Low bundled per period)
- [x] Own color/style inputs for Calendar Level sweep/C2/CISD/projection drawing — distinct from `htf.settings.*`
- [ ] Reuse existing `settings.bias` (`:287`) — no new bias input

## 2. Data model
- [x] New lightweight type, e.g. `CalendarSource` (period label, current-period high/low, prior-period high/low, `Setup` tracking state) — deliberately *not* `CandleSet` (`:213`), which carries `candles`/`trace` fields Calendar Levels don't need
- [x] 3 instances: Day, Week, Month — parallel to the single `var CandleSet htf` at `:251`

## 3. Period high/low tracking
- [x] Detect period rollover (new day/week/month) and roll "current period H/L" into "prior period H/L" (candidate: `request.security` on `"D"`/`"W"`/`"M"` with `[1]` offset, or manual `time("D")`-change detection — confirm it matches the timezone/session handling already used at `:328`)
- [x] This prior-period H/L is the swept reference (PDH/PDL/PWH/PWL/PMH/PML)

## 4. Sweep detection (new, per Calendar source)
- [x] Port the wick-through-then-close-back-through logic from `:1262-1300` (and its bullish mirror ~`:1500`) to run off the tracked prior-period H/L instead of `prev_htf`/`candleSet.candles.first()`
- [x] On sweep: `Setup.new()`, populate `sweep_price`, `sweep_bar_idx`, `is_bullish` — same shape as existing setups so downstream code doesn't need to branch on source type

## 5. CISD confirmation — reuse
- [x] Wire new setups into `FindCISDLevel` (`:893`) and the `IC*` functions (`:930-1011`, already parameterized on `Setup` — no changes expected)
- [x] Verify `ICTrackExtreme`/`ICUpdate`'s CISD-tracking-extreme initialization (`:1277-1287`) doesn't implicitly depend on `candleSet.candles` beyond what's ported in step 4
- [x] Rollover-persistence: an in-progress (swept, unconfirmed) setup keeps tracking its original swept level to confirmation, even after the calendar period rolls over — only *future* sweeps use the new period's H/L

## 6. Projection + position sizer — reuse
- [x] Confirm `TrySetEntryZoneC3`/`TrySetEntryZoneC4` (`:838`, `:851`) work unmodified against Calendar-sourced `Setup`s
- [x] Reuse existing global R:R/projection-ratio inputs — no new per-period copies

## 7. Drawing
- [x] Level line (PDH/PDL/PWH/PWL/PMH/PML label) drawn from prior-period H/L, using new Calendar color group
- [x] Sweep line, C2 label, CISD line, projection lines — reuse existing draw functions, parameterized by the new color inputs instead of `htf.settings.*`
- [x] No candle-projection panel — skip anything resembling `htf.candles` rendering for these sources

## 8. Alerts
- [x] New `alertcondition()`s per period/direction for sweep + CISD confirmation (mirror pattern at `:1061`, `:1491`, `:1726`), gated on `settings.bias` same as existing alerts

## 9. Object-budget / history management
- [x] Apply the same trim-to-`max_setups` pattern (`:1912-1913`) independently per Calendar source
- [x] Re-check `max_boxes_count`/`max_lines_count`/`max_labels_count` in the `indicator(...)` call — 3 more parallel tracks add persistent drawing objects; raise if needed and note why

## 10. Cross-cutting (from broader update scope)
- [x] Bug-fix pass over existing sweep/C2/CISD logic (no specific report — general review while in this code)
- [x] TradingView House Rules compliance check (alert completeness, description, repainting disclosure)
- [x] Perf/object-budget review of pre-existing code, not just the new feature

## 11. Docs
- [x] Update `fractal-model/README.md` with the Calendar Level sequence, settings table entries, and drawn-elements section
- [x] Extend `fractal-model/CONTEXT.md` only if new terms surface during implementation

## 12. Release
- [ ] Manual validation in TradingView's Pine Editor (no local compiler) — golden path: verify a PDH sweep → C2 → CISD → projection on a live chart for each of Day/Week/Month, both directions
- [ ] Push as new version to the existing invite-only script
