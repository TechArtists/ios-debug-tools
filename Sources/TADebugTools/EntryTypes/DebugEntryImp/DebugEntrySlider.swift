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
//  DebugEntrySlider.swift
//  TADebugTools
//
//  Created by Robert Tataru on 28.04.2026.
//

import SwiftUI
import Combine

public final class DebugEntrySlider: DebugEntryProtocol {

    weak public var taDebugToolConfiguration: TADebugToolConfiguration?

    public var id: UUID
    @Published public var renderID: UUID
    public var title: String

    @Published public var wrappedValue: Double {
        didSet {
            if wrappedValue != oldValue {
                renderID = UUID()
                storage?.update(wrappedValue)
                taDebugToolConfiguration?.objectWillChange.send()
            }
        }
    }

    public var range: ClosedRange<Double>
    public var step: Double?
    public var labels: [DebugToolLabel]

    public lazy var stream: AsyncStream<Value> = { [weak self] in
        AsyncStream { continuation in
            self?.continuation = continuation
        }
    }()

    public var continuation: AsyncStream<Value>.Continuation?

    @MainActor
    public var renderView: AnyView {
        AnyView(DebugEntrySliderView(debugEntry: self))
    }

    public var onUpdateFromDebugTool: ((Double) -> Void)?

    public var onUpdateFromApp: ((Double) -> Void) = { _ in }

    public var storage: AnyStorage<Double>?

    var cancellables: Set<AnyCancellable> = []

    public init(
        title: String,
        wrappedValue: Double,
        range: ClosedRange<Double>,
        step: Double? = nil,
        storage: AnyStorage<Double>? = nil,
        labels: [DebugToolLabel] = [],
        taDebugToolConfiguration: TADebugToolConfiguration? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.renderID = id
        self.title = title
        self.range = range
        self.step = step.flatMap { $0 > 0 ? $0 : nil }
        self.wrappedValue = Self.clamp(wrappedValue, to: range)
        self.storage = storage
        self.labels = labels
        self.taDebugToolConfiguration = taDebugToolConfiguration
        self.onUpdateFromApp = { [weak self] newValue in
            guard let self else { return }
            let clampedValue = Self.clamp(newValue, to: self.range)
            if clampedValue != self.wrappedValue {
                self.wrappedValue = clampedValue
            }
        }

        storage?.$value
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                let clampedValue = Self.clamp(newValue, to: self.range)
                guard self.wrappedValue != clampedValue else { return }
                self.wrappedValue = clampedValue
            }
            .store(in: &cancellables)
    }

    @MainActor
    func updateFromDebugTool(_ newValue: Double) {
        let clampedValue = Self.clamp(newValue, to: range)
        guard clampedValue != wrappedValue else { return }

        wrappedValue = clampedValue
        continuation?.yield(clampedValue)
        onUpdateFromDebugTool?(clampedValue)
        taDebugToolConfiguration?.refreshEntryVisibility()
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
