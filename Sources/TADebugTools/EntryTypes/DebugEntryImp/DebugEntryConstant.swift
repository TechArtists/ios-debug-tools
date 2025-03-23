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
//  DebugEntryConstant.swift
//  TADebugTools
//
//  Created by Robert Tataru on 09.12.2024.
//

import SwiftUI

public class DebugEntryConstant<T: Sendable>: DebugEntryProtocol {

    weak public var taDebugToolConfiguration: TADebugToolConfiguration?
    
    public var id: UUID
    public var title: String
    @Published
    public var wrappedValue: T
    public var labels: [DebugToolLabel]
    
    public lazy var stream: AsyncStream<Value> = { [weak self] in
        AsyncStream { continuation in
            self?.continuation = continuation
        }
    }()
    public var continuation: AsyncStream<T>.Continuation?
    
    @MainActor
    public var renderView: AnyView {
        AnyView(DebugEntryConstantView(debugEntry: self))
    }
    
    public var onUpdateFromDebugTool: ((T) -> Void)?
    
    public var onUpdateFromApp: (((T)) -> Void) = { _ in }
    
    public var storage: AnyStorage<Value>?
    
    public init(
        title: String, wrappedValue: @escaping @autoclosure () -> T, storage: AnyStorage<Value>? = nil,
        labels: [DebugToolLabel] = [], taDebugToolConfiguration: TADebugToolConfiguration? = nil, id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        self.labels = labels
        self.storage = storage
        self.wrappedValue = wrappedValue()
        self.taDebugToolConfiguration = taDebugToolConfiguration
        self.onUpdateFromApp = { [weak self] in
            self?.wrappedValue = $0
        }
    }
}
