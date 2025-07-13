//
//  ContentView.swift
//  DrinkTender Watch App
//
//  Created by Jeff Trespalacios on 6/28/25.
//

import SwiftUI
import WidgetKit
import UserNotifications

// MARK: - Data Model
class DrinkTimerModel: ObservableObject {
    @Published var lastDrinkTime: Date?
    @Published var delayMinutes: Int = 60 // Default 1 hour delay
    @Published var canDrink: Bool = true
    @Published var notificationsEnabled: Bool = true
    @Published var drinkCount: Int = 0

    private let userDefaults = UserDefaults.standard
    private let lastDrinkKey = "lastDrinkTime"
    private let delayKey = "delayMinutes"
    private let notificationsKey = "notificationsEnabled"
    private let drinkCountKey = "drinkCount"
    private let notificationIdentifier = "DrinkTimerNotification"

    init() {
        loadData()
        updateCanDrinkStatus()
        requestNotificationPermission()
    }

    func recordDrink() {
        lastDrinkTime = Date()
        canDrink = false
        drinkCount += 1
        
        // Save data immediately and force sync
        saveDataWithSync()
        
        // Force immediate widget update
        scheduleComplicationUpdate()
        
        // Schedule notification for when next drink is available
        if notificationsEnabled {
            scheduleNotification()
        }

        // Schedule next drink availability check
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(delayMinutes * 60)) {
            self.updateCanDrinkStatus()
        }
    }
    
    func resetDrinkCount() {
        drinkCount = 0
        saveDataWithSync()
        scheduleComplicationUpdate()
    }

    func updateCanDrinkStatus() {
        guard let lastDrink = lastDrinkTime else {
            canDrink = true
            scheduleComplicationUpdate()
            return
        }

        let timeSinceLastDrink = Date().timeIntervalSince(lastDrink)
        let newCanDrink = timeSinceLastDrink >= TimeInterval(delayMinutes * 60)
        
        if newCanDrink != canDrink {
            canDrink = newCanDrink
            scheduleComplicationUpdate()
        }
    }

    func timeUntilNextDrink() -> TimeInterval {
        guard let lastDrink = lastDrinkTime, !canDrink else { return 0 }

        let delayInterval = TimeInterval(delayMinutes * 60)
        let nextDrinkTime = lastDrink.addingTimeInterval(delayInterval)
        return max(0, nextDrinkTime.timeIntervalSinceNow)
    }

    func formattedTimeUntilNext() -> String {
        let timeRemaining = timeUntilNextDrink()

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

    private func saveData() {
        if let lastDrink = lastDrinkTime {
            userDefaults.set(lastDrink, forKey: lastDrinkKey)
        }
        userDefaults.set(delayMinutes, forKey: delayKey)
        userDefaults.set(notificationsEnabled, forKey: notificationsKey)
        userDefaults.set(drinkCount, forKey: drinkCountKey)
    }
    
    private func saveDataWithSync() {
        saveData()
        
        // Force synchronization to ensure widgets get updated data immediately
        DispatchQueue.global(qos: .userInitiated).async {
            self.userDefaults.synchronize()
            
            // Update widgets after a brief delay to ensure data is saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scheduleComplicationUpdate()
            }
        }
    }

    private func loadData() {
        if let savedDate = userDefaults.object(forKey: lastDrinkKey) as? Date {
            lastDrinkTime = savedDate
        }
        delayMinutes = userDefaults.integer(forKey: delayKey)
        if delayMinutes == 0 { delayMinutes = 60 } // Default fallback
        
        notificationsEnabled = userDefaults.bool(forKey: notificationsKey)
        // Default to true if not set
        if userDefaults.object(forKey: notificationsKey) == nil {
            notificationsEnabled = true
        }
        
        drinkCount = userDefaults.integer(forKey: drinkCountKey)
    }

    private func scheduleComplicationUpdate() {
        // Reload all widget timelines immediately
        WidgetCenter.shared.reloadAllTimelines()
        
        // Also reload specific widget kinds for more targeted updates
        WidgetCenter.shared.reloadTimelines(ofKind: "DrinkTimerWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DrinkTimerRectangularWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DrinkTimerLargeWidget")
    }
    
    // MARK: - Notification Methods
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationsEnabled = granted
                self.saveData()
            }
            
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleNotification() {
        // Cancel any existing notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        
        guard let lastDrink = lastDrinkTime else { return }
        
        let nextDrinkTime = lastDrink.addingTimeInterval(TimeInterval(delayMinutes * 60))
        let timeInterval = nextDrinkTime.timeIntervalSinceNow
        
        // Only schedule if the time is in the future
        guard timeInterval > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Drink Timer"
        content.body = "Ready for your next drink! 🥤"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleNotifications() {
        if notificationsEnabled {
            // Disable notifications
            notificationsEnabled = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        } else {
            // Request permission and enable
            requestNotificationPermission()
        }
        saveDataWithSync()
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var drinkTimer: DrinkTimerModel
    @State private var currentPage = 0
    @State private var showingConfirmation = false
    
    private let delayOptions = [15, 30, 45, 60, 90, 120, 180, 240] // Minutes
    
    var body: some View {
        VStack(spacing: 0) {
            // Page Content
            TabView(selection: $currentPage) {
                // Main Timer Screen
                mainScreen()
                    .tag(0)
                
                // Settings Screen
                settingsScreen()
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        }
        .onAppear {
            drinkTimer.updateCanDrinkStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSExtensionHostWillEnterForeground)
        ) { _ in
            // Update status when app becomes active
            drinkTimer.updateCanDrinkStatus()
        }
    }
    
    @ViewBuilder
    private func mainScreen() -> some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Main Circular Interface
                ZStack {
                    // Background Circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 160, height: 160)
                    
                    // Progress Circle
                    Circle()
                        .trim(from: 0, to: progressValue())
                        .stroke(
                            drinkTimer.canDrink ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progressValue())
                    
                    // Center Button - Acts as Status Indicator
                    Button(action: {
                        if drinkTimer.canDrink {
                            drinkTimer.recordDrink()
                        } else {
                            // Show confirmation dialog when timer is running
                            showingConfirmation = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(buttonColor())
                                .frame(width: 120, height: 120)
                            
                            VStack(spacing: 8) {
                                Image(systemName: buttonIcon())
                                    .font(.title)
                                    .foregroundColor(.white)
                                
                                if !drinkTimer.canDrink {
                                    Text(drinkTimer.formattedTimeUntilNext())
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .scaleEffect(drinkTimer.canDrink ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: drinkTimer.canDrink)
                }
                
                Spacer()
            }
        }
        .alert("Record Another Drink?", isPresented: $showingConfirmation) {
            Button("Yes") {
                drinkTimer.recordDrink()
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("This will reset your timer and count another drink.")
        }
    }
    
    @ViewBuilder
    private func settingsScreen() -> some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                // Settings Content
                List {
                    Section("Notifications") {
                        HStack {
                            Text("Alert when ready")
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: $drinkTimer.notificationsEnabled)
                                .onChange(of: drinkTimer.notificationsEnabled) { (_, _) in
                                    drinkTimer.toggleNotifications()
                                }
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.2))
                    
                    Section("Delay Between Drinks") {
                        ForEach(delayOptions, id: \.self) { minutes in
                            HStack {
                                Text(formatDelayTime(minutes))
                                    .foregroundColor(.white)
                                Spacer()
                                if drinkTimer.delayMinutes == minutes {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                drinkTimer.delayMinutes = minutes
                                drinkTimer.updateCanDrinkStatus()
                            }
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.2))

                    Section("Current Status") {
                        HStack {
                            Text("Today's Drinks:")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(drinkTimer.drinkCount)")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        
                        if let lastDrink = drinkTimer.lastDrinkTime {
                            HStack {
                                Text("Last Drink:")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(lastDrink, style: .time)
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack {
                            Text("Next Available:")
                                .foregroundColor(.white)
                            Spacer()
                            Text(drinkTimer.canDrink ? "Now" : drinkTimer.formattedTimeUntilNext())
                                .foregroundColor(drinkTimer.canDrink ? .green : .orange)
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.2))

                    Section {
                        Button("Reset Timer") {
                            drinkTimer.lastDrinkTime = nil
                            drinkTimer.canDrink = true
                            // Cancel any pending notifications
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["DrinkTimerNotification"])
                            // Force widget update
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                        .foregroundColor(.red)
                        
                        Button("Reset Drink Count") {
                            drinkTimer.resetDrinkCount()
                        }
                        .foregroundColor(.orange)
                    }
                    .listRowBackground(Color.gray.opacity(0.2))
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
    }
    
    // Calculate progress for the countdown circle
    private func progressValue() -> Double {
        guard let lastDrink = drinkTimer.lastDrinkTime else { return 1.0 }
        
        if drinkTimer.canDrink {
            return 1.0 // Full circle when ready
        }
        
        let totalDelayTime = TimeInterval(drinkTimer.delayMinutes * 60)
        let timeSinceLastDrink = Date().timeIntervalSince(lastDrink)
        let progress = timeSinceLastDrink / totalDelayTime
        
        return min(max(progress, 0.0), 1.0)
    }
    
    // Button color based on state
    private func buttonColor() -> Color {
        if drinkTimer.canDrink {
            return .green
        } else {
            return .orange
        }
    }
    
    // Button icon based on state
    private func buttonIcon() -> String {
        if drinkTimer.canDrink {
            return "plus.circle.fill"
        } else {
            return "clock.fill"
        }
    }
    
    private func formatDelayTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DrinkTimerModel())
    }
}
