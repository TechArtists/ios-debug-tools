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
//  FileMonitor.swift
//  TADebugTools
//
//  Created by Robert Tataru on 04.02.2025.
//

import Foundation
import Combine

enum FileMonitorError: Error, LocalizedError {
    case fileNotFound
    case unreadableFile(Error)
    case failedToMonitor

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The file was not found."
        case .unreadableFile(let error):
            return "The file could not be read: \(error.localizedDescription)"
        case .failedToMonitor:
            return "Failed to monitor file changes."
        }
    }
}


class FileMonitor: @unchecked Sendable {

    private var fileDescriptor: Int32?
    private var source: DispatchSourceFileSystemObject?
    private let fileURL: URL

    private let fileMonitorQueue = DispatchQueue(label: "com.tadebugtools.filemonitor")

    private var lastLines: [String] = []

    public let linesPublisher = CurrentValueSubject<[String], Never>([])
    public let errorPublisher = PassthroughSubject<FileMonitorError, Never>()

    private let eventSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(fileURL: URL) {
        self.fileURL = fileURL
        setupDebounce()
        startMonitoring()
    }
    
    private func setupDebounce() {
        eventSubject
            .debounce(for: .milliseconds(200), scheduler: fileMonitorQueue)
            .sink { [weak self] in
                self?.reloadFileContent()
            }
            .store(in: &cancellables)
    }

    private func reloadFileContent() {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            
            if lines != lastLines {
                lastLines = lines
                linesPublisher.send(lines)
            }
        } catch {
            errorPublisher.send(.unreadableFile(error))
        }
    }

    func startMonitoring() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            errorPublisher.send(.fileNotFound)
            return
        }
        
        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard let fd = fileDescriptor, fd != -1 else {
            errorPublisher.send(.failedToMonitor)
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: fileMonitorQueue
        )
        
        source?.setEventHandler { [weak self] in
            self?.eventSubject.send(())
        }
        
        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor {
                close(fd)
            }
        }
        
        source?.resume()

        fileMonitorQueue.async { [weak self] in
            self?.reloadFileContent()
        }
    }

    func stopMonitoring() {
        source?.cancel()
        source = nil
    }
    
    deinit {
        stopMonitoring()
    }
}
