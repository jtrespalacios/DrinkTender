//
//  DrinkTimerWidget.swift
//  DrinkTender Watch App
//
//  Created by Jeff Trespalacios on 6/28/25.
//

import SwiftUI
import WidgetKit

// MARK: - Widget Entry
struct DrinkTimerEntry: TimelineEntry {
    let date: Date
    let canDrink: Bool
    let timeUntilNext: String
    let drinkCount: Int
}

// MARK: - Timeline Provider
struct DrinkTimerProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> DrinkTimerEntry {
        DrinkTimerEntry(
            date: Date(),
            canDrink: false,
            timeUntilNext: "25m",
            drinkCount: 3
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DrinkTimerEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DrinkTimerEntry>) -> Void) {
        let currentEntry = createEntry()
        var entries: [DrinkTimerEntry] = [currentEntry]
        
        // If there's a timer running, create an entry for when it completes
        if !currentEntry.canDrink {
            let drinkData = getDrinkTimerData()
            if let lastDrink = drinkData.lastDrinkTime {
                let nextAvailableTime = lastDrink.addingTimeInterval(TimeInterval(drinkData.delayMinutes * 60))
                if nextAvailableTime > Date() {
                    let readyEntry = DrinkTimerEntry(
                        date: nextAvailableTime,
                        canDrink: true,
                        timeUntilNext: "Ready!",
                        drinkCount: drinkData.drinkCount
                    )
                    entries.append(readyEntry)
                }
            }
        }
        
        // Update timeline every 15 minutes to keep it fresh
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func createEntry() -> DrinkTimerEntry {
        let drinkData = getDrinkTimerData()
        return DrinkTimerEntry(
            date: Date(),
            canDrink: drinkData.canDrink,
            timeUntilNext: drinkData.formattedTimeUntilNext(),
            drinkCount: drinkData.drinkCount
        )
    }
    
    private func getDrinkTimerData() -> (lastDrinkTime: Date?, delayMinutes: Int, canDrink: Bool, drinkCount: Int, formattedTimeUntilNext: () -> String) {
        let userDefaults = UserDefaults.standard
        let lastDrinkTime = userDefaults.object(forKey: "lastDrinkTime") as? Date
        let delayMinutes = userDefaults.integer(forKey: "delayMinutes")
        let finalDelayMinutes = delayMinutes == 0 ? 60 : delayMinutes
        let drinkCount = userDefaults.integer(forKey: "drinkCount")
        
        let canDrink: Bool
        if let lastDrink = lastDrinkTime {
            let timeSinceLastDrink = Date().timeIntervalSince(lastDrink)
            canDrink = timeSinceLastDrink >= TimeInterval(finalDelayMinutes * 60)
        } else {
            canDrink = true
        }
        
        let formattedTimeUntilNext = {
            guard let lastDrink = lastDrinkTime, !canDrink else { return "Ready!" }
            
            let delayInterval = TimeInterval(finalDelayMinutes * 60)
            let nextDrinkTime = lastDrink.addingTimeInterval(delayInterval)
            let timeRemaining = max(0, nextDrinkTime.timeIntervalSinceNow)
            
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
        
        return (lastDrinkTime, finalDelayMinutes, canDrink, drinkCount, formattedTimeUntilNext)
    }
}

// MARK: - Widget Views
struct DrinkTimerWidgetView: View {
    let entry: DrinkTimerEntry
    
    var body: some View {

        VStack(spacing: 2) {
            // Status Icon
            Image(systemName: entry.canDrink ? "checkmark.circle.fill" : "clock.fill")
                .font(.title2)
                .foregroundColor(.white)

            // Time or Status Text
            Text(entry.canDrink ? "Ready" : entry.timeUntilNext)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(backgroundColor.gradient)
        }
    }
    
    private var backgroundColor: Color {
        entry.canDrink ? .green : .orange
    }
}

// MARK: - Rectangular Widget View
struct DrinkTimerRectangularView: View {
    let entry: DrinkTimerEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Drink Timer")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: entry.canDrink ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption)
                        .foregroundColor(entry.canDrink ? .green : .orange)
                    
                    Text(entry.canDrink ? "Ready for next drink" : "Wait: \(entry.timeUntilNext)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Drink count
            VStack {
                Text("\(entry.drinkCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("drinks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(.windowBackground)
        }
    }
}

// MARK: - Large Widget View
struct DrinkTimerLargeView: View {
    let entry: DrinkTimerEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Main Status Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .fill(entry.canDrink ? Color.green : Color.orange)
                    .frame(width: 50, height: 50)

                HStack {
                    Text("\(entry.drinkCount)")
                        .foregroundColor(.primary)
                    Image(systemName: entry.canDrink ? "checkmark" : "clock")
                        .foregroundColor(.white)
                }
                .font(.caption2)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(.windowBackground)
        }
    }
}

// MARK: - Widget Configuration
struct DrinkTimerWidget: Widget {
    let kind: String = "DrinkTimerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DrinkTimerProvider()) { entry in
            DrinkTimerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Drink Timer")
        .description("Track your drink timing and stay on schedule.")
        .supportedFamilies([
            .accessoryCorner,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Rectangular Widget
struct DrinkTimerRectangularWidget: Widget {
    let kind: String = "DrinkTimerRectangularWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DrinkTimerProvider()) { entry in
            DrinkTimerRectangularView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Drink Timer Detailed")
        .description("Detailed view with drink count and status.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Large Widget (for Ultra/Series 7+)
struct DrinkTimerLargeWidget: Widget {
    let kind: String = "DrinkTimerLargeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DrinkTimerProvider()) { entry in
            DrinkTimerLargeView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Drink Timer Large")
        .description("Large widget with full status display.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Widget Bundle
@main
struct DrinkTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        DrinkTimerWidget()
        DrinkTimerRectangularWidget()
        DrinkTimerLargeWidget()
    }
}

#if DEBUG

    // MARK: - Previews
    struct DrinkTimerWidget_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Circular - Ready State
                DrinkTimerWidgetView(entry: DrinkTimerEntry(
                    date: Date(),
                    canDrink: true,
                    timeUntilNext: "Ready!",
                    drinkCount: 3
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular - Ready")

                // Circular - Waiting State
                DrinkTimerWidgetView(entry: DrinkTimerEntry(
                    date: Date(),
                    canDrink: false,
                    timeUntilNext: "25m",
                    drinkCount: 3
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular - Waiting")

                // Rectangular
                DrinkTimerRectangularView(entry: DrinkTimerEntry(
                    date: Date(),
                    canDrink: false,
                    timeUntilNext: "25m",
                    drinkCount: 5
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular")

                // Large
                DrinkTimerLargeView(entry: DrinkTimerEntry(
                    date: Date(),
                    canDrink: true,
                    timeUntilNext: "Ready!",
                    drinkCount: 4
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Large")
            }
        }
    }

#endif
