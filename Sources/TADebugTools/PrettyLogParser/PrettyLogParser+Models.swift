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
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
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
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}
