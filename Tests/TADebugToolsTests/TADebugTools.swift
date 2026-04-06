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

import Foundation
import Testing
@testable import TADebugTools

@Test func liveFeedBufferKeepsNewestItemsOnly() {
    var buffer = TADebugLiveFeedBuffer(capacity: 3)

    for index in 1...4 {
        buffer.append(
            TADebugLiveFeedItem(
                sourceID: TADebugLiveFeedSource.logsSourceID,
                sourceTitle: "Logs",
                message: "message-\(index)"
            )
        )
    }

    #expect(buffer.items.map(\.message) == ["message-2", "message-3", "message-4"])
}

@Test func liveFeedQueryFiltersBySourceAndSearchText() {
    let items = [
        TADebugLiveFeedItem(
            sourceID: TADebugLiveFeedSource.logsSourceID,
            sourceTitle: "Logs",
            message: "app launched"
        ),
        TADebugLiveFeedItem(
            sourceID: TADebugLiveFeedSource.analyticsSourceID,
            sourceTitle: "Analytics",
            message: "purchase_complete"
        ),
        TADebugLiveFeedItem(
            sourceID: TADebugLiveFeedSource.analyticsSourceID,
            sourceTitle: "Analytics",
            message: "paywall_error",
            metadataText: "network timeout"
        )
    ]

    let filteredItems = TADebugLiveFeedQuery(
        sourceFilter: .analytics,
        searchText: "network"
    )
    .filteredItems(from: items)

    #expect(filteredItems.count == 1)
    #expect(filteredItems.first?.message == "paywall_error")
}

@Test func collapsedPositionStoreRestoresAllowedPositionOrFallsBack() throws {
    let suiteName = "TADebugToolsTests.\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let store = TADebugToolCollapsedPositionStore(key: "collapsedPosition")

    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    #expect(
        store.load(
            allowedPositions: [.topLeading, .bottomTrailing],
            initialPosition: .bottomTrailing,
            userDefaults: userDefaults
        ) == .bottomTrailing
    )

    store.save(.topLeading, userDefaults: userDefaults)

    #expect(
        store.load(
            allowedPositions: [.topLeading, .bottomTrailing],
            initialPosition: .bottomTrailing,
            userDefaults: userDefaults
        ) == .topLeading
    )

    userDefaults.set(TADebugToolCollapsedPosition.topTrailing.rawValue, forKey: "collapsedPosition")

    #expect(
        store.load(
            allowedPositions: [.bottomLeading, .bottomTrailing],
            initialPosition: .bottomLeading,
            userDefaults: userDefaults
        ) == .bottomLeading
    )
}
