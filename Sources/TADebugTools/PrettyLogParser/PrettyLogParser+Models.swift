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
//  Models.swift
//  TADebugTools
//
//  Created by Robert Tataru on 24.10.2025.
//

import Foundation

struct LogEntry {
    let timestamp: Date
    let level: String
    let category: String
    let message: String
    let params: [String: String]
}

struct ScreenVisit {
    let screenName: String
    let entryTime: Date
    var exitTime: Date?
    var actions: [UserAction] = []
    
    var duration: TimeInterval {
        guard let exit = exitTime else { return 0 }
        return exit.timeIntervalSince(entryTime)
    }
    
    var durationFormatted: String {
        let totalSeconds = duration
        let mins = Int(totalSeconds) / 60
        let secs = totalSeconds.truncatingRemainder(dividingBy: 60)
        
        if mins > 0 {
            return "\(mins)m \(String(format: "%.1f", secs))s"
        } else if totalSeconds >= 1 {
            return "\(String(format: "%.1f", totalSeconds))s"
        } else {
            return "\(String(format: "%.2f", totalSeconds))s"
        }
    }
}

struct UserAction {
    let timestamp: Date
    let actionType: String
    let details: String
    let rawEvent: String
}

struct Session {
    let sessionNumber: Int
    let startTime: Date
    var endTime: Date?
    var screens: [ScreenVisit] = []
    var launchCount: Int = 0
    var metadata: [String: String] = [:]
    
    var duration: TimeInterval {
        guard let end = endTime else { return Date().timeIntervalSince(startTime) }
        return end.timeIntervalSince(startTime)
    }
    
    var durationFormatted: String {
        let totalSeconds = duration
        let mins = Int(totalSeconds) / 60
        let secs = totalSeconds.truncatingRemainder(dividingBy: 60)
        
        if mins > 0 {
            return "\(mins)m \(String(format: "%.1f", secs))s"
        } else if totalSeconds >= 10 {
            return "\(String(format: "%.0f", totalSeconds))s"
        } else if totalSeconds >= 1 {
            return "\(String(format: "%.1f", totalSeconds))s"
        } else {
            return "\(String(format: "%.2f", totalSeconds))s"
        }
    }
}
