# CarGuard AI

AI-powered Pre-Delivery Inspection (PDI) assistant for new car buyers in India.

**Fully on-device** — SQLite storage, ML Kit OCR, and local image analysis. No Mac server or backend required.

## Repository Structure

```
carguard-ai/
├── mobile/           # Flutter app (iOS / Android / macOS)
│   ├── lib/core/ai/  # On-device OCR, VIN/tyre/odometer parsers
│   └── assets/data/  # Vehicle catalog (bundled JSON)
└── scripts/          # Dev & iPhone install helpers
```

## Quick Start — iPhone (physical device)

```bash
~/Downloads/carguard-ai/scripts/start-iphone.sh --release
```

Open **CarGuard AI** from the home screen after install.

For hot reload while developing:

```bash
~/Downloads/carguard-ai/scripts/dev.sh
```

## Quick Start — Simulator / macOS / Chrome

```bash
~/Downloads/carguard-ai/scripts/start-mobile.sh          # Chrome
~/Downloads/carguard-ai/scripts/start-mobile.sh macos    # macOS app
```

## Features

- Vehicle selection (Hyundai, Tata, Maruti, Mahindra, Kia)
- Guided inspection journey with progress tracking
- Camera capture with on-device ML Kit analysis
- Multi-pass VIN OCR with check-digit validation
- Tyre DOT decode, odometer read, dashboard warnings
- Findings, score, dealer notes — all stored locally
- Restart inspection, retake photos, offline capable

## Requirements

- Flutter SDK 3.5+
- Xcode + Apple Developer account for physical iPhone
- iOS 15.5+ (ML Kit)

## License

Private — all rights reserved.
