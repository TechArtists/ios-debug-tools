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