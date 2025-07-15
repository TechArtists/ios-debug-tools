
# TADebugTools

**TADebugTools** is a lightweight, modular in-app debugging toolkit for SwiftUI applications. It allows developers to view, edit, and trigger debugging entries directly from within the app.

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

You can either **sync entries with external source of truth** (like `@AppStorage`) or **manage the source of truth from the configuration itself**.

#### Option A: External Source of Truth

```swift
import SwiftUI
import TADebugTools

public class MyDebugToolConfiguration: TADebugToolConfiguration {
    
    let isPremiumEntry: DebugEntryBool = .init(
        title: "Is Premium",
        wrappedValue: UserDefaults.standard.bool(forKey: "isPremium")
    )
    
    override public init(passwordType: TADebugToolConfiguration.PasswordType = .static(password: "")) {
        super.init(passwordType: passwordType)
        addEntriesToSections()
    }
}
```

```swift
struct PaywallWithDebugEntryView: View {
    @EnvironmentObject var debugToolConfiguration: MyDebugToolConfiguration
    @AppStorage("isPremium") var isPremium: Bool = UserDefaults.standard.bool(forKey: "isPremium")
    
    var body: some View {
        VStack {
            Toggle(isOn: $isPremium) {
                Text("Is Premium")
            }
            .onAppear {
                debugToolConfiguration.isPremiumEntry.onUpdateFromDebugTool = { newValue in
                    if self.isPremium != newValue {
                        self.isPremium = newValue
                    }
                }
            }
            .onChange(of: isPremium, perform: debugToolConfiguration.isPremiumEntry.onUpdateFromApp)
        }
        .padding()
    }
}
```

#### Option B: Configuration is the Source of Truth

```swift
import SwiftUI
import TADebugTools

enum ServiceEnvironment: String, CaseIterable {
    case production
    case staging
}

public class MyDebugToolConfiguration2: TADebugToolConfiguration {
    
    @Debuggable(key: "isDebuggableWorking")
    var isDebuggableWorking = false
    
    @Debuggable(title: "Test Action") var actionPrint = {
        print("Action works")
    }
    
    @Debuggable(title: "Async Action") var asyncActionPrint = {
        Task {
            try await Task.sleep(for: .seconds(1))
            print("Async Action works")
        }
    }
    
    @Debuggable(key: "testConstant", section: .defaults)
    var testConstant: String = "Hello World"
    
    @Debuggable(key: "testTextField", textType: .textField)
    var testTextField: String = "Hello World"
    
    @Debuggable(key: "environment")
    var environment: ServiceEnvironment = .staging

}
```

```swift
struct PaywalSingleSourceTruth: View {
    @StateObject var debugToolConfiguration: MyDebugToolConfiguration2 = .init()
    @State var presentDevToolView: Bool = false
    
    var body: some View {
        VStack {
            Toggle(isOn: debugToolConfiguration.$isDebuggableWorking) {
                Text("Is Debugable Working")
            }
            
            Button("Present Dev Tool") {
                presentDevToolView = true
            }
            .popover(isPresented: $presentDevToolView) {
                TADebugToolView(configuration: debugToolConfiguration)
            }
        }
        .padding()
    }
}
```

---

## UI Presentation

You can present the debug UI using a gesture or simple button:

```swift
import SwiftUI

struct PresentDebugView: View {
    @EnvironmentObject var debugToolConfiguration: MyDebugToolConfiguration
    @State var presentDevToolView: Bool = false
    
    var body: some View {
        Button("Present Dev Tool") {
            presentDevToolView = true
        }
        .popover(isPresented: $presentDevToolView) {
            TADebugToolView(configuration: debugToolConfiguration)
        }
    }
}
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
