
<div align="center">

# Skysync  

A modern, self‑hosted, configurable and privacy‑focused Flutter application for file syncing.

![License](https://img.shields.io/badge/License-MIT-green)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Platform](https://img.shields.io/badge/Platforms-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Android%20%7C%20iOS-lightgrey)
![Status](https://img.shields.io/badge/Build-Passing-brightgreen)
![Contributions](https://img.shields.io/badge/Contributions-Welcome-orange)

</div>

---

## 📑 Table of Contents

- [✨ Features](#-features)
- [🏗 Architecture](#-architecture)
- [🚀 Getting Started](#-getting-started)
- [⚙️ Environment & Configuration](#️-environment--configuration)
- [🛠 Build & Run](#-build--run)
- [🧪 Testing](#-testing)
- [📝 Code TODOs](#-code-todos)
- [🤝 Contributing](#-contributing)
- [📜 License](#-license)

---

## ✨ Features

- 🔐 Authentication (login, register, verify)
- 📄 File listing & folder browsing
- 📤 File upload + folder creation
- 📥 Folder download as bundled archive
- ⭐ Favorites system  
- 🖥 Cross‑platform support (Windows, macOS, Linux, mobile)
- 🔌 Backend‑agnostic (URL + API key configurable)

---

## 🏗 Architecture

Skysync uses a modular and simple architecture:

```

lib/
 ┣ pages/          → UI screens  
 ┣ services/       → ApiService, AuthService  
 ┣ models/         → Data models  
 ┣ widgets/        → Reusable UI components  
 ┗ config.dart     → Centralized configuration (baseUrl, apiKey)
```

- `ApiService` handles all HTTP communication  
- `AuthService` handles authentication + secure storage  
- `config.dart` controls runtime configuration values  

---

## 🚀 Getting Started

### **Prerequisites**

- Flutter SDK (stable channel)
- A running **Skysync-compatible backend**

### **Quick Start**

1. Install dependencies  

```bash
flutter pub get
```

2. Run the app  

```bash
flutter run -d windows
```

3. (Optional) Create `.env` if your setup uses environment files.

---

## ⚙️ Environment & Configuration

The app reads configuration from `lib/config.dart`.

Typical values:

| Key | Description |
|-----|-------------|
| `Config.baseUrl` | Backend API base URL |
| `Config.apiKey`  | API key for backend authentication |

Optional `.env` keys if supported:

- `BASE_URL`
- `API_KEY`

---

## 🛠 Build & Run

### Desktop

```bash
flutter run -d windows
flutter run -d linux
flutter run -d macos
```

### Mobile

```bash
flutter run -d <device-id>
```

### Release

```bash
flutter build windows
flutter build apk
flutter build linux
```

---

## 🧪 Testing

```bash
flutter test
```

---

## 📝 Code TODOs

### `lib/main.dart`

- TODO: Add splash screen & deep-link handling  
- TODO: Centralize token expiry logic  
- TODO: Add localization (i18n)

### `lib/services/api_service.dart`

- TODO: Error mapping + retry/backoff system  
- TODO: Token refresh workflow  
- TODO: Replace generic `Map<String, dynamic>` with typed models  
- TODO: Add timeouts & structured logging  

### `lib/services/auth_service.dart`

- TODO: Token expiry parsing + proactive refresh  
- TODO: Secure/Encrypted platform-specific storage  
- TODO: Server-side logout invalidation  

---

## 🤝 Contributing

We welcome contributions!  
Open an issue or submit a PR following the coding style and including tests when possible.

---

## 📜 License

This project is licensed under the **MIT License**.  
See the `LICENSE` file for details.