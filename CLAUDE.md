# PulseVest (积川) — CLAUDE.md

AI development reference for this Flutter project. **Always read the relevant source files before making changes.**

> 中文注释：AI开发参考文档。修改代码前必须先读取相关文件确认现有结构。

---

## Project Overview / 项目概述

| Field | Value |
|-------|-------|
| App name (EN) | PulseVest |
| App name (ZH) | 积川（UI display name, do not change） |
| Platform | iOS + Android |
| UI language | Chinese (Simplified) |
| Purpose | Long-term DCA investment calculator for US equities |

---

## Tech Stack / 技术栈

- **Framework**: Flutter 3.x + Dart
- **Charts**: fl_chart
- **State management**: provider
- **Local storage**: shared_preferences
- **Networking**: http
- **Notifications**: flutter_local_notifications
- **Utilities**: timezone / intl / google_fonts

---

## Design System / 设计规范

| Token | Value |
|-------|-------|
| Background | `#0D0D0D` |
| Card background | `#1A1A1A` |
| Primary (orange) | `#FF6B2B` |
| Accent (gold) | `#FFB347` |
| Text | `#FFFFFF` |

**Rules:**
- Orange is reserved for key data and interactive elements only; everything else is black/white/grey.
- Minimal, restrained aesthetic.
- **Never hardcode color values** — always reference `Theme.of(context).colorScheme`.

---

## Project Structure / 项目结构

```
lib/
├── main.dart
├── models/
│   └── investment_model.dart       # Data models + built-in ETF reference data
├── providers/
│   ├── calculator_provider.dart    # Core calculation logic + state
│   ├── currency_provider.dart      # Live exchange rates
│   └── market_provider.dart        # Market sentiment data (VIX, futures)
├── screens/
│   ├── home_screen.dart            # Bottom nav shell
│   ├── calculator_screen.dart      # Main DCA calculator
│   ├── chart_screen.dart           # Asset growth chart + yearly breakdown
│   ├── compare_screen.dart         # Multi-plan comparison
│   ├── reference_screen.dart       # Macro reference data
│   └── takeprofit_screen.dart      # Take-profit price calculator
├── widgets/
│   ├── input_slider.dart           # Slider input component
│   ├── goal_calculator.dart        # Goal back-calculation widget
│   ├── market_bar.dart             # Market sentiment bar
│   ├── reminder_sheet.dart         # Notification settings sheet
│   └── result_card.dart            # Result display card
└── services/
    └── notification_service.dart   # Local push notifications
```

---

## Completed Features / 已完成功能

- DCA compound interest calculation (monthly / quarterly / annual frequency)
- Lump-sum + DCA hybrid calculation
- Goal back-calculation: years needed or monthly contribution needed
- Multi-plan save & compare (SharedPreferences persistence)
- Asset growth chart + yearly breakdown table
- Live exchange rates: USD / HKD / CNY (frankfurter.app)
- Inflation-adjusted display
- Built-in historical annualized returns: QQQM / VOO / SPY / QQQ / VTI
- Monthly DCA reminder notifications
- Market sentiment bar: VIX + Nasdaq futures (NQ=F) + S&P futures (ES=F)
- Take-profit calculator: input average cost, display +10% / +15% / +20% / +25% target prices
- 10-year US Treasury yield (Reference screen — `^TNX` via Yahoo Finance)
- US CPI YoY (Reference screen — BLS public API + FRED CSV fallback)

---

## Backlog / 待开发

- P/E historical percentile + Shiller CAPE (Reference screen)
- Pyramid averaging-down calculator
- Position size manager
- iOS build (requires Mac + Apple Developer account)

---

## External APIs / 外部API

| Data | Endpoint |
|------|----------|
| Exchange rates | `https://api.frankfurter.app/latest?from=USD&to=HKD,CNY` |
| VIX | `https://query1.finance.yahoo.com/v8/finance/chart/^VIX?interval=1d&range=1d` |
| Nasdaq futures | `https://query1.finance.yahoo.com/v8/finance/chart/NQ=F?interval=1d&range=1d` |
| S&P futures | `https://query1.finance.yahoo.com/v8/finance/chart/ES=F?interval=1d&range=1d` |
| 10Y Treasury | `https://query1.finance.yahoo.com/v8/finance/chart/^TNX?interval=1d&range=1d` |
| CPI | `https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCSL` (free, no key) |

**API failure policy**: On any API error, show cached value or "Unavailable" — never crash.

---

## Data Layer Logic / 数据分层逻辑

| Layer | Data | Frequency |
|-------|------|-----------|
| Home — market bar | VIX + Nasdaq futures + S&P futures | Daily trading signals |
| Reference screen | P/E percentile + Shiller CAPE + CPI + 10Y yield | Macro context, occasional |

---

## Target User / 用户背景

- iOS + Android dual platform
- Non-professional retail investors; UI must be intuitive and jargon-light
- Primary focus: Nasdaq 100 ETFs (QQQM / QQQ); secondary: S&P 500
- Strategy: long-term DCA + pyramid averaging-down + staged take-profit

---

## Development Rules / 开发规范

1. **Read before editing** — always `Read` the target file to confirm existing structure before making changes.
2. **One feature at a time** — complete and describe test points before moving on.
3. **Separation of concerns** — Providers own business logic; Screens own UI only.
4. **Validate all user input** — handle nulls and edge cases at every entry point.
5. **New screens** → `lib/screens/`; **new widgets** → `lib/widgets/`.
6. **No hardcoded colors** — use `colorScheme` tokens.
7. **No hardcoded strings for UI text** — keep Chinese UI labels consistent and readable.
