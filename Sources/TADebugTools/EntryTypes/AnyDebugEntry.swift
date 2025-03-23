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
//  AnyDebugEntry.swift
//  TADebugTools
//
//  Created by Robert Tataru on 20.03.2025.
//
import SwiftUI

// MARK: - Type Erasure
public final class AnyDebugEntry<Value>: DebugEntryProtocol {

    // Stored closures to forward all requirements.
    private let _wrappedValue: () -> Value
    private let _onUpdateFromApp: (Value) -> Void
    private let _id: () -> UUID
    private let _title: () -> String
    private let _labels: () -> [DebugToolLabel]
    private let _stream: () -> AsyncStream<Value>
    private let _continuation: () -> AsyncStream<Value>.Continuation?
    private let _onUpdateFromDebugTool: () -> ((Value) -> Void)?
    private let _renderView: @MainActor () -> AnyView
    private let _getConfig: () -> TADebugToolConfiguration?
    private let _setConfig: (TADebugToolConfiguration?) -> Void
    private let _storage: () -> AnyStorage<Value>?

    public init<DE: DebugEntryProtocol>(_ base: DE) where DE.Value == Value {
        _wrappedValue = { base.wrappedValue }
        _onUpdateFromApp = base.onUpdateFromApp
        _id = { base.id }
        _title = { base.title }
        _labels = { base.labels }
        _stream = { base.stream }
        _continuation = { base.continuation }
        _onUpdateFromDebugTool = { base.onUpdateFromDebugTool }
        _renderView = { base.renderView }
        _getConfig = { base.taDebugToolConfiguration }
        _setConfig = { newValue in base.taDebugToolConfiguration = newValue }
        _storage = { base.storage }
    }
    
    public var wrappedValue: Value { _wrappedValue() }
    public var onUpdateFromApp: ((Value) -> Void) { _onUpdateFromApp }
    public var storage: AnyStorage<Value>?
    public var id: UUID { _id() }
    public var title: String { _title() }
    public var labels: [DebugToolLabel] { _labels() }
    public var stream: AsyncStream<Value> { _stream() }
    public var continuation: AsyncStream<Value>.Continuation? { _continuation() }
    public var onUpdateFromDebugTool: ((Value) -> Void)? { _onUpdateFromDebugTool() }
    @MainActor public var renderView: AnyView { _renderView() }
    public var taDebugToolConfiguration: TADebugToolConfiguration? {
        get { _getConfig() }
        set { _setConfig(newValue) }
    }
}
