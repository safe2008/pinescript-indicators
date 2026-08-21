# Tasks — Reference HTF + Liquidity Mark (`fractal-model.pine`)

Implements the **Reference HTF** and **Liquidity Mark** concepts defined in [`CONTEXT.md`](./CONTEXT.md): a second, independently-timeframed candle series projected beside the chart for visual context — no Sweep → C2 → CISD → projection tracking, just its own lightweight breach-and-close-back mark. Design settled via `/grill-with-docs`: candle box + Vertical Lines + L/H Lines + HTF Label/countdown timer + Liquidity Mark; no Previous EQ, no HTF Open trace, no C2/CISD/entry-zone/projection/liquidity, no alerts.

**Key findings from investigating the current code before writing this list:**

1. **`CandleSet`/`Candle`/`CandleSettings` are structurally reusable, but the draw methods are not.** `CalculatePositions`, `DrawCandles`, `DrawVTHLLines`, `DrawLabels`, `DrawTrace` (`:2401-2485`) all take `CandleSet` as a parameter, but pull colors/sizes/toggles from the single **global** `settings` object (`Settings` type, `:170-244`) — not from `candleSet.settings` (`CandleSettings`, which only holds `htf`/`max_display`/`vt_*`/`hl_*`). A second `CandleSet` with its own dedicated color group can't just call these methods — it would draw with the *primary* track's colors. `DrawCalendarSource` (`:2890`) is the existing precedent for this exact problem: a new source got new sibling draw methods, not a refactor of the existing ones. Follow that precedent — write `DrawReferenceCandles`/`DrawReferenceVTHL`/`DrawReferenceLabel` etc. rather than parameterizing the primary methods (lower regression risk to the primary HTF render path).
2. **There's already a lightweight "cosmetic-only sweep" block, but it's the wrong shape for Liquidity Mark.** Inside `Monitor` (`:2032-2060`), on every new HTF candle, the code checks `prev_candle.h > prev_prev_candle.h` (etc.) and draws a `Sweep` line — decoupled from the `Setup`/live-tracking machinery, which is exactly the kind of precedent we want. But it compares only the **immediate prior candle** to the one before it. Liquidity Mark was scoped to track the **nearest unswept extreme** (running highest-high/lowest-low until actually taken, decision Q2), which this block doesn't do — needs new persistent state (2 floats + 2 indices, high-side and low-side), not a straight port.
3. **`ta.change()`/`time()` are keyed by call site, not by argument.** Commit `48ef2f1` fixed a real bug where looping `UpdatePeriod()` over Day/Week/Month and calling `ta.change()` from inside a shared function clobbered state across sources. The fix (`:3078-3088`) was to give each source its own **textually distinct** `ta.change(time(...))` statement in Main Execution. Reference HTF's new-candle detection (`isNewRefHTFCandle`) must follow the same pattern — its own call site alongside `isNewHTFCandle` (`:2999`) and `isNewDayPeriod`/`isNewWeekPeriod`/`isNewMonthPeriod` (`:3086-3088`), never a parameterized helper shared with the primary track.

## 1. Settings scaffolding
- [x] New `group_htf2` (or similar) settings group, alongside `group_general`/`group_htf`/`group_calendar` (`:373-376`)
- [x] "Enable Reference HTF?" master toggle — default OFF
- [x] Single `input.timeframe()` custom timeframe field (no mode/preset selector, per Q3 round 1)
- [x] Candle visuals: max-display count, size (Small/Normal/Big → width), offset — own dedicated inputs (layout must differ per track). **Correction (reference screenshot):** body/border/wick color is NOT a dedicated Reference HTF input — reuses primary's `settings.bull_body`/`bear_body`/`bull_border`/`bear_border`/`bull_wick`/`bear_wick` at draw time, so both tracks render in the same color (screenshot shows uniform green across 7H/1D/1W, not a distinct palette). `ReferenceSettings` no longer carries color fields for this.
- [x] Vertical Lines: toggle + color/style/width (mirrors `:668-672`)
- [x] L/H Lines: toggle + color/style/width (mirrors `:673-677`)
- [x] HTF Label + countdown timer: toggle + color/size + position, timer toggle + color/size (mirrors `:814-823`)
- [x] Liquidity Mark: "Show" toggle (default ON once Reference HTF enabled, per Q3 round 3) + color/style/width + history-count input (own count, separate from `settings.sweep_history`)
- [x] No new Bias input — reuse `settings.bias` (`:388`), per Q1 round 4

## 2. Data model
- [x] New `CandleSettings`-shaped struct for Reference HTF (or reuse `CandleSettings` type directly, `:124-135` — same shape covers `htf`/`max_display`/`vt_*`/`hl_*`) — reused `CandleSettings` directly
- [x] New candle-visual-cosmetics struct (body/border/wick colors, width, offset, label/timer toggles) — `type ReferenceSettings`, Reference HTF's own, not `Settings` (`:170-244`) which is primary-only; matches how `CalendarSettings` (`:139-168`) is its own type rather than reusing `Settings`
- [x] `var CandleSet htf2 = CandleSet.new()` parallel to `var CandleSet htf` (`:313-318`) — backing `array<Candle> candles_2` via its own `var` binding (same reasoning as `candles_1`/`sweeps_1`/`setups_1`, `:309-311`) so re-linking on `:=` doesn't clear history each bar
- [x] Liquidity Mark tracking state: running unswept high (float + bar idx) and unswept low (float + bar idx) — `ref_unswept_high`/`ref_unswept_high_idx`, `ref_unswept_low`/`ref_unswept_low_idx`; new fields, not the `Sweep` type's `htf_candle_idx`/`swept_candle_idx` pair (those assume a `Setup` will follow)
- [x] Liquidity Mark storage: `type LiquidityMark` (price, extreme_idx, confirm_idx, is_high) + `var array<LiquidityMark> ref_liq_marks` — bounded by the new history-count input (trim logic left for section 4), not `candleSet.sweeps` (that array feeds `DrawSweeps` → primary-only colors/toggle)

## 3. Reference HTF candle building
- [x] Own `isNewRefHTFCandle` — textually distinct `ta.change(time(ref_settings.custom_tf))` call site in Main Execution, not shared/parameterized with `isNewHTFCandleTf` or any Calendar call site
- [x] `htf2.Update()` every bar — confirmed the existing `Update(CandleSet candleSet)` is already fully generic, used unmodified
- [x] `method MonitorReference(CandleSet candleSet, bool isNewCandle)` — new dedicated method (not a flag on `Monitor`), candle-append + trim-to-`max_display` only, no `Setup` progression, no cosmetic-sweep block
- [x] No `calculate_on_close`/`should_run_monitor` gating needed — no live Setup tracking to gate; `MonitorReference`'s own `if isNewCandle` guard is sufficient, `Update()` runs every tick like primary

## 4. Liquidity Mark detection
- [ ] On each new Reference HTF candle: check completed prior candle's high against the running unswept-high tracker (update tracker if not yet swept and new candle's high exceeds it); same for low against unswept-low tracker
- [ ] Confirmed-close condition (Q1 round 3): wick beyond the tracked extreme, then that same candle's close back inside — mirror the shape of `:2038-2039` (`high_breached and prev_candle.c < prev_prev_candle.h`) but evaluated against the tracked running extreme, not `prev_prev_candle`
- [ ] On confirmed mark: reset that side's tracker (it's been "taken"), push a mark record, trim to the history-count input (mirror `:2062-2065`'s trim pattern)
- [ ] Apply `settings.bias` filter at draw time (skip low-side marks when Bearish-only, high-side when Bullish-only) — no new bias state, just a condition in the draw step (Q1 round 4)

## 5. Drawing
- [ ] `DrawReferenceCandles` / `DrawReferenceVTHL` / `DrawReferenceLabel` sibling methods reading the new dedicated settings struct (Key Finding 1) — do not modify `DrawCandles`/`DrawVTHLLines`/`DrawLabels`
- [ ] `DrawReferenceCandles` colors: use the global `settings.bull_body`/`bear_body`/`bull_border`/`bear_border`/`bull_wick`/`bear_wick` (same values primary draws with), NOT a Reference-HTF-specific color — corrected per reference screenshot (Q1), `ReferenceSettings` has no color fields for this anymore
- [ ] `DrawReferenceLabel` text format: `HTFName(candleSet.settings.htf) + ' close ' + RemainingTime(candleSet.settings.htf)` — e.g. `"1D close 15:10:16"`, ONE line — corrected per reference screenshot (Q2), do NOT reuse primary's two-line `TF\n\n(remaining)` format (`:2470-2472`) for Reference HTF. `HTFName`/`RemainingTime` (`:1015`/`:987`) are free functions, not tied to the primary track — reusable as-is.
- [ ] `CalculatePositions`-equivalent for `htf2` — needs its own width/offset (from the new settings struct), so also a sibling, not the shared method (`:2401-2410` reads global `settings.width`)
- [ ] `DrawLiquidityMarks` — new method, one dotted line per stored mark (from tracked-extreme price/idx to the confirming candle), using the dedicated Liquidity Mark color/style/width inputs; do not route through `DrawSweeps` (`:2445-2461`, primary-only colors/toggle, and semantically these are not `Sweep`s per `CONTEXT.md`)
- [ ] No candle-projection setup drawing (no `DrawSetups` equivalent) — confirms scope boundary from round 1
- [ ] Wire into Main Execution's drawing block (`:3131-3137`), gated on `barstate.islast or barstate.isrealtime` and Reference HTF's own enable + valid-timeframe checks (mirror `valid_htf`/`ValidTimeframe` pattern, `:3064`)

## 6. Object-budget check
- [ ] Count new persistent objects: candle body (1 box) + 2 wick lines + optional dow-style label per candle × max-display; VT line + 2 HL lines per candle; 1-2 label objects; 1 line per stored Liquidity Mark × history count
- [ ] Re-check `max_boxes_count`/`max_lines_count`/`max_labels_count` in the `indicator(...)` call (`:3`) — these are already at Pine's hard ceiling (500 each); confirm headroom exists with Reference HTF's defaults enabled, note actual numbers, and cap default `max_display`/history-count low enough if not

## 7. Docs
- [x] `CONTEXT.md` — Reference HTF and Liquidity Mark terms added (this session)
- [ ] `fractal-model/README.md` — add Reference HTF section: what it draws, settings, how Liquidity Mark differs from Sweep (per CLAUDE.md: README is source of truth for trade logic and must match when detection/drawing behavior changes)

## 8. Release
- [ ] Manual validation in TradingView's Pine Editor (no local compiler) — golden path: enable Reference HTF on a custom timeframe different from the Fractal HTF, confirm candles/VT/HL/label draw correctly, confirm a Liquidity Mark fires only on breach + confirmed close-back (not on every new high), confirm it respects the Bias filter
- [ ] Verify same-timeframe edge case (Reference HTF timeframe == Fractal HTF Custom timeframe) draws two overlapping identical tracks with no error — no guard needed, per confirmed scenario answer
- [ ] Push as new version to the existing invite-only script
