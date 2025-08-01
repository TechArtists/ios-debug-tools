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
//  ExampleAppApp.swift
//  ExampleApp
//
//  Created by Robert Tataru on 09.12.2024.
//

import SwiftUI
import TADebugTools

@main
struct ExampleAppApp: App {
    @StateObject var debugToolConfiguration: MyDebugToolConfiguration = .init(passwordType: .static(password: "123"))

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                VStack(spacing: 20) {
                    NavigationLink {
                        PresentDebugView()
                    } label: {
                        Text("Vanilla View")
                            .font(.title3)
                    }
                    
                    NavigationLink {
                        PaywallView()
                    } label: {
                        Text("PaywallView")
                            .font(.title3)
                    }
                    
                    NavigationLink {
                        PaywallWithDebugEntryView()
                    } label: {
                        Text("PaywallWithDebugEntryView")
                            .font(.title3)
                    }
                    
                    NavigationLink {
                        PaywalSingleSourceTruth()
                    } label: {
                        Text("PaywalSingleSourceTruth")
                            .font(.title3)
                    }
                }
            }
            .environmentObject(debugToolConfiguration)
        }
    }
}
