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
//  PaywalSingleSourceTruth.swift
//  TADebugTools
//
//  Created by Robert Tataru on 20.03.2025.
//

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
