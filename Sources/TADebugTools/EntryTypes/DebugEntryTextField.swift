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
//  DebugEntryTextField.swift
//  TADebugTools
//
//  Created by Robert Tataru on 09.12.2024.
//

import SwiftUI

public class DebugEntryTextField: DebugEntryProtocol {

    weak public var taDebugToolConfiguration: TADebugToolConfiguration?
    
    public var id: UUID
    
    public var title: String
    
    @Published
    public var wrappedValue: String  {
        didSet {
            isInitialized = true
            if let taDebugToolConfiguration, wrappedValue != oldValue {
                id = UUID()
                taDebugToolConfiguration.objectWillChange.send()
            }
        }
    }
    
    public var labels: [DebugToolLabel] = []
    
    public lazy var stream: AsyncStream<Value> = { [weak self] in
        AsyncStream { continuation in
            self?.continuation = continuation
        }
    }()
    
    public var continuation: AsyncStream<Value>.Continuation?

    @MainActor
    public var renderView: AnyView {
        AnyView(DebugEntryTextFieldView(debugEntry: self))
    }
    
    public var onUpdateFromDebugTool: ((String) -> Void)?
    
    public var onUpdateFromApp: ((String) -> Void) = { _ in }
    
    public var isInitialized: Bool = false
    
    public init(
        title: String,
        wrappedValue: String?,
        labels: [DebugToolLabel] = [],
        taDebugToolConfiguration: TADebugToolConfiguration? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        if let wrappedValue {
            self.wrappedValue = wrappedValue
            isInitialized = true
        } else {
            self.wrappedValue = ""
        }
        self.labels = labels
        self.taDebugToolConfiguration = taDebugToolConfiguration
        self.onUpdateFromApp = { [weak self] newValue in
            guard let self else { return }
            if newValue != self.wrappedValue {
                self.wrappedValue = newValue
            }
        }
    }
}

public struct DebugEntryTextFieldView: View {
    
    @ObservedObject var debugEntry: DebugEntryTextField
    
    public var body: some View {
        TextField(debugEntry.title, text: $debugEntry.wrappedValue)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .disabled(!debugEntry.isInitialized)
    }
}
