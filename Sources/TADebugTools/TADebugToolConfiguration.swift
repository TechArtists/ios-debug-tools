/*
MIT License

Copyright (c) 2025 Tech Artists Agency

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

//
//  TADebugToolConfiguration.swift
//  TADebugTools
//
//  Created by Robert Tataru on 13.01.2025.
//

import SwiftUI

open class TADebugToolConfiguration: ObservableObject {
    
    @Published private(set) var sections: [DebugToolSection: [String: any DebugEntryProtocol]] = [:]
    
    let password: String?
    
    public init(password: String? = nil) {
        self.password = password
        self.sections = [
            DebugToolSection.app: [:],
            DebugToolSection.appSettings: appSettingEntries,
            DebugToolSection.onboarding: [:],
            DebugToolSection.logs: [:],
            DebugToolSection.defaults: defaultsEntries,
            DebugToolSection.others: [:]
        ]
        UserDefaults.standard.setValue(false, forKey: DefaultsConstants.hasEnteredCorrectPassword)
    }
    
    public func addEntry(
        _ entry: any DebugEntryProtocol,
        to section: DebugToolSection
    ) {
        sections[section]?[entry.title] = entry
        entry.taDebugToolConfiguration = self
    }
    
    public func getEntry(_ title: String, in section: DebugToolSection) -> (any DebugEntryProtocol)? {
        sections[section]?[title]
    }

    private var defaultsEntries: [String: any DebugEntryProtocol] {
        [
            "Show Defaults":  DebugEntryButton(
                title: "Show Defaults",
                wrappedValue: (),
                onTapShowDestinationView: AnyView(
                    TADebugDictionaryView(dictionary: UserDefaults.standard.dictionaryRepresentation().compactMapValues { "\($0)" })
                )
            ),
            "Multiple Options": DebugEntryOptions(
                title: "Multiple Options",
                wrappedValue: "Option 1",
                possibleValues: ["Option 1", "Option 2", "Option 3"]
            )
        ]
    }
    
    private var appSettingEntries: [String: any DebugEntryProtocol] {
        [
            "Open App Settings": DebugEntryButton(
                title: "Open App Settings",
                wrappedValue: (),
                onTapGesture: {
                    Task { @MainActor in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            }
                        }
                    }
                }
            ),
            "App Short Version": DebugEntryConstant(
                title: "App Short Version",
                wrappedValue: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            ),
            "App Long Version": DebugEntryConstant(
                title: "App Long Version",
                wrappedValue: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            )
        ]
    }
    
    private func getAllUserDefaults() -> [String] {
        let defaultsDict = UserDefaults.standard.dictionaryRepresentation()
        
        let sortedDefaults = defaultsDict
            .sorted { $0.key < $1.key }
        
        return sortedDefaults.map { "key: \($0.key) value: \($0.value)" }
    }
}
