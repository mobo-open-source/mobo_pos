# Mobo POS

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=for-the-badge)


Mobo POS is a professional mobile application designed to bring the power of Odoo Point of Sale to Android and iOS devices. Built with Flutter, it offers a high-performance, touch-optimized interface for retail and restaurant operations, allowing staff to process orders, manage sessions, and handle customers directly from their mobile phones or tablets.

##  Key Features

###  Modern POS Experience
- **Touch-Optimized WebView**: Integrated Odoo POS interface for a consistent and powerful user experience.
- **Session Control**: Open, resume, and manage POS sessions directly from the app.
- **Real-Time Sync**: Automatic synchronization with your Odoo backend for up-to-the-minute data.

###  Multi-Account & Multi-Company
- **Switch Account**: Quickly swap between multiple Odoo accounts and databases without re-entering credentials.
- **Multi-Company Support**: Seamlessly switch between different company profiles within the same instance.
- **Global Server Support**: Dynamically handle different Odoo server URLs.

###  Security & User Experience
- **Biometric Authentication**: Secure and fast login using fingerprint or Face ID.
- **Advanced UI/UX**: Modern design with dark mode support, smooth animations, and premium typography (YaroRg).
- **In-App Review**: Integrated system to gather user feedback and maintain quality.
- **Micro-Animations**: Shimmer effects and smooth transitions for a premium feel.

##  Screenshots

<div>
  <img src="images/screenshot1.png" width="200" style="margin:8px;" />
  <img src="images/screenshot2.png" width="200" style="margin:8px;" />
  <img src="images/screenshot3.png" width="200" style="margin:8px;" />
  <img src="images/screenshot4.png" width="200" style="margin:8px;" />
</div>

##  Technology Stack

Mobo POS is built using modern technologies to ensure reliability and performance:

- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Local Database**: Isar (High-performance NoSQL database for account caching)
- **Web Integration**: Flutter InAppWebView (Lag-free web-to-mobile bridge)
- **Backend API**: Odoo RPC
- **Authentication**: Local Auth (Biometrics)

##  Supported Odoo Versions

Tested and verified on:
- **Odoo version 14 - 19** (Community & Enterprise)

##  Getting Started

### Prerequisites
- Flutter SDK (^3.7.2)
- Odoo Instance (v14 or higher)
- Android Studio or VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/mobo-open-source/mobo_pos.git
   cd mobo_pos-main
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Isar schemas**
   Run the build runner to generate necessary database bindings:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

##  Usage

To get started with Mobo POS:

1. **Open the App**: Launch Mobo POS on your mobile device.
2. **Setup Server**: Enter your Odoo server URL and select your database.
3. **Login**: Enter your Odoo credentials.
4. **Select POS**: Choose the POS configuration you want to manage.
5. **Start Selling**: Process orders and manage your retail/restaurant operations.

##  Maintainers

**Team Mobo at Cybrosys Technologies**
-  [mobo@cybrosys.com](mailto:mobo@cybrosys.com)

## License

This project is primarily licensed under the Apache License 2.0.
It also includes third-party components licensed under:
- MIT License
- GNU Lesser General Public License (LGPL)

See the [LICENSE](LICENSE) file for the main license and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for details on included dependencies and their respective licenses.
