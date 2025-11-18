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
//  PrettyLogParser.swift
//  TADebugTools
//
//  Created by Robert Tataru on 24.10.2025.
//

import Foundation

// MARK: - Configuration

struct EventConfig {
    // Generic keywords that indicate session start (pattern-based)
    let sessionStartKeywords = [
        "app_launch", "app launch", "session_start", "launch completed",
        "app started", "application started", "bootstrap", "initialization complete"
    ]
    
    // Generic keywords that indicate screen views
    let screenViewKeywords = [
        "ui_view_show", "screen_view", "view_show", "page_view", "screen_displayed",
        "view_appeared", "screen_appeared", "navigate_to", "open_screen"
    ]
    
    // Generic keywords that indicate user actions (removed app-specific ones)
    let actionKeywords = [
        "ui_button_tap", "button_tap", "button_tapped", "click", "tap", "press",
        "action", "event", "interaction", "user_action", "gesture",
        "swipe", "scroll", "select", "toggle", "change", "update",
        "create", "delete", "save", "share", "refresh", "search"
    ]
    
    // Keywords that indicate session end
    let sessionEndKeywords = [
        "app_close", "session_end", "app_background", "app_terminated",
        "application_will_terminate", "session_ended"
    ]
    
    // Common parameter names for screen identification
    let screenParamNames = ["name", "screen", "screen_name", "view", "page", "view_name"]
    
    // Common parameter names for action identification
    let actionParamNames = [
        "name", "action", "event", "button", "type", "event_name",
        "eventName", "event_type", "identifier", "title", "label"
    ]
    
    // Minimum duration for screens (in seconds) to avoid 0s displays
    let minimumScreenDuration: TimeInterval = 0.1
    
    // Categories to process - look for analytics-related categories
    let allowedCategories = ["analytics", "tracking", "events", "metrics"]
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
        let messageLower = entry.message.lowercased()
        
        // Check both category and message content for analytics-related content
        let isAllowedCategory = config.allowedCategories.contains { allowedCategory in
            categoryLower.contains(allowedCategory.lowercased())
        }
        
        // Also allow entries from main category if they contain session or analytics keywords
        let isRelevantMainEntry = categoryLower.contains("main") && (
            isSessionStart(entry) || isSessionEnd(entry) ||
            messageLower.contains("launch") || messageLower.contains("premium status") ||
            messageLower.contains("app") || messageLower.contains("session")
        )
        
        if !isAllowedCategory && !isRelevantMainEntry {
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
        let messageLower = entry.message.lowercased()
        return config.sessionStartKeywords.contains { keyword in
            messageLower.contains(keyword.lowercased())
        }
    }
    
    private func isScreenView(_ entry: LogEntry) -> Bool {
        // Only count original sendEvent lines for screen views
        if entry.message.contains("sendEvent: ui_view_show") || entry.message.contains("sendEvent: screen_view") {
            return true
        }
        
        let messageLower = entry.message.lowercased()
        return config.screenViewKeywords.contains { keyword in
            messageLower.contains(keyword.lowercased()) && !entry.message.contains("Adaptor:")
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
                    if eventType == "ui_view_show" || eventType == "screen_view" {
                        return false
                    }
                    
                    // Everything else is a user action
                    return true
                } else {
                    let eventType = String(afterEvent).trimmingCharacters(in: .whitespaces)
                    return eventType != "ui_view_show" && eventType != "screen_view"
                }
            }
        }
        
        // Fallback to generic keyword checking for non-sendEvent patterns
        let messageLower = entry.message.lowercased()
        let isAction = config.actionKeywords.contains { keyword in
            messageLower.contains(keyword.lowercased()) && !entry.message.contains("Adaptor:")
        }
        
        return isAction
    }
    
    private func isSessionEnd(_ entry: LogEntry) -> Bool {
        let messageLower = entry.message.lowercased()
        return config.sessionEndKeywords.contains { keyword in
            messageLower.contains(keyword.lowercased())
        }
    }
    
    private func extractScreenName(_ entry: LogEntry) -> String? {
        // Handle sendEvent: ui_view_show format
        if entry.message.contains("sendEvent: ui_view_show") || entry.message.contains("sendEvent: screen_view") {
            if let name = entry.params["name"] {
                return formatScreenName(name)
            }
            // Also check for type parameter for paywall screens
            if let type = entry.params["type"] {
                return formatScreenName("Paywall (\(type))")
            }
            // Check for secondary_view_name for modal/overlay screens
            if let secondaryView = entry.params["secondary_view_name"] {
                let primaryView = entry.params["name"] ?? "Screen"
                return formatScreenName("\(primaryView) > \(secondaryView)")
            }
        }
        
        for paramName in config.screenParamNames {
            if let value = entry.params[paramName] {
                return formatScreenName(value)
            }
        }
        return nil
    }
    
    private func extractEventTypeFromSendEvent(_ message: String) -> String {
        guard message.contains("sendEvent:") else {
            return "Unknown Action"
        }
        
        if let start = message.range(of: "sendEvent: ") {
            let afterEvent = message[start.upperBound...]
            if let comma = afterEvent.firstIndex(of: ",") {
                let eventType = String(afterEvent[..<comma]).trimmingCharacters(in: .whitespaces)
                return eventType.isEmpty ? "sendEvent" : eventType
            } else {
                let eventType = String(afterEvent).trimmingCharacters(in: .whitespaces)
                return eventType.isEmpty ? "sendEvent" : eventType
            }
        }
        
        return "sendEvent" // Fallback for sendEvent format
    }
    
    private func extractActionName(_ entry: LogEntry) -> String {
        // For sendEvent messages, always extract the event type
        if entry.message.contains("sendEvent:") {
            return extractEventTypeFromSendEvent(entry.message)
        }
        
        // Try standard param names for non-sendEvent messages
        for paramName in config.actionParamNames {
            if let value = entry.params[paramName] {
                return value
            }
        }
        
        // Check for logged event patterns (legacy support)
        if entry.message.contains("has logged event:") {
            let pattern = #"has logged event: '([^']+)'"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: entry.message, range: NSRange(entry.message.startIndex..., in: entry.message)) {
                if let range = Range(match.range(at: 1), in: entry.message) {
                    return String(entry.message[range])
                }
            }
        }

        if let propertyAction = extractUserPropertyActionName(entry) {
            return propertyAction
        }

        if let derivedName = deriveActionNameFromMessage(entry.message) {
            return derivedName
        }
        
        return "Unknown Action"
    }

    private func extractUserPropertyActionName(_ entry: LogEntry) -> String? {
        guard let propertyName = extractUserPropertyName(entry) else {
            return nil
        }
        let formattedProperty = formatScreenName(propertyName)
        return "Set User Property: \(formattedProperty)"
    }

    private func extractUserPropertyName(_ entry: LogEntry) -> String? {
        let propertyKeys = ["setuserproperty", "set_user_property", "property_name"]
        for key in propertyKeys {
            if let value = entry.params.first(where: { $0.key.lowercased() == key })?.value,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        
        guard entry.message.lowercased().contains("setuserproperty") else {
            return nil
        }
        
        let pattern = #"setuserproperty[^\w]*[:=]\s*([^,\n]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let range = NSRange(entry.message.startIndex..., in: entry.message)
        if let match = regex.firstMatch(in: entry.message, range: range),
           let propertyRange = Range(match.range(at: 1), in: entry.message) {
            var property = String(entry.message[propertyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let arrowRange = property.range(of: "->") {
                property = property[..<arrowRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if let commaRange = property.firstIndex(of: ",") {
                property = property[..<commaRange].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if !property.isEmpty {
                return property
            }
        }
        
        return nil
    }

    private func deriveActionNameFromMessage(_ message: String) -> String? {
        var trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }
        
        if let closingBracket = trimmedMessage.lastIndex(of: "]") {
            trimmedMessage = String(trimmedMessage[trimmedMessage.index(after: closingBracket)...])
        }
        
        trimmedMessage = trimmedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.hasPrefix(":") {
            trimmedMessage = String(trimmedMessage.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let lowered = trimmedMessage.lowercased()
        if lowered.hasPrefix("sendevent") || lowered.hasPrefix("has logged event") {
            return nil
        }
        
        let stopCharacters: [Character] = ["(", ","]
        if let stopIndex = trimmedMessage.firstIndex(where: { stopCharacters.contains($0) }) {
            trimmedMessage = String(trimmedMessage[..<stopIndex])
        }
        
        let whitespaceAndPunctuation = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        trimmedMessage = trimmedMessage.trimmingCharacters(in: whitespaceAndPunctuation)
        return trimmedMessage.isEmpty ? nil : trimmedMessage
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
                if timeSinceLastOccurrence < 10.0 {
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
    
    private func addUserAction(sessionIndex: Int, entry: LogEntry) {
        // If no screens exist, create a generic one
        if sessions[sessionIndex].screens.isEmpty {
            let visit = ScreenVisit(screenName: "App", entryTime: entry.timestamp)
            sessions[sessionIndex].screens.append(visit)
        }
        
        let screenIdx = sessions[sessionIndex].screens.count - 1
        let currentScreenName = sessions[sessionIndex].screens[screenIdx].screenName
        
        // Extract action name - for sendEvent this should NEVER be "Unknown Action"
        let actionName = extractActionName(entry)
        
        // Determine action type from message content
        let actionType = categorizeAction(entry)
        
        // Format details with current screen context
        let details = formatActionDetails(actionName, entry: entry, currentScreen: currentScreenName)
        
        let action = UserAction(timestamp: entry.timestamp, actionType: actionType, details: details, rawEvent: actionName)
        sessions[sessionIndex].screens[screenIdx].actions.append(action)
    }
    
    private func categorizeAction(_ entry: LogEntry) -> String {
        let msg = entry.message.lowercased()
        
        // Generic categorization based on common patterns
        
        // Check for button/tap events first (most common)
        if msg.contains("button") || msg.contains("tap") || msg.contains("click") || msg.contains("press") {
            return "👆"
        }
        
        // Check for toggle/switch events
        if msg.contains("toggle") || msg.contains("switch") || msg.contains("change") {
            return "🔄"
        }
        
        // Check for view/open events
        if msg.contains("view") || msg.contains("open") || msg.contains("show") || msg.contains("display") {
            return "👁️"
        }
        
        // Check for purchase/subscription events
        if msg.contains("purchase") || msg.contains("subscription") || msg.contains("paywall") || msg.contains("premium") {
            return "💳"
        }
        
        // Check for save/update events
        if msg.contains("save") || msg.contains("update") || msg.contains("modify") || msg.contains("edit") {
            return "💾"
        }
        
        // Check for create/add events
        if msg.contains("create") || msg.contains("add") || msg.contains("new") {
            return "➕"
        }
        
        // Check for delete/remove events
        if msg.contains("delete") || msg.contains("remove") || msg.contains("clear") {
            return "🗑️"
        }
        
        // Check for settings/configuration events
        if msg.contains("settings") || msg.contains("setting") || msg.contains("config") || msg.contains("preference") || msg.contains("property") || msg.contains("setuserproperty") {
            return "⚙️"
        }
        
        // Check for share/export events
        if msg.contains("share") || msg.contains("export") || msg.contains("send") {
            return "📤"
        }
        
        // Check for onboarding/tutorial events
        if msg.contains("onboarding") || msg.contains("tutorial") || msg.contains("intro") {
            return "🚀"
        }
        
        // Check for navigation events
        if msg.contains("navigate") || msg.contains("go_to") || msg.contains("back") {
            return "🧭"
        }
        
        // Check for search events
        if msg.contains("search") || msg.contains("filter") || msg.contains("find") {
            return "🔍"
        }
        
        // Check for refresh/reload events
        if msg.contains("refresh") || msg.contains("reload") || msg.contains("update") {
            return "🔄"
        }
        
        // Check for speed test events
        if msg.contains("speedtest") || msg.contains("speed") || msg.contains("test") {
            return "⚡"
        }
        
        // Check for VPN/connection events
        if msg.contains("vpn") || msg.contains("connect") || msg.contains("server") {
            return "🔐"
        }
        
        // Check for tutorial/engagement events
        if msg.contains("engagement") || msg.contains("completed") {
            return "✨"
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
        
        // Generic handling for different event types
        
        // Button events
        if eventName.lowercased().contains("button") || eventName == "ui_button_tap" {
            if let buttonName = entry.params["name"] ?? entry.params["button"] {
                details = formatScreenName(buttonName)
            }
        }
        // Any events with 'name' parameter
        else if let name = entry.params["name"] {
            details = formatScreenName(name)
        }
        
        // Look for value changes
        if let newValue = entry.params["newValue"] ?? entry.params["value"] ?? entry.params["to"] {
            additionalInfo.append("→ \(formatScreenName(newValue))")
        }
        
        // Look for 'from' values for transitions
        if let fromValue = entry.params["from"] ?? entry.params["previous"] {
            additionalInfo.append("from \(formatScreenName(fromValue))")
        }
        
        // Only add screen context if it's different from current screen
        if let viewName = entry.params["view_name"] ?? entry.params["screen"],
           let currentScreen = currentScreen,
           formatScreenName(viewName).lowercased() != currentScreen.lowercased() {
            additionalInfo.append("on \(formatScreenName(viewName))")
        }
        
        // Add other meaningful parameters (generic approach)
        let commonKeys = ["name", "button", "view_name", "screen", "newValue", "value", "to", "from", "previous", "detail"]
        let excludedKeys = Set(commonKeys + ["timeDelta", "timestamp", "setuserproperty", "set_user_property", "property_name"]) // Exclude timing info
        
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
