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

import Combine
import Foundation

public struct TADebugLiveFeedSource {
    public typealias StreamBuilder = @Sendable () -> AsyncStream<TADebugLiveFeedItem>

    public static let logsSourceID = "logs"
    public static let analyticsSourceID = "analytics"

    public let id: String
    public let title: String
    public let makeStream: StreamBuilder

    public init(
        id: String,
        title: String,
        makeStream: @escaping StreamBuilder
    ) {
        self.id = id
        self.title = title
        self.makeStream = makeStream
    }
}

public extension TADebugLiveFeedSource {
    static func fileLogs(
        fileURL: URL,
        id: String = logsSourceID,
        title: String = "Logs"
    ) -> Self {
        Self(id: id, title: title) {
            TADebugFileLiveFeedStream.makeStream(
                fileURL: fileURL,
                sourceID: id,
                sourceTitle: title
            )
        }
    }
}

private final class TADebugFileLiveFeedStreamState {
    let lock = NSLock()
    let monitor: FileMonitor
    var previousLines: [String] = []
    var cancellables = Set<AnyCancellable>()

    init(fileURL: URL) {
        self.monitor = FileMonitor(fileURL: fileURL)
    }

    func consume(_ lines: [String]) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        defer {
            previousLines = lines
        }

        guard !previousLines.isEmpty else {
            return lines
        }

        guard
            lines.count >= previousLines.count,
            Array(lines.prefix(previousLines.count)) == previousLines
        else {
            return lines
        }

        return Array(lines.dropFirst(previousLines.count))
    }
}

private enum TADebugFileLiveFeedStream {
    static func makeStream(
        fileURL: URL,
        sourceID: String,
        sourceTitle: String
    ) -> AsyncStream<TADebugLiveFeedItem> {
        AsyncStream { continuation in
            let state = TADebugFileLiveFeedStreamState(fileURL: fileURL)

            state.monitor.linesPublisher
                .sink { lines in
                    let emittedLines = state.consume(lines)

                    for line in emittedLines {
                        continuation.yield(
                            TADebugLiveFeedItem(
                                sourceID: sourceID,
                                sourceTitle: sourceTitle,
                                message: line
                            )
                        )
                    }
                }
                .store(in: &state.cancellables)

            state.monitor.errorPublisher
                .sink { error in
                    continuation.yield(
                        TADebugLiveFeedItem(
                            sourceID: sourceID,
                            sourceTitle: sourceTitle,
                            message: "File monitor error",
                            metadataText: error.localizedDescription
                        )
                    )
                }
                .store(in: &state.cancellables)

            state.monitor.startMonitoring()

            continuation.onTermination = { _ in
                state.cancellables.removeAll()
                state.monitor.stopMonitoring()
            }
        }
    }
}
