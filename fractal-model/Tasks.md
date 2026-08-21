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
- [x] On each new Reference HTF candle: check completed prior candle's high against the running unswept-high tracker (update tracker if not yet swept and new candle's high exceeds it); same for low against unswept-low tracker
- [x] Confirmed-close condition (Q1 round 3): wick beyond the tracked extreme, then that same candle's close back inside — mirror the shape of `:2038-2039` (`high_breached and prev_candle.c < prev_prev_candle.h`) but evaluated against the tracked running extreme, not `prev_prev_candle`
- [x] On confirmed mark: reset that side's tracker (it's been "taken"), push a mark record, trim to the history-count input (mirror `:2062-2065`'s trim pattern)
- [ ] Apply `settings.bias` filter at draw time (skip low-side marks when Bearish-only, high-side when Bullish-only) — no new bias state, just a condition in the draw step (Q1 round 4) — **deferred to section 5**, detection intentionally records both sides unconditionally

## 5. Drawing
- [x] `DrawReferenceCandles` / `DrawReferenceLabel` sibling methods reading the new dedicated settings struct (Key Finding 1) — `DrawVTHLLines` confirmed fully generic (reads only `candleSet.settings`) and reused directly on `htf2`, no sibling needed. `DrawCandles`/`DrawVTHLLines`/`DrawLabels` bodies unmodified.
- [x] `DrawReferenceCandles` colors: global `settings.bull_body`/`bear_body`/`bull_border`/`bear_border`/`bull_wick`/`bear_wick`, per Q1 correction
- [x] `DrawReferenceLabel` text format: `HTFName(...) + ' close ' + RemainingTime(...)`, one line, per Q2 correction
- [x] `CalculatePositionsReference` — sibling reading `ref_settings.width`/`offset`
- [x] `DrawLiquidityMarks` — new method, one line per stored mark from `mark.extreme_idx`/`price` to `mark.confirm_idx`/`price`, using `ref_settings.liq_*`; bias filter applied here (`Bullish → not mark.is_high`, `Bearish → mark.is_high`, matched against `DrawSetups`' `bias_ok` convention — `is_bullish` = low sweep, confirmed at `:58`). Does not route through `DrawSweeps`.
- [x] No `DrawSetups` equivalent
- [x] `DrawAllReference` composes the above (mirrors `DrawAll`), wired into Main Execution's drawing block gated on `ref_settings.enabled` + `valid_ref_htf`, using `ref_settings.offset`

## 6. Object-budget check
- [x] Counted at defaults (`max_display=4`, `liq_history=10`, VT/HL/label all on): `DrawReferenceCandles` = 4 boxes + 8 lines (body + 2 wicks × 4 candles); `DrawVTHLLines` (reused) = 4 VT lines (all candles) + 6 HL lines (skips the forming candle, `i != 0`) = 10 lines; `DrawReferenceLabel` = 1-2 labels (`label_position` defaults to `'Top'` → 1); `DrawLiquidityMarks` = up to 10 lines (`liq_history`). Total at defaults: **4 boxes, ~28 lines, 1-2 labels** — negligible against the 500/500/500 ceiling (`:3`), even stacked on top of the primary track + 3 Calendar sources.
- [x] `max_boxes_count`/`max_lines_count`/`max_labels_count` (`:3`) left unchanged — no headroom problem at defaults, no reason to raise
- [x] No new `maxval` added to `htf2.settings.max_display` or `ref_settings.liq_history` — the primary track's own `htf.settings.max_display` (`:724`) has no `maxval` either; this is an existing accepted pattern (user's own input, not new risk this feature introduces), not something in scope to newly guard against

## 7. Docs
- [x] `CONTEXT.md` — Reference HTF and Liquidity Mark terms added (this session)
- [ ] `fractal-model/README.md` — add Reference HTF section: what it draws, settings, how Liquidity Mark differs from Sweep (per CLAUDE.md: README is source of truth for trade logic and must match when detection/drawing behavior changes)

## 8. Release
- [ ] Manual validation in TradingView's Pine Editor (no local compiler) — golden path: enable Reference HTF on a custom timeframe different from the Fractal HTF, confirm candles/VT/HL/label draw correctly, confirm a Liquidity Mark fires only on breach + confirmed close-back (not on every new high), confirm it respects the Bias filter
- [ ] Verify same-timeframe edge case (Reference HTF timeframe == Fractal HTF Custom timeframe) draws two overlapping identical tracks with no error — no guard needed, per confirmed scenario answer
- [ ] Push as new version to the existing invite-only script
