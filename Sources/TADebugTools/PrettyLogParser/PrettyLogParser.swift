//
//  PrettyLogParser.swift
//  TADebugTools
//
//  Created by Robert Tataru on 24.10.2025.
//

import Foundation

// MARK: - Configuration

struct EventConfig {
    // Keywords that indicate session start
    let sessionStartKeywords = ["App launched", "app_launch", "session_start", "app_open"]
    
    // Keywords that indicate screen views
    let screenViewKeywords = ["ui_view_show", "screen_view", "view_show", "page_view", "screen_displayed"]
    
    // Keywords that indicate user actions
    let actionKeywords = ["ui_button_tap", "button_tap", "BUTTON_TAPPED", "click", "tap", "action", "event"]
    
    // Keywords that indicate session end
    let sessionEndKeywords = ["app_close", "session_end", "app_background"]
    
    // Common parameter names for screen identification
    let screenParamNames = ["name", "screen", "screen_name", "view", "page"]
    
    // Common parameter names for action identification
    let actionParamNames = ["name", "action", "event", "button", "type"]
}

// MARK: - Parser

class PrettyLogParser {
    private let dateFormatter: DateFormatter
    private var sessions: [Session] = []
    private var currentSessionIndex: Int?
    private let config = EventConfig()
    
    init() {
        dateFormatter = DateFormatter()
        // Try multiple date formats
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    }
    
    func parse(_ logContent: String) -> [Session] {
        let lines = logContent.components(separatedBy: .newlines)
        
        for line in lines {
            // Check for session separator
            if line.contains("-- ** ** ** --") || line.contains("===") || line.contains("***") {
                if let idx = currentSessionIndex {
                    sessions[idx].endTime = sessions[idx].screens.last?.exitTime ?? sessions[idx].startTime
                }
                currentSessionIndex = nil
                continue
            }
            
            if let entry = parseLogLine(line) {
                processLogEntry(entry)
            }
        }
        
        // Close final session
        if let idx = currentSessionIndex {
            sessions[idx].endTime = sessions[idx].screens.last?.exitTime ?? sessions[idx].startTime
        }
        
        return sessions
    }
    
    private func parseLogLine(_ line: String) -> LogEntry? {
        // Try multiple log formats
        let patterns = [
            #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+\d{4})\s+(\w+)\s+\[([^\]]+)\]\s+:\s+(.+)$"#,
            #"^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+\[([^\]]+)\]\s+(.+)$"#,
            #"^\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]\s+(\w+)\s+-\s+(.+)$"#,
        ]
        
        for pattern in patterns {
            if let entry = tryParseWithPattern(line, pattern: pattern) {
                return entry
            }
        }
        
        return nil
    }
    
    private func tryParseWithPattern(_ line: String, pattern: String) -> LogEntry? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        let rangeCount = match.numberOfRanges
        guard rangeCount >= 3 else { return nil }
        
        let timestampStr = String(line[Range(match.range(at: 1), in: line)!])
        let level = rangeCount >= 3 ? String(line[Range(match.range(at: 2), in: line)!]) : "info"
        let category = rangeCount >= 4 ? String(line[Range(match.range(at: 3), in: line)!]) : "app"
        let message = rangeCount >= 5 ? String(line[Range(match.range(at: 4), in: line)!]) : String(line[Range(match.range(at: 3), in: line)!])
        
        guard let timestamp = parseTimestamp(timestampStr) else {
            return nil
        }
        
        let params = extractParams(from: message)
        
        return LogEntry(timestamp: timestamp, level: level, category: category, message: message, params: params)
    }
    
    private func parseTimestamp(_ str: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: str) {
                return date
            }
        }
        
        return nil
    }
    
    private func extractParams(from message: String) -> [String: String] {
        var params: [String: String] = [:]
        
        // Pattern for key:value or key=value
        let pattern = #"(\w+)[:=]([^\s,\]]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return params
        }
        
        let matches = regex.matches(in: message, range: NSRange(message.startIndex..., in: message))
        
        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: message),
               let valueRange = Range(match.range(at: 2), in: message) {
                let key = String(message[keyRange])
                let value = String(message[valueRange])
                params[key] = value
            }
        }
        
        return params
    }
    
    private func processLogEntry(_ entry: LogEntry) {
        // Start new session
        if isSessionStart(entry) {
            let launchCount = Int(entry.params["launchCount"] ?? entry.params["launch_count"] ?? "0") ?? 0
            var session = Session(sessionNumber: sessions.count + 1, startTime: entry.timestamp, launchCount: launchCount)
            
            // Extract any metadata
            session.metadata = extractSessionMetadata(entry)
            
            sessions.append(session)
            currentSessionIndex = sessions.count - 1
            return
        }
        
        guard let idx = currentSessionIndex else {
            // If no session started yet, create one automatically
            var session = Session(sessionNumber: sessions.count + 1, startTime: entry.timestamp, launchCount: 0)
            session.metadata = extractSessionMetadata(entry)
            sessions.append(session)
            currentSessionIndex = sessions.count - 1
            processLogEntry(entry)
            return
        }
        
        // Track screen views
        if isScreenView(entry) {
            if let screenName = extractScreenName(entry) {
                addScreenVisit(sessionIndex: idx, screenName: screenName, timestamp: entry.timestamp)
            }
        }
        
        // Track user actions
        if isUserAction(entry) {
            addUserAction(sessionIndex: idx, entry: entry)
        }
        
        // Track session end
        if isSessionEnd(entry) {
            sessions[idx].endTime = entry.timestamp
        }
    }
    
    private func isSessionStart(_ entry: LogEntry) -> Bool {
        return config.sessionStartKeywords.contains { keyword in
            entry.message.lowercased().contains(keyword.lowercased())
        }
    }
    
    private func isScreenView(_ entry: LogEntry) -> Bool {
        return config.screenViewKeywords.contains { keyword in
            entry.message.lowercased().contains(keyword.lowercased())
        }
    }
    
    private func isUserAction(_ entry: LogEntry) -> Bool {
        return config.actionKeywords.contains { keyword in
            entry.message.lowercased().contains(keyword.lowercased())
        }
    }
    
    private func isSessionEnd(_ entry: LogEntry) -> Bool {
        return config.sessionEndKeywords.contains { keyword in
            entry.message.lowercased().contains(keyword.lowercased())
        }
    }
    
    private func extractScreenName(_ entry: LogEntry) -> String? {
        for paramName in config.screenParamNames {
            if let value = entry.params[paramName] {
                return value
            }
        }
        return nil
    }
    
    private func extractActionName(_ entry: LogEntry) -> String? {
        for paramName in config.actionParamNames {
            if let value = entry.params[paramName] {
                return value
            }
        }
        return nil
    }
    
    private func extractSessionMetadata(_ entry: LogEntry) -> [String: String] {
        var metadata: [String: String] = [:]
        
        let interestingKeys = ["version", "app_version", "build", "os_version", "device", "platform"]
        for key in interestingKeys {
            if let value = entry.params[key] {
                metadata[key] = value
            }
        }
        
        return metadata
    }
    
    private func addScreenVisit(sessionIndex: Int, screenName: String, timestamp: Date) {
        // Close previous screen
        if !sessions[sessionIndex].screens.isEmpty {
            let lastIdx = sessions[sessionIndex].screens.count - 1
            sessions[sessionIndex].screens[lastIdx].exitTime = timestamp
        }
        
        // Add new screen
        let visit = ScreenVisit(screenName: formatScreenName(screenName), entryTime: timestamp)
        sessions[sessionIndex].screens.append(visit)
    }
    
    private func addUserAction(sessionIndex: Int, entry: LogEntry) {
        guard !sessions[sessionIndex].screens.isEmpty else { return }
        
        let screenIdx = sessions[sessionIndex].screens.count - 1
        let actionName = extractActionName(entry) ?? "Unknown Action"
        
        // Determine action type from message content
        let actionType = categorizeAction(entry)
        
        // Format details with all available parameters
        let details = formatActionDetails(actionName, entry: entry)
        
        let action = UserAction(timestamp: entry.timestamp, actionType: actionType, details: details, rawEvent: actionName)
        sessions[sessionIndex].screens[screenIdx].actions.append(action)
    }
    
    private func categorizeAction(_ entry: LogEntry) -> String {
        let msg = entry.message.lowercased()
        
        if msg.contains("tap") || msg.contains("click") || msg.contains("button") {
            return "Button Tap"
        } else if msg.contains("swipe") {
            return "Swipe"
        } else if msg.contains("scroll") {
            return "Scroll"
        } else if msg.contains("input") || msg.contains("text") || msg.contains("edit") {
            return "Input"
        } else if msg.contains("select") || msg.contains("choose") {
            return "Selection"
        } else if msg.contains("delete") || msg.contains("remove") {
            return "Delete"
        } else if msg.contains("create") || msg.contains("add") || msg.contains("new") {
            return "Create"
        } else if msg.contains("update") || msg.contains("save") || msg.contains("change") {
            return "Update"
        } else if msg.contains("open") || msg.contains("view") {
            return "View"
        } else if msg.contains("close") || msg.contains("exit") || msg.contains("cancel") {
            return "Close"
        } else if msg.contains("share") {
            return "Share"
        } else if msg.contains("purchase") || msg.contains("paywall") || msg.contains("subscribe") {
            return "Commerce"
        } else {
            return "Action"
        }
    }
    
    private func formatActionDetails(_ action: String, entry: LogEntry) -> String {
        var details = formatScreenName(action)
        
        // Add relevant parameters
        var additionalInfo: [String] = []
        
        for (key, value) in entry.params {
            // Skip common keys that are already used
            if config.actionParamNames.contains(key) || key == "timeDelta" {
                continue
            }
            
            // Add meaningful parameters
            if !value.isEmpty && value != "nil" {
                let formattedKey = formatScreenName(key)
                let formattedValue = formatScreenName(value)
                additionalInfo.append("\(formattedKey): \(formattedValue)")
            }
        }
        
        if !additionalInfo.isEmpty {
            details += " (" + additionalInfo.joined(separator: ", ") + ")"
        }
        
        return details
    }
    
    private func formatScreenName(_ name: String) -> String {
        let formatted = name.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return formatted.capitalized
    }
}

// MARK: - Report Generator

class ReportGenerator {
    func generate(sessions: [Session]) -> String {
        var report = """
        ╔════════════════════════════════════════════════════════════════════╗
        ║                    USER SESSION ANALYTICS REPORT                    ║
        ╚════════════════════════════════════════════════════════════════════╝
        
        """
        
        if sessions.isEmpty {
            report += "No sessions found in the log.\n"
            return report
        }
        
        report += "Total Sessions: \(sessions.count)\n"
        report += generateSummary(sessions: sessions)
        report += "\n"
        
        for session in sessions {
            report += generateSessionReport(session)
            report += "\n" + String(repeating: "─", count: 72) + "\n\n"
        }
        
        return report
    }
    
    private func generateSummary(sessions: [Session]) -> String {
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
        let avgDuration = totalDuration / Double(sessions.count)
        
        let totalScreens = sessions.reduce(0) { $0 + $1.screens.count }
        let avgScreens = Double(totalScreens) / Double(sessions.count)
        
        let mins = Int(avgDuration) / 60
        let secs = Int(avgDuration) % 60
        let avgFormatted = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
        
        return """
        Average Session Duration: \(avgFormatted)
        Average Screens per Session: \(String(format: "%.1f", avgScreens))
        """
    }
    
    private func generateSessionReport(_ session: Session) -> String {
        var report = """
        ┌────────────────────────────────────────────────────────────────────┐
        │ SESSION #\(session.sessionNumber)
        │ Started: \(formatTime(session.startTime))
        │ Duration: \(session.durationFormatted)
        """
        
        if session.launchCount > 0 {
            report += "\n│ Launch Count: \(session.launchCount)"
        }
        
        if !session.metadata.isEmpty {
            for (key, value) in session.metadata.sorted(by: { $0.key < $1.key }) {
                report += "\n│ \(key.capitalized): \(value)"
            }
        }
        
        report += "\n└────────────────────────────────────────────────────────────────────┘\n\n"
        
        if session.screens.isEmpty {
            report += "  No screen activity recorded.\n"
            return report
        }
        
        report += "📱 User Journey:\n\n"
        
        for (index, screen) in session.screens.enumerated() {
            report += "  \(index + 1). \(screen.screenName)\n"
            report += "     ⏱  Time spent: \(screen.durationFormatted)\n"
            
            if !screen.actions.isEmpty {
                report += "     📍 Actions (\(screen.actions.count)):\n"
                
                // Group similar actions
                let groupedActions = groupActions(screen.actions)
                
                for (actionType, actions) in groupedActions.sorted(by: { $0.key < $1.key }) {
                    let icon = getActionIcon(actionType)
                    
                    if actions.count == 1 {
                        report += "        \(icon) \(actions[0].details)\n"
                    } else {
                        // If multiple similar actions, show count
                        let uniqueDetails = Set(actions.map { $0.details })
                        if uniqueDetails.count == 1 {
                            report += "        \(icon) \(actions[0].details) ×\(actions.count)\n"
                        } else {
                            for action in actions {
                                report += "        \(icon) \(action.details)\n"
                            }
                        }
                    }
                }
            }
            
            report += "\n"
        }
        
        return report
    }
    
    private func groupActions(_ actions: [UserAction]) -> [String: [UserAction]] {
        var grouped: [String: [UserAction]] = [:]
        
        for action in actions {
            if grouped[action.actionType] == nil {
                grouped[action.actionType] = []
            }
            grouped[action.actionType]?.append(action)
        }
        
        return grouped
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func getActionIcon(_ actionType: String) -> String {
        switch actionType {
        case "Button Tap": return "👆"
        case "Swipe": return "👉"
        case "Scroll": return "📜"
        case "Input": return "⌨️"
        case "Selection": return "☑️"
        case "Delete": return "🗑️"
        case "Create": return "➕"
        case "Update": return "💾"
        case "View": return "👁️"
        case "Close": return "❌"
        case "Share": return "📤"
        case "Commerce": return "💳"
        default: return "•"
        }
    }
}
