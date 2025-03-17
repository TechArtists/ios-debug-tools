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
//  TADevToolView.swift
//  TADebugTools
//
//  Created by Robert Tataru on 09.12.2024.
//

import SwiftUI

//
//  TADebugToolView.swift
//  TADebugTools
//
//  Created by Robert Tataru on 09.12.2024.
//

import SwiftUI

public struct TADebugToolView: View {
    
    @StateObject public var configuration: TADebugToolConfiguration
    @FocusState private var isFocused: Bool
    @State private var ipAddress: String?
    @State private var passwordInput = ""
    
    public init(
        configuration: TADebugToolConfiguration = TADebugToolConfiguration()
    ) {
        self._configuration = StateObject(wrappedValue: configuration)
        accessUserDefaultsForAllGroups()
    }
    
    public var body: some View {
        if shouldShowPasswordInput {
            TADebugPasswordView(
                passwordInput: $passwordInput,
                isFocused: _isFocused,
                keyboardType: keyBoardType()
            )
        } else {
            TADebugToolSectionsView(configuration: configuration, ipAddress: ipAddress)
        }
    }
}

// MARK: - Password Handling
extension TADebugToolView {
    private var shouldShowPasswordInput: Bool {
        let hasEnteredCorrectPassword = UserDefaults.standard.bool(forKey: DefaultsConstants.hasEnteredCorrectPassword)
        
        if hasEnteredCorrectPassword {
            return false
        }
        
        guard let password = configuration.password else { return false }
        let isPasswordCorrect = (password == passwordInput)
        
        if isPasswordCorrect {
            UserDefaults.standard.setValue(true, forKey: DefaultsConstants.hasEnteredCorrectPassword)
        }
        
        return !isPasswordCorrect
    }
    
    private func keyBoardType() -> UIKeyboardType {
        (configuration.password?.isNumeric ?? false) ? .numberPad : .default
    }
}

// MARK: - App Groups Handling
extension TADebugToolView {
    private func fetchAppGroups() -> [String] {
        Bundle.main.infoDictionary?["com.apple.security.application-groups"] as? [String] ?? []
    }
    
    private func accessUserDefaultsForAllGroups() {
        fetchAppGroups().forEach { group in
            if let userDefaults = UserDefaults(suiteName: group) {
                print("Data for group \(group): \(userDefaults.dictionaryRepresentation())")
            } else {
                print("No data found for group \(group)")
            }
        }
    }
}

// MARK: - Password Input View
private struct TADebugPasswordView: View {
    @Binding var passwordInput: String
    @FocusState var isFocused: Bool
    let keyboardType: UIKeyboardType

    var body: some View {
        VStack {
            TextField("Password", text: $passwordInput)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .padding()
                .focused($isFocused)
                .onAppear { isFocused = true }
                .keyboardType(keyboardType)
            
            Spacer()
        }
    }
}

// MARK: - Sections View
private struct TADebugToolSectionsView: View {
    let configuration: TADebugToolConfiguration
    let ipAddress: String?

    var body: some View {
        NavigationView {
            List {
                sectionList
            }
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private var sectionList: some View {
        ForEach(sortedSections, id: \.key) { section, entries in
            if !entries.isEmpty {
                Section(header: Text(section.title)) {
                    entryList(for: entries)
                }
            }
        }
    }
    
    private var sortedSections: [(key: DebugToolSection, values: [any DebugEntryProtocol])] {
        configuration
            .sections
            .sorted { $0.key.title < $1.key.title }
            .map { section in
                let sortedEntries = Array(section.value.values)
                    .sorted { $0.title < $1.title }
                return (key: section.key, values: sortedEntries)
            }
    }
    
    @ViewBuilder
    private func entryList(for entries: [any DebugEntryProtocol]) -> some View {
        ForEach(entries, id: \.id) { entry in
            entry.renderView
        }
    }
}
