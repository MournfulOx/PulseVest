# PulseVest (积川)

> A minimalist DCA investment calculator for US equities — built with Flutter for iOS & Android.
>
> 极简美股定投计算器，支持 iOS + Android 双平台。

---

## Features / 功能

| Feature | Description |
|---------|-------------|
| DCA Calculator | Monthly / quarterly / annual compound interest calculation |
| Hybrid Mode | Lump-sum + recurring DCA combined |
| Goal Back-Calc | How many years, or how much per month, to reach your target |
| Multi-Plan Compare | Save and compare multiple scenarios (persisted locally) |
| Growth Chart | Asset curve + yearly breakdown table |
| Live Exchange Rates | USD → HKD / CNY via frankfurter.app |
| Inflation Adjustment | Real-return display toggle |
| ETF Reference Data | Built-in historical annualized returns: QQQM / VOO / SPY / QQQ / VTI |
| Reminder Notifications | Monthly DCA reminder push notification |
| Market Sentiment Bar | VIX + Nasdaq futures (NQ=F) + S&P futures (ES=F) |
| Take-Profit Calculator | Input average cost → show +10% / +15% / +20% / +25% target prices |

---

## Design / 设计规范

Dark, minimal, orange-accented.

| Token | Hex |
|-------|-----|
| Background | `#0D0D0D` |
| Card | `#1A1A1A` |
| Primary (orange) | `#FF6B2B` |
| Accent (gold) | `#FFB347` |
| Text | `#FFFFFF` |

Orange is used only for key data and interactive elements — everything else is black/white/grey.

---

## Tech Stack / 技术栈

- **Flutter 3.x** + Dart
- [fl_chart](https://pub.dev/packages/fl_chart) — charts
- [provider](https://pub.dev/packages/provider) — state management
- [shared_preferences](https://pub.dev/packages/shared_preferences) — local persistence
- [http](https://pub.dev/packages/http) — API calls
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) — reminders
- timezone / intl / google_fonts

---

## Getting Started / 快速开始

### Prerequisites / 环境要求

- Flutter SDK 3.x — [flutter.dev](https://flutter.dev)
- Android Studio or Xcode (for device builds)

### Run / 运行

```bash
git clone https://github.com/YOUR_USERNAME/PulseVest.git
cd PulseVest
flutter pub get
flutter run
```

### Build / 打包

**Android APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**iOS (requires Mac + Xcode + Apple Developer account):**
```bash
flutter build ipa
```

---

## Project Structure / 项目结构

```
lib/
├── main.dart
├── models/
│   └── investment_model.dart       # Data models + ETF reference data
├── providers/
│   ├── calculator_provider.dart    # Core calculation logic
│   ├── currency_provider.dart      # Live exchange rates
│   └── market_provider.dart        # VIX / futures market data
├── screens/
│   ├── home_screen.dart            # Bottom navigation shell
│   ├── calculator_screen.dart      # DCA calculator
│   ├── chart_screen.dart           # Growth chart + yearly table
│   ├── compare_screen.dart         # Multi-plan comparison
│   ├── reference_screen.dart       # Macro reference data
│   └── takeprofit_screen.dart      # Take-profit calculator
├── widgets/
│   ├── input_slider.dart
│   ├── goal_calculator.dart
│   ├── market_bar.dart
│   ├── reminder_sheet.dart
│   └── result_card.dart
└── services/
    └── notification_service.dart
```

---

## External APIs / 外部数据源

All APIs are free and require no API key (except FRED, also free).

| Data | Source |
|------|--------|
| Exchange rates | [frankfurter.app](https://frankfurter.app) |
| VIX / Futures | Yahoo Finance (public endpoint) |
| CPI | [FRED](https://fred.stlouisfed.org) — `CPIAUCSL` series |

API failures show cached values or "Unavailable" — the app never crashes on network errors.

---

## Roadmap / 计划中

- [x] 10-year US Treasury yield (Reference screen)
- [x] US CPI YoY (Reference screen)
- [ ] P/E historical percentile + Shiller CAPE (Reference screen)
- [ ] Pyramid averaging-down calculator
- [ ] Position size manager
- [ ] iOS App Store release

---

## License

MIT
