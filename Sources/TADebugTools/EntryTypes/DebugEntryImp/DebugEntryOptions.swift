///*
//MIT License
//
//Copyright (c) 2025 Tech Artists Agency
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//*/

//
//  DebugEntryOptions.swift
//  TADebugTools
//
//  Created by Robert Tataru on 06.01.2025.
//

import SwiftUI
import Combine

public class DebugEntryOptions<E: RawRepresentable & CaseIterable & Hashable>: DebugEntryProtocol where E.RawValue == String {

    public var id: UUID
    public var title: String

    @Published public var wrappedValue: E {
        didSet {
            if let taDebugToolConfiguration, wrappedValue.rawValue != oldValue.rawValue {
                id = UUID()
                storage?.update(wrappedValue)
                taDebugToolConfiguration.objectWillChange.send()
            }
        }
    }

    public var labels: [DebugToolLabel] = []
    public var possibleValues: [E]
    weak public var taDebugToolConfiguration: TADebugToolConfiguration?
    public var storage: AnyStorage<E>?
    
    var cancellables: Set<AnyCancellable> = []

    public lazy var stream: AsyncStream<E> = { [weak self] in
        AsyncStream { continuation in
            self?.continuation = continuation
        }
    }()
    public var continuation: AsyncStream<E>.Continuation?

    @MainActor
    public var renderView: AnyView {
        AnyView(DebugEntryOptionsView(debugEntry: self))
    }

    public var onUpdateFromDebugTool: ((E) -> Void)?
    public var onUpdateFromApp: ((E) -> Void) = { _ in }

    public init( title: String, wrappedValue: E, storage: AnyStorage<E>? = nil, labels: [DebugToolLabel] = [], taDebugToolConfiguration: TADebugToolConfiguration? = nil, id: UUID = UUID() ) {
        self.id = id
        self.title = title
        self.labels = labels
        self.storage = storage
        self.taDebugToolConfiguration = taDebugToolConfiguration
        self.possibleValues = Array(E.allCases)
        self.wrappedValue = wrappedValue

        self.onUpdateFromApp = { [weak self] newValue in
            guard let self = self else { return }
            if newValue != self.wrappedValue {
                self.wrappedValue = newValue
            }
        }
        
        storage?.$value
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self = self, self.wrappedValue != newValue else { return }
                self.wrappedValue = newValue
            }
            .store(in: &cancellables)
    }
}
