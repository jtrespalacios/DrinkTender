//
//  ContentView.swift
//  DrinkTender Watch App
//
//  Created by Jeff Trespalacios on 6/28/25.
//

import SwiftUI
import WidgetKit
import ClockKit

// MARK: - Data Model
class DrinkTimerModel: ObservableObject {
    @Published var lastDrinkTime: Date?
    @Published var delayMinutes: Int = 60 // Default 1 hour delay
    @Published var canDrink: Bool = true

    private let userDefaults = UserDefaults.standard
    private let lastDrinkKey = "lastDrinkTime"
    private let delayKey = "delayMinutes"

    init() {
        loadData()
        updateCanDrinkStatus()
    }

    func recordDrink() {
        lastDrinkTime = Date()
        canDrink = false
        saveData()
        scheduleComplicationUpdate()

        // Schedule next drink availability
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(delayMinutes * 60)) {
            self.updateCanDrinkStatus()
        }
    }

    func updateCanDrinkStatus() {
        guard let lastDrink = lastDrinkTime else {
            canDrink = true
            return
        }

        let timeSinceLastDrink = Date().timeIntervalSince(lastDrink)
        canDrink = timeSinceLastDrink >= TimeInterval(delayMinutes * 60)
        scheduleComplicationUpdate()
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
    }

    private func loadData() {
        if let savedDate = userDefaults.object(forKey: lastDrinkKey) as? Date {
            lastDrinkTime = savedDate
        }
        delayMinutes = userDefaults.integer(forKey: delayKey)
        if delayMinutes == 0 { delayMinutes = 60 } // Default fallback
    }

    private func scheduleComplicationUpdate() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { complication in
            server.reloadTimeline(for: complication)
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var drinkTimer: DrinkTimerModel
    @State private var currentPage = 0
    
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
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        }
        .onAppear {
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
                            }
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.2))

                    Section("Current Status") {
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
                        }
                        .foregroundColor(.red)
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

// MARK: - Complication Provider
class ComplicationController: NSObject, CLKComplicationDataSource {

    private var drinkTimer: DrinkTimerModel {
        // In a real app, you'd want to share this instance properly
        return DrinkTimerModel()
    }

    // MARK: - Complication Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(identifier: "DrinkTimer", displayName: "Drink Timer", supportedFamilies: [
                .modularSmall,
                .modularLarge,
                .utilitarianSmall,
                .utilitarianLarge,
                .circularSmall,
                .extraLarge,
                .graphicCorner,
                .graphicBezel,
                .graphicCircular,
                .graphicRectangular
            ])
        ]
        handler(descriptors)
    }

    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Handle shared complications if needed
    }

    // MARK: - Timeline Configuration

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        guard let lastDrink = drinkTimer.lastDrinkTime else {
            handler(nil)
            return
        }

        let endDate = lastDrink.addingTimeInterval(TimeInterval(drinkTimer.delayMinutes * 60))
        handler(endDate)
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = createTemplate(for: complication.family)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }

    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        var entries: [CLKComplicationTimelineEntry] = []

        if let lastDrink = drinkTimer.lastDrinkTime, !drinkTimer.canDrink {
            let nextAvailableTime = lastDrink.addingTimeInterval(TimeInterval(drinkTimer.delayMinutes * 60))

            if nextAvailableTime > date {
                let template = createTemplate(for: complication.family, isAvailable: true)
                let entry = CLKComplicationTimelineEntry(date: nextAvailableTime, complicationTemplate: template)
                entries.append(entry)
            }
        }

        handler(entries)
    }

    // MARK: - Sample Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(for: complication.family)
        handler(template)
    }

    // MARK: - Template Creation

    private func createTemplate(for family: CLKComplicationFamily, isAvailable: Bool? = nil) -> CLKComplicationTemplate {
        let available = isAvailable ?? drinkTimer.canDrink
        let timeText = available ? "Ready" : drinkTimer.formattedTimeUntilNext()
        let color: UIColor = available ? .green : .red

        switch family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallSimpleText()
            template.textProvider = CLKSimpleTextProvider(text: timeText)
            template.tintColor = color
            return template

        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Drink Timer")
            template.body1TextProvider = CLKSimpleTextProvider(text: available ? "Ready for next drink" : "Wait: \(timeText)")
            template.tintColor = color
            return template

        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            template.textProvider = CLKSimpleTextProvider(text: timeText)
            template.tintColor = color
            return template

        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleText()
            template.textProvider = CLKSimpleTextProvider(text: available ? "✓" : timeText)
            template.tintColor = color
            return template

        case .graphicCircular:
            let template = CLKComplicationTemplateGraphicCircularStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: available ? "Ready" : "Wait")
            template.line2TextProvider = CLKSimpleTextProvider(text: available ? "✓" : timeText)
            return template

        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Drink Timer")
            template.body1TextProvider = CLKSimpleTextProvider(text: available ? "Ready for next drink" : "Wait: \(timeText)")
            return template

        default:
            let template = CLKComplicationTemplateModularSmallSimpleText()
            template.textProvider = CLKSimpleTextProvider(text: timeText)
            template.tintColor = color
            return template
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
