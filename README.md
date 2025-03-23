# TADebugTools

**TADebugTools** is a lightweight, modular in-app debugging toolkit for SwiftUI applications. It allows developers to view, edit, and trigger debugging entries directly from within the app, with support for dynamic values, user defaults, and custom actions.

---

## Features

- 🔐 **Optional Password Protection**: Lock access to the debug tool with a password.
- 🧩 **Custom Debug Entries**: Easily add toggles, buttons, text fields, constants, and more.
- 🗂️ **Sectioned UI**: Organize your debugging entries by category.
- 🧪 **Property Wrapper Support**: Quickly bind debug state to your app’s logic.

---

## Installation

### Swift Package Manager

To include **TADebugTools** in your project, add it to your `Package.swift` file:

```swift
let package = Package(
    name: "YourProject",
    platforms: [
        .iOS(.v14)
    ],
    dependencies: [
        .package(
            url: "git@github.com:TechArtists/ios-debug-tools.git",
            from: "0.9.0"
        )
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                .product(name: "TADebugTools", package: "TADebugTools")
            ]
        )
    ]
)
```

Or add it via Xcode:

- Go to **File > Add Packages**.
- Enter the repo URL: `git@github.com:YourRepo/TADebugTools.git`.
- Add it to your target.

---

## Usage

### 1. Create a Custom Configuration

Subclass `TADebugToolConfiguration` and register your debug entries:

```swift
import TADebugTools

class MyDebugToolConfiguration: TADebugToolConfiguration {
    let isPremiumEntry = DebugEntryBool(
        title: "Is Premium",
        wrappedValue: UserDefaults.standard.bool(forKey: "isPremium")
    )

    override init(password: String? = nil) {
        super.init(password: password)
        addEntry(isPremiumEntry, to: .app)
    }
}
```

### 2. Present the Debug Tool UI

You can show the debug UI using a button or gesture:

```swift
import TADebugTools

struct DebugToolButton: View {
    @EnvironmentObject var debugToolConfiguration: MyDebugToolConfiguration
    @State private var isPresented = false

    var body: some View {
        Button("Open Debug Tool") {
            isPresented = true
        }
        .popover(isPresented: $isPresented) {
            TADebugToolView(configuration: debugToolConfiguration)
        }
    }
}
```

### 3. Bind Debuggable Properties

Use `@Debuggable` for seamless integration between debug state and app logic:

```swift
class MyDebugToolConfiguration2: TADebugToolConfiguration {
    @Debuggable(key: "isDebuggableWorking")
    var isDebuggableWorking = false

    @Debuggable(title: "Print Action")
    var printAction = {
        print("Action triggered")
    }
}
```

```swift
Toggle("Debug Mode", isOn: debugToolConfiguration.$isDebuggableWorking)
```

---

## Sections

Available predefined sections:

- `.app`: General app controls
- `.appSettings`: System-level app settings
- `.onboarding`: Onboarding-specific controls
- `.logs`: Logs and debugging output
- `.defaults`: UserDefaults display and manipulation
- `.others`: Miscellaneous tools and entries

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.
