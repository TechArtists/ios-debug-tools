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
//  DebugEntryTextFieldAlertButton.swift
//  TADebugTools
//
//  Created by Robert Tataru on 13.02.2025.
//

import SwiftUI

public class DebugEntryTextFieldAlertButton: DebugEntryConfirmableProtocol, ObservableObject {
    public typealias Value = String

    weak public var taDebugToolConfiguration: TADebugToolConfiguration?
    
    public var id: UUID
    public var title: String
    public var wrappedValue: String
    public var labels: [DebugToolLabel]
    
    public lazy var stream: AsyncStream<String> = { [weak self] in
        AsyncStream { continuation in
            self?.continuation = continuation
        }
    }()
    public var continuation: AsyncStream<String>.Continuation?
    
    public var onUpdateFromDebugTool: ((String) -> Void)?
    public var onUpdateFromApp: ((String) -> Void) = { _ in }
    
    public var onConfirm: (String) -> Void
    
    public var storage: AnyStorage<String>?

    public init(
        title: String, wrappedValue: String = "", storage: AnyStorage<String>? = nil, labels: [DebugToolLabel] = [], onConfirm: @escaping (String) -> Void,
        taDebugToolConfiguration: TADebugToolConfiguration? = nil, id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        self.wrappedValue = wrappedValue
        self.storage = storage
        self.labels = labels
        self.onConfirm = onConfirm
        self.taDebugToolConfiguration = taDebugToolConfiguration
    }
    
    @MainActor
    public var renderView: AnyView {
        AnyView(DebugEntryTextInputButtonView(debugEntry: self))
    }
}
