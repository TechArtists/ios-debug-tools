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
//  PresentDebugView.swift
//  ExampleApp
//
//  Created by Robert Tataru on 27.01.2025.
//

import SwiftUI
import TADebugTools

struct PresentDebugView: View {
    @EnvironmentObject var debugToolConfiguration: MyDebugToolConfiguration

    @State private var presentDevToolView = false
    @State private var logCounter = 0
    @State private var analyticsCounter = 0
    @State private var ctaTapCount = 0
    @State private var lastTappedCTA = "None"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Embedded Debug Menu")
                        .font(.largeTitle.bold())

                    Text("This screen demonstrates the intended flow for the floating launcher. The password is enforced only when you enter the main debug tool.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Try it")
                        .font(.title3.weight(.semibold))

                    stepRow(number: 1, text: "Open the main debug tool.")
                    stepRow(number: 2, text: "Enter password `123`.")
                    stepRow(number: 3, text: "In App Settings, enable `Enable Embedded Debug Launcher`.")
                    stepRow(number: 4, text: "Dismiss the tool and tap the floating ladybug.")
                    stepRow(number: 5, text: "Use the Live tab while triggering the sample events below.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Launcher Status")
                        .font(.title3.weight(.semibold))

                    Label(
                        debugToolConfiguration.isEmbeddedDebugLauncherEnabled ? "Embedded launcher is enabled" : "Embedded launcher is disabled",
                        systemImage: debugToolConfiguration.isEmbeddedDebugLauncherEnabled ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(debugToolConfiguration.isEmbeddedDebugLauncherEnabled ? .green : .orange)

                    Text("Production usage should enable this from the main debug tool. The button below is only here so the example is immediately visible.")
                        .foregroundStyle(.secondary)

                    HStack {
                        Button(debugToolConfiguration.isEmbeddedDebugLauncherEnabled ? "Disable Launcher" : "Enable Launcher") {
                            setEmbeddedLauncherEnabled(!debugToolConfiguration.isEmbeddedDebugLauncherEnabled)
                        }
                        .buttonStyle(.bordered)

                        Button("Open Main Debug Tool") {
                            presentDevToolView = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Live Feed Controls")
                        .font(.title3.weight(.semibold))

                    Text("These buttons publish sample log lines and analytics events. The example also emits background traffic every few seconds, so the Live tab keeps moving while the sheet is open.")
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Emit Log") {
                            logCounter += 1
                            ExampleDebugMenuLiveFeed.emitLog(
                                "Checkout screen rendered",
                                metadataText: "sample-log-\(logCounter)"
                            )
                        }

                        Button("Emit Analytics") {
                            analyticsCounter += 1
                            ExampleDebugMenuLiveFeed.emitAnalytics(
                                "purchase_cta_tapped",
                                metadataText: "count=\(analyticsCounter)"
                            )
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Emit Mixed Traffic") {
                        logCounter += 1
                        analyticsCounter += 1

                        ExampleDebugMenuLiveFeed.emitLog(
                            "Remote config refreshed",
                            metadataText: "revision=\(logCounter)"
                        )
                        ExampleDebugMenuLiveFeed.emitAnalytics(
                            "paywall_presented",
                            metadataText: "variant=B count=\(analyticsCounter)"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Sample Content")
                        .font(.title3.weight(.semibold))

                    Text("Use the overlay sheet toolbar menu, `Position`, to move the collapsed launcher to another corner.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last tapped CTA: \(lastTappedCTA)")
                            .font(.subheadline.weight(.semibold))
                        Text("Total CTA taps: \(ctaTapCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        tappableCard(title: "Top Left CTA", subtitle: "Sample action")
                        tappableCard(title: "Top Right CTA", subtitle: "Sample action")
                        tappableCard(title: "Bottom Left CTA", subtitle: "Sample action")
                        tappableCard(title: "Bottom Right CTA", subtitle: "Sample action")
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Debug Menu Demo")
        .sheet(isPresented: $presentDevToolView) {
            TADebugToolView(configuration: debugToolConfiguration)
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue, in: Circle())

            Text(.init(text))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tappableCard(title: String, subtitle: String) -> some View {
        Button {
            handleCTATap(title: title, subtitle: subtitle)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func setEmbeddedLauncherEnabled(_ isEnabled: Bool) {
        debugToolConfiguration.embeddedDebugLauncherEnabledEntry.onUpdateFromApp(isEnabled)
        debugToolConfiguration.embeddedDebugLauncherEnabledEntry.onUpdateFromDebugTool?(isEnabled)
    }

    private func handleCTATap(title: String, subtitle: String) {
        ctaTapCount += 1
        lastTappedCTA = title

        ExampleDebugMenuLiveFeed.emitLog(
            "\(title) tapped",
            metadataText: subtitle
        )
    }
}
