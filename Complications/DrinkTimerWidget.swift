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
    let progressPercentage: Double // New property for border progress
}

// MARK: - Timeline Provider
struct DrinkTimerProvider: TimelineProvider {

    func placeholder(in context: Context) -> DrinkTimerEntry {
        DrinkTimerEntry(
            date: Date(),
            canDrink: false,
            timeUntilNext: "25m",
            drinkCount: 3,
            progressPercentage: 0.6
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
                        drinkCount: drinkData.drinkCount,
                        progressPercentage: 1.0
                    )
                    entries.append(readyEntry)
                }
            }
        }

        // Update timeline every minute to keep progress accurate
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry() -> DrinkTimerEntry {
        let drinkData = getDrinkTimerData()
        return DrinkTimerEntry(
            date: Date(),
            canDrink: drinkData.canDrink,
            timeUntilNext: drinkData.formattedTimeUntilNext(),
            drinkCount: drinkData.drinkCount,
            progressPercentage: drinkData.progressPercentage()
        )
    }

    private func getDrinkTimerData() -> (lastDrinkTime: Date?, delayMinutes: Int, canDrink: Bool, drinkCount: Int, formattedTimeUntilNext: () -> String, progressPercentage: () -> Double) {
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

        let progressPercentage = {
            guard let lastDrink = lastDrinkTime else { return 1.0 }

            if canDrink {
                return 1.0 // Complete when ready
            }

            let totalDelayTime = TimeInterval(finalDelayMinutes * 60)
            let timeSinceLastDrink = Date().timeIntervalSince(lastDrink)
            let progress = timeSinceLastDrink / totalDelayTime

            return min(max(progress, 0.0), 1.0)
        }

        return (lastDrinkTime, finalDelayMinutes, canDrink, drinkCount, formattedTimeUntilNext, progressPercentage)
    }
}

// MARK: - Widget Views
struct DrinkTimerWidgetView: View {
    let entry: DrinkTimerEntry

    var body: some View {
        ZStack {
            // Background circle with color based on state
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)

            // Progress border
            Circle()
                .trim(from: 0, to: entry.progressPercentage)
                .stroke(
                    borderColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))

            // Drink count in center
            Text("\(entry.drinkCount)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var backgroundColor: Color {
        entry.canDrink ? .green : .purple
    }

    private var borderColor: Color {
        entry.canDrink ? .white : .white.opacity(0.8)
    }
}

// MARK: - Rectangular Widget View
struct DrinkTimerRectangularView: View {
    let entry: DrinkTimerEntry

    var body: some View {
        HStack(spacing: 8) {
            // Timer circle with progress border
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: entry.progressPercentage)
                    .stroke(
                        Color.white.opacity(0.8),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))

                Text("\(entry.drinkCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Drink Timer")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(entry.canDrink ? "Ready for next drink" : "Wait: \(entry.timeUntilNext)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(.windowBackground)
        }
    }

    private var backgroundColor: Color {
        entry.canDrink ? .green : .purple
    }
}

// MARK: - Large Widget View
struct DrinkTimerLargeView: View {
    let entry: DrinkTimerEntry

    var body: some View {
        VStack(spacing: 8) {
            // Main Status Circle with progress border
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: entry.progressPercentage)
                    .stroke(
                        Color.white.opacity(0.9),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(entry.drinkCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

        }
        .padding()
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(.windowBackground)
        }
    }

    private var backgroundColor: Color {
        entry.canDrink ? .green : .purple
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
                    drinkCount: 3,
                    progressPercentage: 1.0
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular - Ready")

                // Circular - Waiting State (60% progress)
                DrinkTimerWidgetView(entry: DrinkTimerEntry(
                    date: Date(),
                    canDrink: false,
                    timeUntilNext: "25m",
                    drinkCount: 3,
                    progressPercentage: 0.6
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular - Waiting")

                // Rectangular
                DrinkTimerRectangularView(entry: DrinkTimerEntry(
                    date: Date(),
                    canDrink: false,
                    timeUntilNext: "25m",
                    drinkCount: 5,
                    progressPercentage: 0.4
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular")

                // Large
                DrinkTimerLargeView(entry: DrinkTimerEntry(
                    date: Date(),
                    canDrink: true,
                    timeUntilNext: "Ready!",
                    drinkCount: 4,
                    progressPercentage: 1.0
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Large")
            }
        }
    }

#endif
