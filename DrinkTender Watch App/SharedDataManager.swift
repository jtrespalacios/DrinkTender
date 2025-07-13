//
//  SharedDataManager.swift
//  DrinkTender
//
//  Shared data manager for app and widget communication
//

import Foundation
import WidgetKit

class SharedDataManager {
    static let shared = SharedDataManager()
    
    // Use App Group for shared data between app and widget
    // You'll need to add an App Group capability to your project
    private let appGroupIdentifier = "group.co.j3p.DrinkTender"
    
    private var userDefaults: UserDefaults {
        return UserDefaults(suiteName: appGroupIdentifier)!
    }
    
    // MARK: - Keys
    private let lastDrinkKey = "lastDrinkTime"
    private let delayKey = "delayMinutes"
    private let notificationsKey = "notificationsEnabled"
    private let drinkCountKey = "drinkCount"
    private let lastUpdateKey = "lastUpdateTime"
    
    private init() {}
    
    // MARK: - Data Access
    
    var lastDrinkTime: Date? {
        get { userDefaults.object(forKey: lastDrinkKey) as? Date }
        set {
            userDefaults.set(newValue, forKey: lastDrinkKey)
            updateLastModified()
        }
    }
    
    var delayMinutes: Int {
        get { 
            let value = userDefaults.integer(forKey: delayKey)
            return value == 0 ? 60 : value
        }
        set { 
            userDefaults.set(newValue, forKey: delayKey)
            updateLastModified()
        }
    }
    
    var notificationsEnabled: Bool {
        get { 
            // Default to true if not set
            if userDefaults.object(forKey: notificationsKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: notificationsKey)
        }
        set { 
            userDefaults.set(newValue, forKey: notificationsKey)
            updateLastModified()
        }
    }
    
    var drinkCount: Int {
        get { userDefaults.integer(forKey: drinkCountKey) }
        set { 
            userDefaults.set(newValue, forKey: drinkCountKey)
            updateLastModified()
        }
    }
    
    var lastUpdateTime: Date? {
        get { userDefaults.object(forKey: lastUpdateKey) as? Date }
    }
    
    // MARK: - Computed Properties
    
    var canDrink: Bool {
        guard let lastDrink = lastDrinkTime else { return true }
        let timeSinceLastDrink = Date().timeIntervalSince(lastDrink)
        return timeSinceLastDrink >= TimeInterval(delayMinutes * 60)
    }
    
    var timeUntilNextDrink: TimeInterval {
        guard let lastDrink = lastDrinkTime, !canDrink else { return 0 }
        let delayInterval = TimeInterval(delayMinutes * 60)
        let nextDrinkTime = lastDrink.addingTimeInterval(delayInterval)
        return max(0, nextDrinkTime.timeIntervalSinceNow)
    }
    
    var formattedTimeUntilNext: String {
        let timeRemaining = timeUntilNextDrink
        
        if timeRemaining <= 0 {
            return "Ready!"
        }
        
        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Actions
    
    func recordDrink() {
        lastDrinkTime = Date()
        drinkCount += 1
        synchronizeAndUpdateWidgets()
    }
    
    func resetTimer() {
        lastDrinkTime = nil
        synchronizeAndUpdateWidgets()
    }
    
    func resetDrinkCount() {
        drinkCount = 0
        synchronizeAndUpdateWidgets()
    }
    
    func updateDelayMinutes(_ minutes: Int) {
        delayMinutes = minutes
        synchronizeAndUpdateWidgets()
    }
    
    // MARK: - Private Methods
    
    private func updateLastModified() {
        userDefaults.set(Date(), forKey: lastUpdateKey)
    }
    
    private func synchronizeAndUpdateWidgets() {
        // Force synchronization
        userDefaults.synchronize()
        
        // Update widgets after a brief delay to ensure data is written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Widget Data Extension
extension SharedDataManager {
    
    /// Get all data needed for widget display
    func getWidgetData() -> (lastDrinkTime: Date?, delayMinutes: Int, canDrink: Bool, drinkCount: Int, formattedTimeUntilNext: String) {
        return (
            lastDrinkTime: lastDrinkTime,
            delayMinutes: delayMinutes,
            canDrink: canDrink,
            drinkCount: drinkCount,
            formattedTimeUntilNext: formattedTimeUntilNext
        )
    }
}
