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
import TADebugTools

enum ExampleDebugMenuLiveFeed {
    static let sharedHub = Hub()

    static let sources: [TADebugLiveFeedSource] = [
        TADebugLiveFeedSource(
            id: TADebugLiveFeedSource.logsSourceID,
            title: "Logs"
        ) {
            sharedHub.makeStream(
                sourceID: TADebugLiveFeedSource.logsSourceID,
                sourceTitle: "Logs"
            )
        },
        TADebugLiveFeedSource(
            id: TADebugLiveFeedSource.analyticsSourceID,
            title: "Analytics"
        ) {
            sharedHub.makeStream(
                sourceID: TADebugLiveFeedSource.analyticsSourceID,
                sourceTitle: "Analytics"
            )
        }
    ]

    static func emitLog(_ message: String, metadataText: String? = nil) {
        sharedHub.emit(
            sourceID: TADebugLiveFeedSource.logsSourceID,
            sourceTitle: "Logs",
            message: message,
            metadataText: metadataText
        )
    }

    static func emitAnalytics(_ eventName: String, metadataText: String? = nil) {
        sharedHub.emit(
            sourceID: TADebugLiveFeedSource.analyticsSourceID,
            sourceTitle: "Analytics",
            message: eventName,
            metadataText: metadataText
        )
    }

    final class Hub {
        private let replayCapacity = 60
        private let lock = NSLock()
        private var continuations: [String: [UUID: AsyncStream<TADebugLiveFeedItem>.Continuation]] = [:]
        private var replayBuffer: [TADebugLiveFeedItem] = []
        private var backgroundTrafficTask: Task<Void, Never>?

        init() {
            startBackgroundTraffic()
        }

        func makeStream(sourceID: String, sourceTitle: String) -> AsyncStream<TADebugLiveFeedItem> {
            AsyncStream { continuation in
                let token = UUID()

                lock.lock()
                var sourceContinuations = continuations[sourceID, default: [:]]
                sourceContinuations[token] = continuation
                continuations[sourceID] = sourceContinuations
                let bufferedItems = replayBuffer.filter { $0.sourceID == sourceID }
                lock.unlock()

                continuation.yield(
                    TADebugLiveFeedItem(
                        sourceID: sourceID,
                        sourceTitle: sourceTitle,
                        message: "Connected to the example \(sourceTitle.lowercased()) stream"
                    )
                )

                for item in bufferedItems {
                    continuation.yield(item)
                }

                continuation.onTermination = { [weak self] _ in
                    self?.removeContinuation(for: sourceID, token: token)
                }
            }
        }

        func emit(
            sourceID: String,
            sourceTitle: String,
            message: String,
            metadataText: String? = nil
        ) {
            let item = TADebugLiveFeedItem(
                sourceID: sourceID,
                sourceTitle: sourceTitle,
                message: message,
                metadataText: metadataText
            )

            lock.lock()
            replayBuffer.append(item)
            if replayBuffer.count > replayCapacity {
                replayBuffer.removeFirst(replayBuffer.count - replayCapacity)
            }
            let activeContinuations = Array(continuations[sourceID, default: [:]].values)
            lock.unlock()

            for continuation in activeContinuations {
                continuation.yield(item)
            }
        }

        private func startBackgroundTraffic() {
            guard backgroundTrafficTask == nil else {
                return
            }

            backgroundTrafficTask = Task {
                var tick = 0

                while !Task.isCancelled {
                    tick += 1

                    emit(
                        sourceID: TADebugLiveFeedSource.logsSourceID,
                        sourceTitle: "Logs",
                        message: "Heartbeat \(tick)",
                        metadataText: "Example background traffic"
                    )

                    if tick.isMultiple(of: 2) {
                        emit(
                            sourceID: TADebugLiveFeedSource.analyticsSourceID,
                            sourceTitle: "Analytics",
                            message: "demo_background_heartbeat",
                            metadataText: "heartbeat=\(tick)"
                        )
                    }

                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        private func removeContinuation(for sourceID: String, token: UUID) {
            lock.lock()
            defer { lock.unlock() }

            guard var sourceContinuations = continuations[sourceID] else {
                return
            }

            sourceContinuations.removeValue(forKey: token)
            continuations[sourceID] = sourceContinuations.isEmpty ? nil : sourceContinuations
        }
    }
}
