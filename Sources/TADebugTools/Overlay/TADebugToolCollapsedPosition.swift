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

import SwiftUI

public enum TADebugToolCollapsedPosition: String, CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    public var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .topLeading:
            return "Top Left"
        case .topTrailing:
            return "Top Right"
        case .bottomLeading:
            return "Bottom Left"
        case .bottomTrailing:
            return "Bottom Right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeading:
            return .topLeading
        case .topTrailing:
            return .topTrailing
        case .bottomLeading:
            return .bottomLeading
        case .bottomTrailing:
            return .bottomTrailing
        }
    }

    func launcherPadding(safeAreaInsets: EdgeInsets) -> EdgeInsets {
        let spacing = 12.0

        switch self {
        case .topLeading:
            return EdgeInsets(
                top: safeAreaInsets.top + spacing,
                leading: safeAreaInsets.leading + spacing,
                bottom: 0,
                trailing: 0
            )
        case .topTrailing:
            return EdgeInsets(
                top: safeAreaInsets.top + spacing,
                leading: 0,
                bottom: 0,
                trailing: safeAreaInsets.trailing + spacing
            )
        case .bottomLeading:
            return EdgeInsets(
                top: 0,
                leading: safeAreaInsets.leading + spacing,
                bottom: safeAreaInsets.bottom + spacing,
                trailing: 0
            )
        case .bottomTrailing:
            return EdgeInsets(
                top: 0,
                leading: 0,
                bottom: safeAreaInsets.bottom + spacing,
                trailing: safeAreaInsets.trailing + spacing
            )
        }
    }
}

struct TADebugToolCollapsedPositionStore {
    let key: String

    func load(
        allowedPositions: [TADebugToolCollapsedPosition],
        initialPosition: TADebugToolCollapsedPosition,
        userDefaults: UserDefaults = .standard
    ) -> TADebugToolCollapsedPosition {
        let sanitizedPositions = sanitize(allowedPositions, fallback: initialPosition)
        let fallbackPosition = sanitizedPositions.contains(initialPosition) ? initialPosition : sanitizedPositions[0]

        guard
            let storedRawValue = userDefaults.string(forKey: key),
            let storedPosition = TADebugToolCollapsedPosition(rawValue: storedRawValue),
            sanitizedPositions.contains(storedPosition)
        else {
            return fallbackPosition
        }

        return storedPosition
    }

    func save(
        _ position: TADebugToolCollapsedPosition,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(position.rawValue, forKey: key)
    }

    private func sanitize(
        _ positions: [TADebugToolCollapsedPosition],
        fallback: TADebugToolCollapsedPosition
    ) -> [TADebugToolCollapsedPosition] {
        let uniquePositions = positions.reduce(into: [TADebugToolCollapsedPosition]()) { partialResult, position in
            guard !partialResult.contains(position) else {
                return
            }
            partialResult.append(position)
        }

        return uniquePositions.isEmpty ? [fallback] : uniquePositions
    }
}
