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
//  DebugEntryProtocol.swift
//  TADebugTools
//
//  Created by Robert Tataru on 09.12.2024.
//

import SwiftUI

public protocol DebugEntryProtocol: Identifiable, ObservableObject {
    associatedtype Value
    
    //MARK: Make sure that in the implementation you use weak reference for this
    var taDebugToolConfiguration: TADebugToolConfiguration? { get set }
    
    var id: UUID { get }
    var title: String { get }
    var wrappedValue: Value { get }
    var labels: [DebugToolLabel] { get }
    var stream: AsyncStream<Value> { get }
    var continuation: AsyncStream<Value>.Continuation? { get }
    var onUpdateFromDebugTool: ((Value) -> Void)? { get }
    var onUpdateFromApp: ((Value) -> Void) { get }
    var storage: AnyStorage<Value>? { get }
    
    @MainActor
    var renderView: AnyView { get }
}

protocol DebugEntryActionProtocol: DebugEntryProtocol {
    
    var onTapShowDestinationView : (() -> AnyView)? { get }
}

protocol DebugEntryConfirmableProtocol: DebugEntryProtocol {
    
    var onConfirm: (String) -> Void { get }
}
