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
//  PaywallWithDebugEntryView.swift
//  ExampleApp
//
//  Created by Robert Tataru on 29.01.2025.
//

import SwiftUI
import TADebugTools

struct PaywallWithDebugEntryView: View {
    @EnvironmentObject var debugToolConfiguration: MyDebugToolConfiguration
    
    @AppStorage("isPremium") var isPremium: Bool = UserDefaults.standard.bool(forKey: "isPremium")

    @State private var isDebugToolPresented = false
    @State private var debugToolUpdateCount = 0
    @State private var lastDebugToolValueDescription = "None"
    
    var body: some View {
        Form {
            Section("App State") {
                Toggle(isOn: $isPremium) {
                    Text("Is Premium")
                }

                LabeledContent("Persisted Value") {
                    Text(isPremium ? "true" : "false")
                }
            }

            Section("Debug Entry Callback") {
                LabeledContent("Callback Count") {
                    Text("\(debugToolUpdateCount)")
                }

                LabeledContent("Last Debug Value") {
                    Text(lastDebugToolValueDescription)
                }

                Button("Open Debug Tool") {
                    isDebugToolPresented = true
                }
                .buttonStyle(.borderedProminent)
            }

            Section("How To Reproduce") {
                Text("Open the debug tool, go to App Settings, then toggle `Is Premium`. The callback count and persisted value should update immediately.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Debug Entry Callback")
        .onAppear(perform: configureDebugEntry)
        .onChange(
            of: isPremium,
            perform: debugToolConfiguration.isPremiumEntry.onUpdateFromApp
        )
        .sheet(isPresented: $isDebugToolPresented) {
            TADebugToolView(configuration: debugToolConfiguration)
        }
    }

    private func configureDebugEntry() {
        debugToolConfiguration.isPremiumEntry.onUpdateFromDebugTool = { newValue in
            debugToolUpdateCount += 1
            lastDebugToolValueDescription = newValue ? "true" : "false"

            if isPremium != newValue {
                isPremium = newValue
            }
        }
    }
}
