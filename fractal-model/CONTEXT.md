# Fractal Model

TradingView Pine Script indicator that detects a higher-timeframe liquidity sweep, marks a reversal candidate, and confirms it through a lower-timeframe change in delivery before projecting trade levels.

## Language

**Sweep**:
Price trading beyond a reference level (a Fractal HTF level or a Calendar Level) and then closing back through it, creating a reversal candidate.
_Avoid_: Liquidity grab, stop hunt

**C2**:
The reversal candle identified immediately after a Sweep — the reversal candidate the script tracks toward confirmation.
_Avoid_: Reversal candle, signal candle

**CISD**:
The confirmation level derived from the candles around a C2; price closing through it confirms the reversal as a valid setup.
_Avoid_: Confirmation line, change in delivery (spell out only on first use, then say CISD)

**Fractal HTF**:
The higher-timeframe candle series chosen via the `Fractal` input (`Automatic`, `Quarterly`, `Custom`, or an explicit LTF/HTF pairing) and projected beside the chart as the Sweep reference.
_Avoid_: Bare "HTF" — ambiguous with Calendar Level, which is also a higher-timeframe concept but selector-independent

**Calendar Level**:
A Sweep reference tied to a fixed calendar period (Day, Week, or Month) instead of the `Fractal` selector. Each period runs its own independent Sweep → C2 → CISD track, in parallel with the Fractal HTF track and the other Calendar Levels — a setup already swept keeps tracking its original level through confirmation even after the calendar period rolls over.
_Avoid_: HTF level

**Calendar High / Calendar Low**:
The high or low of a Calendar Level's period — the price a Sweep is measured against. Labeled on chart as PDH/PWH/PMH (highs) and PDL/PWL/PML (lows) for Day/Week/Month respectively.
_Avoid_: Treating PDH/PDL etc. as a separate concept — they are the on-chart labels for Calendar High/Low, not a distinct idea.
