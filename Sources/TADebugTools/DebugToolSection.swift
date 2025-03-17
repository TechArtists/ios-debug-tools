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
//  DebugToolSection.swift
//  TADebugTools
//
//  Created by Robert Tataru on 17.03.2025.
//

import SwiftUI

public enum DebugToolLabel: Sendable {
    case persistsBetweenSessions
    case requresrestart
}

public struct DebugToolSection: Hashable, Sendable {
    public let id: String
    public let title: String
    
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
    
    public static let app = DebugToolSection(id: "app", title: "App")
    public static let onboarding = DebugToolSection(id: "onboarding", title: "Onboarding")
    public static let appSettings = DebugToolSection(id: "appSettings", title: "App Settings")
    public static let defaults = DebugToolSection(id: "defaults", title: "Defaults")
    public static let logs = DebugToolSection(id: "logs", title: "Logs")
    public static let others = DebugToolSection(id: "others", title: "Others")
}

extension DebugToolSection {
    public static func custom(id: String, title: String) -> DebugToolSection {
        return DebugToolSection(id: id, title: title)
    }
}
