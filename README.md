<div align="center">

# ⚡ Axom AI Mobile App
### *Next-Generation Assamese & Multilingual Intelligent AI Assistant*

[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-4CAF50?style=for-the-badge)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen?style=for-the-badge)]()

<br />

> **Axom AI** is an intelligent, culture-conscious mobile and multi-platform application designed to deliver real-time conversational AI, integrated web search, document utilities, and creative tools tailored for multilingual users with native support for Assamese and English.

---

</div>

## 🌟 Overview

**Axom AI** blends the power of modern Large Language Models with a curated suite of creator utilities into a sleek, cyber-luminous dark interface. Whether querying complex regional information, converting business documents, generating AI imagery, or creating viral memes, Axom AI provides a seamless, high-performance experience powered by Flutter.

---

## ✨ Key Features

### 💬 1. Conversational AI (Axom 2.0 Pro)
- **Real-Time Token Streaming**: Low-latency token-by-token text streaming for instant responses.
- **Integrated Web Search**: Live search capability fetching real-time facts with clickable web citations and domain sources.
- **Rich Markdown Rendering**: Full support for code syntax highlighting, structured tables, math expressions, and bulleted notes.
- **Multi-Session Management**: Create, rename, delete, and search across past conversation histories with offline caching via `SharedPreferences`.

### 🛠️ 2. Integrated Tools Hub
| Tool | Category | Description |
| :--- | :--- | :--- |
| **Word to PDF** | `Document & PDF` | Converts `.docx`, `.doc`, and `.txt` files into high-fidelity formatted PDF files. |
| **AI Image Generator** | `AI Tools` | Generates art, cultural landscapes, and photorealistic imagery from prompts. |
| **Background Remover** | `Creative Suite` | Removes photo backgrounds with AI edge detection for portraits and products. |
| **AI Text Summarizer** | `AI Tools` | Condenses lengthy articles, research papers, and news into concise bullet points. |
| **QR Code Generator** | `Utilities` | Creates high-resolution custom QR codes for URLs, contacts, and Wi-Fi access. |
| **Meme Generator** | `Creative Suite` | Quick-creation viral meme editor with trending templates and custom typography. |

### 🎨 3. Cyber-Luminous UI/UX Design
- **Glowing Orb & Ambient Aesthetics**: Atmospheric gradient backgrounds with fluid micro-animations.
- **Floating Pill Navigation**: Minimalist floating navigation dock for quick tab transitions.
- **Bi-Directional Drawers**:
  - **Left Drawer**: Chat session history, session search, and management.
  - **Right Drawer**: User profile status, membership tiers, and system controls.
- **Adaptive Theme Engine**: Smooth dark and light theme switching with persistent user preferences.

### 🔐 4. Identity & Authentication
- **Secure Credentials Flow**: Username/email login and registration with validation.
- **Guest Access**: Explore the app without mandatory signup.
- **Tiered Access**: Support for Free and Pro Member statuses.

---

## 🏗️ Architecture & Project Structure

```
axomai_app/
├── lib/
│   ├── main.dart                   # Application entry point & theme initialization
│   ├── models/
│   │   ├── chat_message.dart       # Message entity & web source models
│   │   └── chat_session.dart       # Chat session & persistence model
│   ├── screens/
│   │   ├── auth_gate_screen.dart   # Auth status router
│   │   ├── chat_screen.dart        # Main conversational AI view
│   │   ├── login_screen.dart       # Authentication screen
│   │   ├── profile_screen.dart     # User profile & account overview
│   │   ├── tools_hub_screen.dart   # Creator & utility hub
│   │   └── tools/                  # Dedicated screens for tools
│   │       ├── background_remover_screen.dart
│   │       ├── image_generator_screen.dart
│   │       ├── meme_generator_screen.dart
│   │       ├── qr_generator_screen.dart
│   │       ├── summarizer_screen.dart
│   │       └── word_to_pdf_screen.dart
│   ├── services/
│   │   ├── api_service.dart        # HTTP streaming & file conversion API handler
│   │   ├── auth_service.dart       # Auth session & user state management
│   │   └── storage_service.dart    # Local persistence layer
│   ├── theme/
│   │   └── app_theme.dart          # Design system, color palettes & text styles
│   └── widgets/                    # Reusable modular UI components
│       ├── floating_pill_nav_bar.dart
│       ├── glowing_orb.dart
│       ├── header_bar.dart
│       ├── input_bar.dart
│       ├── message_bubble.dart
│       └── ...
├── android/                        # Android native configurations
├── ios/                            # iOS native configurations
├── web/                            # Web engine assets & manifest
└── pubspec.yaml                    # Dependencies & asset declarations
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.12.0` or later)
- [Dart SDK](https://dart.dev/get-dart) (`^3.12.0`)
- Android Studio / VS Code with Flutter & Dart extensions
- Android device or emulator running API 21+

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Samarjitkashyp/axomai_mobileapp.git
   cd axomai_mobileapp
   ```

2. **Install project dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Flutter environment**:
   ```bash
   flutter doctor
   ```

4. **Launch the application**:
   ```bash
   flutter run
   ```

---

## 📦 Building for Production

### Android APK (Release)
```bash
flutter build apk --release
```
The optimized APK output will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (AAB for Google Play Store)
```bash
flutter build appbundle --release
```
The bundle output will be located at:
`build/app/outputs/bundle/release/app-release.aab`

---

## 🔒 Security & Privacy Practices

- **Zero Hardcoded Secrets**: No sensitive API keys or credentials are stored in the client codebase.
- **Sanitized Version Control**: Local SDK properties (`local.properties`), keystores, and certificate files are strictly isolated via comprehensive `.gitignore` rules.
- **Client-Side Privacy**: Saved chats and settings are securely stored locally via encrypted device storage interfaces.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more details.

---

<div align="center">
  <sub>Built with ❤️ by <b>Samarjit Kashyap</b> and the Axom AI Community.</sub>
</div>
