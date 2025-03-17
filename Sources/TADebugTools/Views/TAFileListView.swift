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
//  TAFileListView.swift
//  TADebugTools
//
//  Created by Robert Tataru on 04.02.2025.
//

import SwiftUI
import Combine

public struct TAFileListView: View {
    
    struct Line: Identifiable, Hashable {
        let id = UUID()
        let content: String
    }
    
    let fileURL: URL
    
    @State private var lines: [Line] = []
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var lastItemID: UUID? = nil
    
    @State private var cancellables = Set<AnyCancellable>()
    private var fileMonitor: FileMonitor

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.fileMonitor = FileMonitor(fileURL: fileURL)
    }
    
    private var filteredLines: [Line] {
        return searchText.isEmpty ? lines : lines.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    public var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.largeTitle)
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }
            } else {
                ScrollViewReader { proxy in
                    List(filteredLines, id: \.self.id) { line in
                        Text(line.content)
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                    .searchable(text: $searchText, prompt: "Search")
                }
            }
        }
        .navigationTitle(Text("File Viewer"))
        .onAppear {
            fileMonitor.linesPublisher
                .receive(on: DispatchQueue.main)
                .sink { newLines in
                    self.lines = newLines.map { Line(content: $0) }
                }
                .store(in: &cancellables)

            fileMonitor.errorPublisher
                .receive(on: DispatchQueue.main)
                .sink { error in
                    self.errorMessage = error.errorDescription ?? "Unknown error"
                }
                .store(in: &cancellables)

            fileMonitor.startMonitoring()
        }
    }
}
