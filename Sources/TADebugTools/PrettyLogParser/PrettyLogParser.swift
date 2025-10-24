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
    let sessionStartKeywords = ["App launched", "app_launch", "session_start", "App launch completed successfully"]
    
    // Keywords that indicate screen views
    let screenViewKeywords = ["ui_view_show", "screen_view", "view_show", "page_view", "screen_displayed"]
    
    // Keywords that indicate user actions - expanded list
    let actionKeywords = [
        "ui_button_tap", "button_tap", "BUTTON_TAPPED", "click", "tap", "action", "event",
        "NOTE_OPENED", "FONT_FAMILY_CHANGED", "FONT_SIZE_CHANGED", "BACKGROUND_COLOR_CHANGED", 
        "NOTE_MODE_CHANGED", "AFFIRMATION_REFRESH_INTERVAL_CHANGED", "TEXT_ALIGNMENT_CHANGED",
        "SETTING_SORTING_OPTION_CHANGED", "NOTE_SELECTED_IN_MODE", "onboarding_enter",
        "app_version_update", "paywall_show", "paywall_exit", "NOTE_UPDATED", "SAVE_NOTE", 
        "CREATE_NOTE"
    ]
    
    // Keywords that indicate session end
    let sessionEndKeywords = ["app_close", "session_end", "app_background"]
    
    // Common parameter names for screen identification
    let screenParamNames = ["name", "screen", "screen_name", "view", "page"]
    
    // Common parameter names for action identification
    let actionParamNames = ["name", "action", "event", "button", "type"]
    
    // Minimum duration for screens (in seconds) to avoid 0s displays
    let minimumScreenDuration: TimeInterval = 0.1
    
    // Categories to process - only analytics events
    let allowedCategories = ["analytics"]
}

// MARK: - Parser

class PrettyLogParser {
    private let dateFormatter: DateFormatter
    private var sessions: [Session] = []
    private var currentSessionIndex: Int?
    private let config = EventConfig()
    private var processedEventIds: Set<String> = []
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    }
    
    func parse(_ logContent: String) -> [Session] {
        let lines = logContent.components(separatedBy: .newlines)
        
        // Reset state
        sessions = []
        currentSessionIndex = nil
        processedEventIds = []
        
        for line in lines {
            // Check for session separator
            if line.contains("-- ** ** ** --") || line.contains("===") || line.contains("***") {
                finalizeCurrentSession()
                continue
            }
            
            if let entry = parseLogLine(line) {
                processLogEntry(entry)
            }
        }
        
        // Close final session
        finalizeCurrentSession()
        
        return sessions
    }
    
    private func parseLogLine(_ line: String) -> LogEntry? {
        // Skip empty lines and non-log lines
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
              line.contains("[") && line.contains("]") else {
            return nil
        }
        
        // More flexible patterns to handle different log formats
        let patterns = [
            // Main pattern: 2025-10-24T14:45:37+0300 info [category] : message
            #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4})\s+(\w+)\s+\[([^\]]+)\]\s+:\s+(.+)$"#,
            // Alternative pattern: timestamp level [category] message (no colon)  
            #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4})\s+(\w+)\s+\[([^\]]+)\]\s+(.+)$"#,
            // Simpler pattern: just timestamp and message with brackets
            #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}).*\[([^\]]+)\].*?:\s*(.+)$"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }
            
            let timestampStr = String(line[Range(match.range(at: 1), in: line)!])
            let level = match.numberOfRanges > 2 ? String(line[Range(match.range(at: 2), in: line)!]) : "info"
            let category = String(line[Range(match.range(at: match.numberOfRanges - 2), in: line)!])
            let message = String(line[Range(match.range(at: match.numberOfRanges - 1), in: line)!])
            
            guard let timestamp = parseTimestamp(timestampStr) else {
                continue
            }
            
            let params = extractParams(from: message)
            
            return LogEntry(timestamp: timestamp, level: level, category: category, message: message, params: params)
        }
        
        return nil
    }
    
    private func parseTimestamp(_ str: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss",
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
        
        // Pattern for key:value or key=value, including quoted values
        let patterns = [
            #"(\w+):([^,\s\]]+)"#,
            #"(\w+)=([^,\s\]]+)"#,
            #"(\w+):\s*'([^']*?)'"#,
            #"(\w+)=\s*'([^']*?)'"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: message, range: NSRange(message.startIndex..., in: message))
            
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: message),
                   let valueRange = Range(match.range(at: 2), in: message) {
                    let key = String(message[keyRange])
                    let value = String(message[valueRange])
                    params[key] = value
                }
            }
        }
        
        return params
    }
    
    private func processLogEntry(_ entry: LogEntry) {
        // More flexible category filtering - check if category contains any allowed category
        let categoryLower = entry.category.lowercased()
        let isAllowedCategory = config.allowedCategories.contains { allowedCategory in
            categoryLower.contains(allowedCategory.lowercased())
        }
        
        if !isAllowedCategory {
            return
        }
        
        // Skip adaptor confirmation lines - we only want the original sendEvent lines
        if entry.message.contains("Adaptor:") && entry.message.contains("has logged event:") {
            return
        }
        
        // Skip other adaptor/system messages
        if entry.message.contains("Adaptor:") && (
            entry.message.contains("has been started") ||
            entry.message.contains("Starting with install type") ||
            entry.message.contains("Skipping Configuring") ||
            entry.message.contains("setUserProperty:")
        ) {
            return
        }
        
        // Create unique event ID to prevent duplicates
        let eventId = "\(entry.timestamp.timeIntervalSince1970)_\(entry.message.hashValue)"
        if processedEventIds.contains(eventId) {
            return
        }
        processedEventIds.insert(eventId)
        
        // Start new session only if no current session exists
        if isSessionStart(entry) && currentSessionIndex == nil {
            startNewSession(entry)
            return
        }
        
        // Auto-create session if none exists and we see important activity
        if currentSessionIndex == nil && (isScreenView(entry) || isUserAction(entry)) {
            // Create a synthetic session start
            let syntheticEntry = LogEntry(
                timestamp: entry.timestamp.addingTimeInterval(-1), 
                level: entry.level, 
                category: entry.category, 
                message: "App launched (inferred)", 
                params: [:]
            )
            startNewSession(syntheticEntry)
        }
        
        guard let idx = currentSessionIndex else { return }
        
        // Track screen views
        if isScreenView(entry) {
            if let screenName = extractScreenName(entry) {
                addScreenVisit(sessionIndex: idx, screenName: screenName, timestamp: entry.timestamp)
            }
        }
        
        // Track user actions (but skip duplicate screen views)
        if isUserAction(entry) && !isScreenView(entry) {
            addUserAction(sessionIndex: idx, entry: entry)
        }
        
        // Track session end
        if isSessionEnd(entry) {
            sessions[idx].endTime = entry.timestamp
            currentSessionIndex = nil // Close the session
        }
    }
    
    private func startNewSession(_ entry: LogEntry) {
        // Finalize previous session
        finalizeCurrentSession()
        
        let launchCount = Int(entry.params["launchCount"] ?? entry.params["launch_count"] ?? "0") ?? (sessions.count + 1)
        var session = Session(sessionNumber: sessions.count + 1, startTime: entry.timestamp, launchCount: launchCount)
        
        // Extract any metadata
        session.metadata = extractSessionMetadata(entry)
        
        sessions.append(session)
        currentSessionIndex = sessions.count - 1
    }
    
    private func finalizeCurrentSession() {
        if let idx = currentSessionIndex {
            if sessions[idx].endTime == nil {
                let lastScreenTime = sessions[idx].screens.last?.exitTime ?? sessions[idx].screens.last?.entryTime
                sessions[idx].endTime = lastScreenTime ?? sessions[idx].startTime
            }
            
            // Ensure all screens have proper exit times and minimum durations
            for screenIdx in 0..<sessions[idx].screens.count {
                if sessions[idx].screens[screenIdx].exitTime == nil {
                    let entryTime = sessions[idx].screens[screenIdx].entryTime
                    let nextScreenTime = screenIdx < sessions[idx].screens.count - 1 
                        ? sessions[idx].screens[screenIdx + 1].entryTime
                        : sessions[idx].endTime ?? entryTime.addingTimeInterval(config.minimumScreenDuration)
                    
                    let duration = nextScreenTime.timeIntervalSince(entryTime)
                    let actualExitTime = duration < config.minimumScreenDuration 
                        ? entryTime.addingTimeInterval(config.minimumScreenDuration)
                        : nextScreenTime
                    
                    sessions[idx].screens[screenIdx].exitTime = actualExitTime
                }
            }
        }
        currentSessionIndex = nil
    }
    
    private func isSessionStart(_ entry: LogEntry) -> Bool {
        return config.sessionStartKeywords.contains { keyword in
            entry.message.contains(keyword)
        }
    }
    
    private func isScreenView(_ entry: LogEntry) -> Bool {
        // Only count original sendEvent lines for screen views
        if entry.message.contains("sendEvent: ui_view_show") {
            return true
        }
        
        return config.screenViewKeywords.contains { keyword in
            entry.message.contains(keyword) && !entry.message.contains("Adaptor:")
        }
    }
    
    private func isUserAction(_ entry: LogEntry) -> Bool {
        // Skip adaptor confirmation messages
        if entry.message.contains("Adaptor:") {
            return false
        }
        
        // Any sendEvent that isn't ui_view_show is considered a user action
        if entry.message.contains("sendEvent:") {
            // Extract event type to check if it's a screen view
            if let start = entry.message.range(of: "sendEvent: ") {
                let afterEvent = entry.message[start.upperBound...]
                if let comma = afterEvent.firstIndex(of: ",") {
                    let eventType = String(afterEvent[..<comma]).trimmingCharacters(in: .whitespaces)
                    
                    // Only exclude screen view events
                    if eventType == "ui_view_show" {
                        return false
                    }
                    
                    // Everything else is a user action
                    return true
                } else {
                    let eventType = String(afterEvent).trimmingCharacters(in: .whitespaces)
                    return eventType != "ui_view_show"
                }
            }
        }
        
        // Fallback to keyword checking for non-sendEvent patterns
        let isAction = config.actionKeywords.contains { keyword in
            entry.message.contains(keyword) && !entry.message.contains("Adaptor:")
        }
        
        return isAction
    }
    
    private func isSessionEnd(_ entry: LogEntry) -> Bool {
        return config.sessionEndKeywords.contains { keyword in
            entry.message.contains(keyword)
        }
    }
    
    private func extractScreenName(_ entry: LogEntry) -> String? {
        // Handle sendEvent: ui_view_show format
        if entry.message.contains("sendEvent: ui_view_show") {
            if let name = entry.params["name"] {
                return formatScreenName(name)
            }
            // Also check for type parameter for paywall screens
            if let type = entry.params["type"] {
                return formatScreenName("Paywall (\(type))")
            }
        }
        
        for paramName in config.screenParamNames {
            if let value = entry.params[paramName] {
                return formatScreenName(value)
            }
        }
        return nil
    }
    
    private func extractActionName(_ entry: LogEntry) -> String? {
        // Handle sendEvent: format
        if entry.message.contains("sendEvent:") {
            if let start = entry.message.range(of: "sendEvent: ") {
                let afterEvent = entry.message[start.upperBound...]
                if let comma = afterEvent.firstIndex(of: ",") {
                    let eventType = String(afterEvent[..<comma]).trimmingCharacters(in: .whitespaces)
                    
                    // For BUTTON_TAPPED events, try to get the specific button name
                    if eventType == "BUTTON_TAPPED", let buttonName = entry.params["button"] {
                        return buttonName
                    }
                    
                    return eventType
                } else {
                    return String(afterEvent).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // First try standard param names
        for paramName in config.actionParamNames {
            if let value = entry.params[paramName] {
                return value
            }
        }
        
        // Try button parameter for BUTTON_TAPPED events
        if entry.message.contains("BUTTON_TAPPED"), let buttonName = entry.params["button"] {
            return buttonName
        }
        
        return nil
    }
    
    private func extractSessionMetadata(_ entry: LogEntry) -> [String: String] {
        var metadata: [String: String] = [:]
        
        let interestingKeys = ["version", "app_version", "build", "os_version", "device", "platform", "to_version", "to_build"]
        for key in interestingKeys {
            if let value = entry.params[key] {
                metadata[key] = value
            }
        }
        
        return metadata
    }
    
    private func addScreenVisit(sessionIndex: Int, screenName: String, timestamp: Date) {
        let formattedName = formatScreenName(screenName)
        
        // Check for exact duplicate screens (same name within short time window)
        if let lastScreen = sessions[sessionIndex].screens.last,
           lastScreen.screenName == formattedName {
            let timeSinceLastScreen = timestamp.timeIntervalSince(lastScreen.entryTime)
            if timeSinceLastScreen < 2.0 { // Less than 2 seconds, likely duplicate
                return
            }
        }
        
        // Also check if this screen name already exists in the session (avoid false back-navigation)
        let existingScreens = sessions[sessionIndex].screens.map { $0.screenName }
        if existingScreens.contains(formattedName) {
            // If it's a return to a previous screen, check if it makes logical sense
            if let lastScreen = sessions[sessionIndex].screens.last,
               let lastIndex = existingScreens.lastIndex(of: formattedName) {
                let timeSinceLastOccurrence = timestamp.timeIntervalSince(sessions[sessionIndex].screens[lastIndex].entryTime)
                
                // Only allow return to previous screen if enough time has passed (> 10 seconds)
                // or if it's a legitimate navigation pattern
                if timeSinceLastOccurrence < 10.0 && !isLegitimateNavigation(from: lastScreen.screenName, to: formattedName) {
                    return
                }
            }
        }
        
        // Close previous screen with proper timing and minimum duration
        if !sessions[sessionIndex].screens.isEmpty {
            let lastIdx = sessions[sessionIndex].screens.count - 1
            let lastScreen = sessions[sessionIndex].screens[lastIdx]
            let duration = timestamp.timeIntervalSince(lastScreen.entryTime)
            
            // Ensure minimum duration
            let actualExitTime = duration < config.minimumScreenDuration 
                ? lastScreen.entryTime.addingTimeInterval(config.minimumScreenDuration)
                : timestamp
            
            sessions[sessionIndex].screens[lastIdx].exitTime = actualExitTime
        }
        
        // Add new screen
        let visit = ScreenVisit(screenName: formattedName, entryTime: timestamp)
        sessions[sessionIndex].screens.append(visit)
    }
    
    /// Check if navigation from one screen to another is legitimate
    private func isLegitimateNavigation(from: String, to: String) -> Bool {
        // Define legitimate navigation patterns
        let legitimatePatterns: [(from: String, to: String)] = [
            ("Dashboard", "Settings"),
            ("Settings", "Dashboard"),
            ("Create Note", "Dashboard"),
            ("Paywall", "Dashboard"),
            ("Onboarding Premium", "Paywall"),
            ("Paywall", "Onboarding Premium")
        ]
        
        return legitimatePatterns.contains { pattern in
            from.lowercased().contains(pattern.from.lowercased()) && 
            to.lowercased().contains(pattern.to.lowercased())
        }
    }
    
    private func addUserAction(sessionIndex: Int, entry: LogEntry) {
        // If no screens exist, create a generic one
        if sessions[sessionIndex].screens.isEmpty {
            let visit = ScreenVisit(screenName: "App", entryTime: entry.timestamp)
            sessions[sessionIndex].screens.append(visit)
        }
        
        let screenIdx = sessions[sessionIndex].screens.count - 1
        let currentScreenName = sessions[sessionIndex].screens[screenIdx].screenName
        let actionName = extractActionName(entry) ?? extractEventTypeFromMessage(entry.message)
        
        // Determine action type from message content
        let actionType = categorizeAction(entry)
        
        // Format details with current screen context for comparison
        let details = formatActionDetails(actionName, entry: entry, currentScreen: currentScreenName)
        
        let action = UserAction(timestamp: entry.timestamp, actionType: actionType, details: details, rawEvent: actionName)
        sessions[sessionIndex].screens[screenIdx].actions.append(action)
    }
    
    private func extractEventTypeFromMessage(_ message: String) -> String {
        if message.contains("sendEvent:") {
            if let start = message.range(of: "sendEvent: ") {
                let afterEvent = message[start.upperBound...]
                if let comma = afterEvent.firstIndex(of: ",") {
                    return String(afterEvent[..<comma]).trimmingCharacters(in: .whitespaces)
                } else {
                    return String(afterEvent).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Extract from direct event mentions - expanded list
        let events = [
            "NOTE_OPENED", "NOTE_MODE_CHANGED", "FONT_FAMILY_CHANGED", 
            "FONT_SIZE_CHANGED", "BACKGROUND_COLOR_CHANGED", "AFFIRMATION_REFRESH_INTERVAL_CHANGED",
            "TEXT_ALIGNMENT_CHANGED", "SETTING_SORTING_OPTION_CHANGED", "NOTE_SELECTED_IN_MODE",
            "ui_button_tap", "paywall_show", "paywall_exit", "NOTE_UPDATED", "BUTTON_TAPPED",
            "onboarding_enter", "app_version_update"
        ]
        
        for event in events {
            if message.contains(event) {
                return event
            }
        }
        
        // Check for logged event patterns
        if message.contains("has logged event:") {
            let pattern = #"has logged event: '([^']+)'"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) {
                if let range = Range(match.range(at: 1), in: message) {
                    return String(message[range])
                }
            }
        }
        
        return "Unknown Action"
    }
    
    private func categorizeAction(_ entry: LogEntry) -> String {
        let msg = entry.message.lowercased()
        
        // Check for button-related events first (more specific)
        if msg.contains("button") || msg.contains("tap") {
            return "👆"
        }
        
        // Check for toggle events
        if msg.contains("toggle") {
            return "🔄"
        }
        
        // Check for note-related events
        if msg.contains("note_opened") || msg.contains("note_selected") {
            return "👁️"
        }
        
        // Check for styling events
        if msg.contains("font") || msg.contains("color") || msg.contains("alignment") || msg.contains("style") {
            return "🎨"
        }
        
        // Check for affirmation events
        if msg.contains("affirmation") {
            return "✨"
        }
        
        // Check for paywall events
        if msg.contains("paywall") {
            return "💳"
        }
        
        // Check for save/update events
        if msg.contains("save") || msg.contains("update") {
            return "💾"
        }
        
        // Check for create/add events
        if msg.contains("create") || msg.contains("add") {
            return "➕"
        }
        
        // Check for delete/remove events
        if msg.contains("delete") || msg.contains("remove") {
            return "🗑️"
        }
        
        // Check for settings events
        if msg.contains("settings") || msg.contains("setting") {
            return "⚙️"
        }
        
        // Check for share events
        if msg.contains("share") {
            return "📤"
        }
        
        // Check for onboarding events
        if msg.contains("onboarding") {
            return "🚀"
        }
        
        // Check for version/update events
        if msg.contains("version") || msg.contains("app_") {
            return "🔄"
        }
        
        // Check for premium/subscription events
        if msg.contains("premium") || msg.contains("subscription") {
            return "💎"
        }
        
        // Default for unknown events
        return "⚡"
    }
    
    private func formatActionDetails(_ action: String, entry: LogEntry, currentScreen: String? = nil) -> String {
        // Extract the event name from sendEvent format
        var eventName = action
        if entry.message.contains("sendEvent:") {
            if let start = entry.message.range(of: "sendEvent: ") {
                let afterEvent = entry.message[start.upperBound...]
                if let comma = afterEvent.firstIndex(of: ",") {
                    eventName = String(afterEvent[..<comma]).trimmingCharacters(in: .whitespaces)
                } else {
                    eventName = String(afterEvent).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        var details = formatScreenName(eventName)
        var additionalInfo: [String] = []
        
        // Special handling for different event types
        
        // Button events
        if eventName.lowercased().contains("button") || eventName == "ui_button_tap" {
            if let buttonName = entry.params["name"] ?? entry.params["button"] {
                details = formatScreenName(buttonName)
            }
        }
        // Toggle events  
        else if eventName.lowercased().contains("toggle") {
            if let newValue = entry.params["newValue"] ?? entry.params["value"] {
                additionalInfo.append("→ \(newValue.capitalized)")
            }
        }
        // Premium/subscription events
        else if eventName.lowercased().contains("premium") || eventName.lowercased().contains("is_premium") {
            if let newValue = entry.params["newValue"] ?? entry.params["value"] {
                additionalInfo.append("→ \(newValue.capitalized)")
            }
        }
        
        // Only add screen context if it's different from current screen
        if let viewName = entry.params["view_name"],
           let currentScreen = currentScreen,
           formatScreenName(viewName).lowercased() != currentScreen.lowercased() {
            additionalInfo.append("on \(formatScreenName(viewName))")
        }
        
        // Add all other meaningful parameters
        let commonKeys = ["name", "button", "view_name", "newValue", "value"]
        let excludedKeys = Set(commonKeys + ["timeDelta"]) // Exclude timing info
        
        for (key, value) in entry.params.sorted(by: { $0.key < $1.key }) {
            if !excludedKeys.contains(key) && !value.isEmpty && value != "nil" {
                let formattedKey = formatScreenName(key)
                let formattedValue = formatScreenName(value)
                additionalInfo.append("\(formattedKey): \(formattedValue)")
            }
        }
        
        // Join everything together
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
        📊 SESSION ANALYTICS
        ══════════════════════════
        
        """
        
        if sessions.isEmpty {
            report += "No sessions found.\n"
            return report
        }
        
        report += "📈 SUMMARY\n"
        report += "──────────\n"
        report += "Sessions: \(sessions.count)\n"
        report += generateSummary(sessions: sessions)
        report += "\n\n"
        
        for (index, session) in sessions.enumerated() {
            report += generateSessionReport(session, isLast: index == sessions.count - 1)
            if index < sessions.count - 1 {
                report += "\n"
            }
        }
        
        return report
    }
    
    private func generateSummary(sessions: [Session]) -> String {
        let validSessions = sessions.filter { $0.duration > 0 }
        let totalDuration = validSessions.reduce(0.0) { $0 + $1.duration }
        let avgDuration = validSessions.isEmpty ? 0.0 : totalDuration / Double(validSessions.count)
        
        let totalScreens = sessions.reduce(0) { $0 + $1.screens.count }
        let avgScreens = Double(totalScreens) / Double(sessions.count)
        
        let mins = Int(avgDuration) / 60
        let secs = avgDuration.truncatingRemainder(dividingBy: 60)
        let avgFormatted: String
        
        if mins > 0 {
            avgFormatted = "\(mins)m \(String(format: "%.1f", secs))s"
        } else if avgDuration >= 10 {
            avgFormatted = "\(String(format: "%.0f", avgDuration))s"
        } else if avgDuration >= 1 {
            avgFormatted = "\(String(format: "%.1f", avgDuration))s"
        } else {
            avgFormatted = "\(String(format: "%.2f", avgDuration))s"
        }
        
        return """
        Avg Duration: \(avgFormatted)
        Avg Screens: \(String(format: "%.1f", avgScreens))
        """
    }
    
    private func generateSessionReport(_ session: Session, isLast: Bool) -> String {
        var report = """
        🎯 SESSION #\(session.sessionNumber)
        ────────────────────
        Started: \(formatTime(session.startTime))
        Duration: \(session.durationFormatted)
        """
        
        if session.launchCount > 0 {
            report += "\nLaunch: #\(session.launchCount)"
        }
        
        if !session.metadata.isEmpty {
            for (key, value) in session.metadata.sorted(by: { $0.key < $1.key }) {
                let formattedKey = key.replacingOccurrences(of: "_", with: " ").capitalized
                report += "\n\(formattedKey): \(value)"
            }
        }
        
        report += "\n\n"
        
        if session.screens.isEmpty {
            report += "No screen activity.\n"
            if !isLast {
                report += "\n" + String(repeating: "═", count: 30) + "\n"
            }
            return report
        }
        
        report += "📱 USER JOURNEY\n"
        report += String(repeating: "─", count: 15) + "\n\n"
        
        for (index, screen) in session.screens.enumerated() {
            report += "\(index + 1). \(screen.screenName)\n"
            report += "   ⏱ \(screen.durationFormatted)\n"
            
            if !screen.actions.isEmpty {
                report += "   📍 Actions (\(screen.actions.count)):\n"
                
                // Group similar actions but preserve order and details
                let groupedActions = groupActionsPreservingDetails(screen.actions)
                
                for actionGroup in groupedActions {
                    if actionGroup.count == 1 {
                        let action = actionGroup[0]
                        report += "     \(action.actionType) \(action.details)\n"
                    } else {
                        // Group identical actions with count
                        let uniqueActions = Dictionary(grouping: actionGroup) { $0.details }
                        
                        for (detail, actions) in uniqueActions.sorted(by: { $0.key < $1.key }) {
                            let icon = actions.first?.actionType ?? "•"
                            if actions.count > 1 {
                                report += "     \(icon) \(detail) ×\(actions.count)\n"
                            } else {
                                report += "     \(icon) \(detail)\n"
                            }
                        }
                    }
                }
            }
            
            if index < session.screens.count - 1 {
                report += "\n"
            }
        }
        
        if !isLast {
            report += "\n\n" + String(repeating: "═", count: 30) + "\n"
        }
        
        return report
    }
    
    private func groupActionsPreservingDetails(_ actions: [UserAction]) -> [[UserAction]] {
        var result: [[UserAction]] = []
        var currentGroup: [UserAction] = []
        var lastActionType = ""
        
        for action in actions {
            if action.actionType == lastActionType && !currentGroup.isEmpty {
                currentGroup.append(action)
            } else {
                if !currentGroup.isEmpty {
                    result.append(currentGroup)
                }
                currentGroup = [action]
                lastActionType = action.actionType
            }
        }
        
        if !currentGroup.isEmpty {
            result.append(currentGroup)
        }
        
        return result
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}