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
//  TADebugDictionaryView.swift
//  TADebugTools
//
//  Created by Robert Tataru on 03.02.2025.
//

import SwiftUI

enum JSONContent {
    case dictionary([String: Any])
    case array([Any])
}

public struct TADebugDictionaryView: View {
    let dictionary: [String: String]
    @State private var searchText: String = ""
    
    public init(dictionary: [String : String]) {
        self.dictionary = dictionary
    }
    
    private var filteredEntries: [(key: String, value: String)] {
        let entries = dictionary.map { (key: $0.key, value: $0.value) }
        guard !searchText.isEmpty else {
            return entries.sorted { $0.key < $1.key }
        }
        return entries.filter { entry in
            entry.key.localizedCaseInsensitiveContains(searchText) ||
            entry.value.localizedCaseInsensitiveContains(searchText)
        }
        .sorted { $0.key < $1.key }
    }
    
    private func parseJSONString(_ jsonString: String) -> JSONContent? {
        guard jsonString.trimmingCharacters(in: .whitespacesAndNewlines).first.map({ $0 == "{" || $0 == "[" }) == true else {
            return nil
        }
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            if let dict = jsonObject as? [String: Any] {
                return .dictionary(dict)
            } else if let array = jsonObject as? [Any] {
                return .array(array)
            }
        } catch {
            print("JSON parse error: \(error)")
        }
        return nil
    }
    
    public var body: some View {
        List(filteredEntries, id: \.key) { entry in
            if let jsonContent = parseJSONString(entry.value) {
                NavigationLink(destination: TADebugJSONDetailView(jsonContent: jsonContent)) {
                    rowView(for: entry)
                }
            } else {
                rowView(for: entry)
            }
        }
        .searchable(text: $searchText, prompt: "Search keys and values")
        .navigationTitle("Dictionary View")
    }
    
    private func rowView(for entry: (key: String, value: String)) -> some View {
        HStack(alignment: .top) {
            Text(entry.key)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            ExpandableText(text: entry.value)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ExpandableText View

struct ExpandableText: View {
    let text: String
    private let limit: Int = 50
    @State private var expanded: Bool = false
    
    var body: some View {
        Group {
            if expanded || text.count <= limit {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                (Text(text.prefix(limit))
                    + Text(" more")
                        .foregroundColor(.gray))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onTapGesture {
            withAnimation {
                expanded.toggle()
            }
        }
    }
}

// MARK: - JSON Detail View

struct TADebugJSONDetailView: View {
    let jsonContent: JSONContent
    
    var body: some View {
        switch jsonContent {
        case .dictionary(let dict):
            List(dict.keys.sorted(), id: \.self) { key in
                HStack {
                    Text(key)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    Text(String(describing: dict[key]!))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("JSON Dictionary")
        case .array(let array):
            List(0..<array.count, id: \.self) { index in
                HStack {
                    Text("Item \(index)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    Text(String(describing: array[index]))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("JSON Array")
        }
    }
}

struct TADebugDictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = [
            "Name": "Alice",
            "Occupation": "Engineer",
            "Location": "Wonderland",
            "Hobby": "Adventuring",
            "Details": "{\"age\":30, \"city\":\"Wonderland\", \"bio\":\"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\"}"
        ]
        NavigationView {
            TADebugDictionaryView(dictionary: sampleData)
        }
    }
}
