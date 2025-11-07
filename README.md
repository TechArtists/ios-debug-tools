# TADebugTools

**TADebugTools** is a lightweight, modular in-app debugging toolkit for SwiftUI applications. It allows developers to view, edit, and trigger debugging entries directly from within the app.

---

## Features

- 🔐 **Flexible Password Protection**: Multiple authentication strategies for different environments
- 🧩 **Custom Debug Entries**: Easily add toggles, buttons, text fields, constants, and more
- 🗂️ **Sectioned UI**: Organize your debugging entries by category
- 🧪 **Property Wrapper Support**: Quickly bind debug state to your app's logic
- 🔄 **Bidirectional State Sync**: Keep debug entries in sync with your app's state
- 📊 **Advanced Logging**: Built-in log viewers, file sharing, and management
- 🎯 **Production-Ready**: Environment-specific configurations and hidden access patterns

---

## Installation

### Swift Package Manager

To include **TADebugTools** in your project, add it to your `Package.swift` file:

\`\`\`swift
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
\`\`\`

Or add it via Xcode:

- Go to **File > Add Packages**.
- Enter the repo URL: `git@github.com:YourRepo/TADebugTools.git`.
- Add it to your target.

---

## Quick Start

### 1. Create a Custom Configuration

You can either **sync entries with external source of truth** (like `@AppStorage`) or **manage the source of truth from the configuration itself**.

#### Option A: External Source of Truth

\`\`\`swift
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
\`\`\`

\`\`\`swift
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
\`\`\`

#### Option B: Configuration is the Source of Truth

\`\`\`swift
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
\`\`\`

\`\`\`swift
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
\`\`\`

### 2. Present the Debug UI

\`\`\`swift
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
\`\`\`

---

## Real-World Integration

### Production-Ready Configuration

For production applications, you'll want a more sophisticated setup that handles different environments, secure access, and comprehensive debugging features:

\`\`\`swift
import SwiftUI
import TADebugTools
import Defaults // Using Defaults library for type-safe UserDefaults

public class AppDebugToolConfiguration: TADebugToolConfiguration {
    
    // Environment-aware password strategy
    static var passwordStrategy: PasswordStrategy {
        #if DEBUG
            return DebugPasswordStrategy()
        #elseif TESTFLIGHT
            return TestflightPasswordStrategy()
        #else
            return ProductionPasswordStrategy()
        #endif
    }
    
    // App state entries with bidirectional sync
    let isPremiumEntry: DebugEntryBool = .init(
        title: "Is Premium",
        wrappedValue: Defaults[.isPremium]
    )
    
    let hasCompletedOnboardingEntry: DebugEntryBool = .init(
        title: "Has Completed Onboarding", 
        wrappedValue: Defaults[.onboardingCompleted]
    )

    
    public override init(passwordType: TADebugToolConfiguration.PasswordType) {
        super.init(passwordType: passwordType)
        
        setupEntries()
        setupStateSync()
    }
    
    private func setupEntries() {
        // App state section
        addEntry(isPremiumEntry, to: .app)
        addEntry(hasCompletedOnboardingEntry, to: .app)
    }
    
    private func setupStateSync() {
        // Bidirectional sync for premium status
        isPremiumEntry.onUpdateFromDebugTool = { newValue in
            Defaults[.isPremium] = newValue
        }
        
        Task {
            for await newIsPremium in Defaults.updates(.isPremium) {
                await MainActor.run {
                    self.isPremiumEntry.onUpdateFromApp(newIsPremium)
                }
            }
        }
        
        // Bidirectional sync for onboarding status
        hasCompletedOnboardingEntry.onUpdateFromDebugTool = { newValue in
            Defaults[.onboardingCompleted] = newValue
        }
        
        Task {
            for await newOnboardingStatus in Defaults.updates(.onboardingCompleted) {
                await MainActor.run {
                    self.hasCompletedOnboardingEntry.onUpdateFromApp(newOnboardingStatus)
                }
            }
        }
    }
}
\`\`\`

### App Integration Pattern

#### 1. Initialize in AppDelegate

\`\`\`swift
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // Initialize debug configuration early
    let debugConfig = AppDebugToolConfiguration(
        passwordType: .dynamic(strategy: AppDebugToolConfiguration.passwordStrategy)
    )
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // ... other setup code ...
        
        // Configure additional debug entries after services are initialized
        setupDebugEntries()
        
        return true
    }
    
    private func setupDebugEntries() {
        // Add entries that require initialized services
        debugConfig.addFirebaseEntries()
        debugConfig.addOnboardingEntries()
    }
}
\`\`\`

#### 2. Dependency Injection Pattern

\`\`\`swift
final class SettingsViewController: UIViewController {
    private let debugConfig: AppDebugToolConfiguration
    
    init(debugConfig: AppDebugToolConfiguration) {
        self.debugConfig = debugConfig
        super.init(nibName: nil, bundle: nil)
    }
    
    // ... rest of implementation ...
}
\`\`\`

---

## Password Strategies & Security

### Built-in Strategies

TADebugTools provides several password strategies for different security needs:

\`\`\`swift
// No password required (development)
.none

// Static password
.static(password: "mypassword")

// Dynamic password using custom strategy
.dynamic(strategy: MyCustomPasswordStrategy())
\`\`\`

### Custom Password Strategies

Create custom password strategies for advanced security:

\`\`\`swift
import TADebugTools
import UIKit

/// Always allows access (for debug/TestFlight builds)
struct AlwaysTruePasswordStrategy: PasswordStrategy {
    func isPasswordValid(_ input: String) -> Bool {
        return true
    }
    
    var keyboardType: UIKeyboardType {
        return .numberPad
    }
}
\`\`\`

## State Management & Synchronization

### Bidirectional Sync with Existing State

For apps with existing state management systems, TADebugTools provides seamless synchronization:

\`\`\`swift
isPremiumEntry.onUpdateFromDebugTool = { newValue in
    Defaults[.isPremium] = newValue
}

Task {
    for await newIsPremium in Defaults.updates(.isPremium) {
        await MainActor.run {
            self.isPremiumEntry.onUpdateFromApp(newIsPremium)
        }
    }
}
\`\`\`

### State Management Patterns

#### Pattern 1: External Source of Truth
Best for apps with established state management systems.

\`\`\`swift
// Debug tool syncs with your existing state system
let premiumEntry: DebugEntryBool = .init(
    title: "Is Premium",
    wrappedValue: MyStateManager.shared.isPremium
)

// Setup bidirectional sync
premiumEntry.onUpdateFromDebugTool = { newValue in
    MyStateManager.shared.setPremium(newValue)
}

MyStateManager.shared.onPremiumChanged = { newValue in
    premiumEntry.onUpdateFromApp(newValue)
}
\`\`\`

#### Pattern 2: Debug Tool as Source of Truth
Best for simple debugging scenarios.

\`\`\`swift
@Debuggable(key: "isPremium")
var isPremium = false

// Use directly in your views
Toggle(isOn: debugConfig.$isPremium) {
    Text("Premium Status")
}
\`\`\`

---

## Available Sections

Organize your debug entries using these predefined sections:

- `.app`: General app controls and state
- `.appSettings`: System-level app settings
- `.onboarding`: Onboarding-specific controls
- `.logs`: Logs and debugging output
- `.defaults`: UserDefaults display and manipulation
- `.others`: Miscellaneous tools and entries

---

## Entry Types

### Available Entry Types

- **DebugEntryBool**: Toggle switches for boolean values
- **DebugEntryButton**: Action buttons that execute code
- **DebugEntryConstant**: Read-only display of values
- **DebugEntryTextField**: Text input fields
- **DebugEntryTextFieldAlertButton**: Buttons that show text input dialogs
- **DebugEntryOptions**: Dropdown selection for enum values

### Custom Entry Creation

\`\`\`swift
// Boolean toggle with custom behavior
let customToggle = DebugEntryBool(
    title: "Custom Feature",
    wrappedValue: false
) { newValue in
    // Custom logic when value changes
    FeatureManager.shared.setCustomFeature(enabled: newValue)
}

// Button with navigation
let navigationButton = DebugEntryButton(
    title: "Advanced Settings",
    wrappedValue: {},
    onTapShowDestinationView: { 
        AnyView(AdvancedDebugSettingsView()) 
    }
)
\`\`\`

---

## Best Practices

### Security Considerations

1. **Use environment-specific password strategies** to ensure production security
2. **Hide debug access behind subtle UI patterns** (tap counters, gestures)
3. **Disable debug tools in production builds** when not needed
4. **Use secure password strategies** that change over time

### Performance

1. **Initialize debug configuration early** in app lifecycle
2. **Use lazy initialization** for expensive debug entries
3. **Avoid heavy operations** in debug entry callbacks
4. **Clean up resources** when debug tools are dismissed

### User Experience

1. **Organize entries logically** using sections
2. **Use clear, descriptive titles** for all entries
3. **Provide immediate feedback** for debug actions
4. **Test debug flows** regularly during development

---

## Troubleshooting

### Common Issues

**Debug tool not appearing:**
- Check if password strategy is correctly configured
- Verify initialization order in AppDelegate
- Ensure debug configuration is passed to presentation layer

**State sync not working:**
- Verify bidirectional sync callbacks are set up
- Check if state updates are happening on main thread
- Ensure proper memory management (avoid retain cycles)

**Performance issues:**
- Move expensive operations out of entry initialization
- Use lazy loading for debug entries that access files/network
- Implement proper cleanup in deinitializers

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.
