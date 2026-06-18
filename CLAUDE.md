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
| Purpose | Real-time QDII overseas-fund valuation + long-term DCA toolkit for US equities |
| Default tab | 估值 (fund valuation) — 6 tabs: 估值 · 行情 · 计算 · 图表 · 对比 · 参考 |

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
│   ├── market_provider.dart        # Market sentiment + watchlist (auto-refresh 1 min)
│   └── fund_provider.dart          # QDII fund estimated valuations (auto-refresh 2 min)
├── screens/
│   ├── home_screen.dart            # Bottom nav shell (6 tabs; 估值 is index 0)
│   ├── fund_valuation_screen.dart  # 估值 — QDII fund valuation list (default home)
│   ├── fund_detail_screen.dart     # Fund holdings detail (top-10 + 展开全部)
│   ├── market_screen.dart          # 行情 — sentiment bar + US watchlist (live)
│   ├── calculator_screen.dart      # 计算 — main DCA calculator
│   ├── chart_screen.dart           # 图表 — asset growth chart + yearly breakdown
│   ├── compare_screen.dart         # 对比 — multi-plan comparison
│   └── reference_screen.dart       # 参考 — macro / historical reference data
├── widgets/
│   ├── input_slider.dart           # Slider input component
│   ├── goal_calculator.dart        # Goal back-calculation widget
│   ├── market_bar.dart             # Market sentiment bar
│   ├── reminder_sheet.dart         # Notification settings sheet
│   └── result_card.dart            # Result display card
└── services/
    ├── fund_data_service.dart      # Fund holdings (F10) + stock changes (proxy/Tencent) + FX
    ├── market_data_service.dart    # Market sentiment + watchlist (multi-source race)
    └── notification_service.dart   # Local push notifications

proxy/
└── yahoo-quote-proxy.js            # Cloudflare Worker — Yahoo quotes incl. pre/post
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
- Market sentiment bar: VIX + NDX + SPX + S&P futures (ES=F)
- Market home screen + US watchlist with live quotes (multi-source race, China-accessible)
- **QDII fund estimated valuation (海外基金估值)** — flagship feature. Formula:
  `估值 = Σ(weight_i × change_i) / Σ(weight_i)  +  FX` (weighted-average change of
  disclosed holdings, **normalized by Σweight** since disclosed ≈ 85-90% of NAV).
  - **Holdings**: Eastmoney F10 — latest quarter top-10 weights merged with the
    annual full holdings (`year=current-1`, the `-12-31` table); cached weekly.
    Covers **US + HK + 沪深 A-shares** (`_yahooSymbol`: 105/106/107 → US ticker,
    116 → `XXXX.HK`, 1 → `.SS`, 0 → `.SZ`).
  - **Stock changes incl. pre/post**: a self-hosted Yahoo proxy
    (`proxy/yahoo-quote-proxy.js`). Chinese quote APIs freeze at the regular close
    overnight, so this is required for pre/post. Set `FundDataService.proxyBase`.
    The proxy's `pickChange` returns each stock's move **in its own market's
    session** — US pre-market → preMarketChangePercent (0 if untraded); an HK/A
    stock whose market has closed (marketState POST/POSTPOST/CLOSED) →
    regularMarketChangePercent (its today move), NOT 0. Tencent `qt.gtimg.cn` is
    the US regular-session fallback.
  - **FX**: Sina onshore PBOC mid-rate (央行中间价) via `fx_susdcny` — what QDII
    NAV uses (NOT Yahoo CNY=X / offshore CNH).
  - **Top bar**: QQQ(纳指100)/SPY(标普500)/汇率 — ETFs (not indices) so pre/post
    works. 红涨绿跌 (Chinese convention: red up, green down).
  - **Detail**: estimate uses the FULL holdings; list shows top-10 + 展开全部数据.
  - Official NAV (`fundmobapi` batch) marked "净值" as fallback before holdings load.

---

## Backlog / 待开发

- P/E historical percentile + Shiller CAPE (Reference screen)
- Position size manager
- Background (app-closed) price-tier monitoring — needs workmanager/background fetch
- iOS build (requires Mac + Apple Developer account)

---

## External APIs / 外部API

All free, no key. Chosen to stay accessible from mainland China.

| Data | Endpoint |
|------|----------|
| Fund holdings (持仓) | `fundf10.eastmoney.com/FundArchivesDatas.aspx?type=jjcc&code=…` |
| Official fund NAV (fallback) | `fundmobapi.eastmoney.com/FundMNewApi/FundMNFInfo` |
| US stock quotes incl. pre/post | Yahoo via self-hosted proxy `proxy/yahoo-quote-proxy.js` |
| US stock quotes (regular fallback) | `https://qt.gtimg.cn/q=r_usTICKER` (Tencent) |
| Indices / VIX | Tencent `qt.gtimg.cn` + Sina `znb_VIX` + Eastmoney (multi-source race) |
| USD/CNY 在岸中间价 | `https://hq.sinajs.cn/list=fx_susdcny` (Sina) |
| Exchange rates | `https://api.frankfurter.app/latest?from=USD&to=HKD,CNY` |
| CPI / 10Y yield (Reference) | FRED CSV + BLS / Yahoo `^TNX` |

> ⚠️ `push2.eastmoney.com` 502s for foreign IPs (works in China); `push2delay.*`
> works abroad but freezes overnight (no pre/post). Yahoo is GFW-blocked in China
> → that is why pre/post needs the self-hosted proxy.

**API failure policy**: On any API error, show cached value or "Unavailable" — never crash.

---

## Data Layer Logic / 数据分层逻辑

| Layer | Data | Frequency |
|-------|------|-----------|
| 估值 — fund valuation | holdings (cached ~weekly) × live stock changes + FX | auto-refresh 2 min |
| 行情 — market bar + watchlist | VIX + NDX/SPX + ES futures + US watchlist | auto-refresh 1 min |
| Reference screen | historical returns + CPI + 10Y yield | macro context, occasional |

---

## Target User / 用户背景

- iOS + Android dual platform; users mainly in **mainland China** (data sources
  must be China-accessible — this drives most architecture decisions)
- Non-professional retail investors; UI must be intuitive and jargon-light
- Holds Chinese QDII overseas funds + tracks US equities (Nasdaq 100 / S&P 500)
- Wants a reference app's live fund 估值 (incl. pre/post) reproduced accurately

---

## Development Rules / 开发规范

1. **Read before editing** — always `Read` the target file to confirm existing structure before making changes.
2. **One feature at a time** — complete and describe test points before moving on.
3. **Separation of concerns** — Providers own business logic; Screens own UI only.
4. **Validate all user input** — handle nulls and edge cases at every entry point.
5. **New screens** → `lib/screens/`; **new widgets** → `lib/widgets/`.
6. **No hardcoded colors** — use `colorScheme` tokens.
7. **No hardcoded strings for UI text** — keep Chinese UI labels consistent and readable.
