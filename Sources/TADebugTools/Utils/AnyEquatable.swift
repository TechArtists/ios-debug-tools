//
//  AnyEquatable.swift
//  TADebugTools
//
//  Created by Robert Tataru on 20.03.2025.
//

import Foundation

struct AnyEquatable {
    private let value: Any
    private let isEqual: (Any) -> Bool

    init<T: Equatable>(_ value: T) {
        self.value = value
        self.isEqual = { ($0 as? T) == value }
    }

    func equals(_ other: Any) -> Bool {
        return isEqual(other)
    }
}
