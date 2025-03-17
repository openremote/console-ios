# OpenRemote Generic iOS App

This is the OpenRemote Generic iOS App that uses the ORLib Swift Package.

## Setup and Installation

### Requirements

- iOS 14.0+
- Swift 5.0+
- Xcode 12.0+

### Dependencies

This project uses Swift Package Manager for all dependencies:

- **ORLib**: Core OpenRemote library
- **Firebase**: Messaging, Crashlytics, Analytics
- **IQKeyboardManagerSwift**: For keyboard management
- **DropDown**: For dropdown menus

### Getting Started

1. Clone the repository
2. Open the `GenericApp.xcodeproj` file in Xcode
3. Build and run the project

## App Flow

### WizardDomainViewController
- User enters URL or domain
  - If only domain is entered, URL becomes https://<domain>.openremote.app
  - GET <base URL>/api/master/apps/consoleConfig
    - See https://github.com/openremote/openremote/issues/642
    - If 404, use defaults
    - If 200, read info:
      - showAppTextInput: Boolean (default false)
      - showRealmTextInput: Boolean (default false)
      - app: String? (default nil)
      - allowedApps: List<String>? (default nil/empty)
      - apps: Map<String, ORAppInfo>? (default nil/empty)
    - If allowedApps empty -> GET <base URL>/api/master/apps
      - If 200, e.g. ["console_loader","manager"]

### Configuration
The app collects the following information:
- URL
- app
- realm
- name (optional)

This configuration is passed between wizard screens and stored for future use.

## Additional Resources

- App info endpoint: https://test1.openremote.app/<app>/info.json
