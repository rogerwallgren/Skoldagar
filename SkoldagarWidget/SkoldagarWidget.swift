import SwiftUI
import WidgetKit

struct SchoolCountdownEntry: TimelineEntry {
    let date: Date
    let summerDays: Int
    let nextBreakName: String
    let nextBreakDays: Int
    let isConfigured: Bool
}

private struct WidgetMilestone: Codable {
    let id: String
    let title: String
    let symbolName: String
    let date: Date
    let tint: String
}

private struct WidgetSchoolCalendar: Codable {
    let summerBreakStart: Date
    let milestones: [WidgetMilestone]
    let daysOff: Set<Date>
}

struct SchoolCountdownProvider: TimelineProvider {
    private let appGroupIdentifier = "group.com.rogerwallgren.Lasarsnedrakning"

    func placeholder(in context: Context) -> SchoolCountdownEntry {
        SchoolCountdownEntry(
            date: .now,
            summerDays: 124,
            nextBreakName: "Höstlov",
            nextBreakDays: 20,
            isConfigured: true
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (SchoolCountdownEntry) -> Void
    ) {
        completion(entry(for: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<SchoolCountdownEntry>) -> Void
    ) {
        let now = Date()
        let entry = entry(for: now)
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86_400)

        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func entry(for date: Date) -> SchoolCountdownEntry {
        guard let schoolCalendar = savedCalendar() else {
            return SchoolCountdownEntry(
                date: date,
                summerDays: 0,
                nextBreakName: "",
                nextBreakDays: 0,
                isConfigured: false
            )
        }

        let nextMilestone = schoolCalendar.milestones
            .filter { $0.date > Calendar.current.startOfDay(for: date) }
            .min { $0.date < $1.date }

        return SchoolCountdownEntry(
            date: date,
            summerDays: schoolDays(
                from: date,
                until: schoolCalendar.summerBreakStart,
                daysOff: schoolCalendar.daysOff
            ),
            nextBreakName: nextMilestone?.title ?? "Sommarlov",
            nextBreakDays: schoolDays(
                from: date,
                until: nextMilestone?.date ?? schoolCalendar.summerBreakStart,
                daysOff: schoolCalendar.daysOff
            ),
            isConfigured: true
        )
    }

    private func savedCalendar() -> WidgetSchoolCalendar? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: "schoolYearCalendar") else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetSchoolCalendar.self, from: data)
    }

    private func schoolDays(
        from startDate: Date,
        until targetDate: Date,
        daysOff: Set<Date>
    ) -> Int {
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: targetDate)
        var count = 0

        while date < target {
            if !calendar.isDateInWeekend(date),
               !daysOff.contains(calendar.startOfDay(for: date)) {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = next
        }

        return count
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? .distantPast
    }
}

struct SkoldagarWidgetEntryView: View {
    let entry: SchoolCountdownEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.isConfigured {
                configuredContent
            } else {
                emptyContent
            }
        }
        .foregroundStyle(.white)
        .containerBackground(
            LinearGradient(
                colors: [.indigo, .blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }
    private var configuredContent: some View {
        Group {
            Label("Sommarlov", systemImage: "sun.max.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            Text(entry.summerDays, format: .number)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .minimumScaleFactor(0.7)

            Text("skoldagar kvar")
                .font(.caption.bold())

            Spacer(minLength: 2)

            HStack {
                Text(entry.nextBreakName)
                Spacer()
                Text("\(entry.nextBreakDays) dagar")
            }
            .font(.caption2.bold())
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.title)
            Text("Lägg in din skolkalender")
                .font(.headline)
            Text("Öppna appen för att komma igång.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct SkoldagarWidget: Widget {
    let kind = "SkoldagarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SchoolCountdownProvider()
        ) { entry in
            SkoldagarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Skoldagar kvar")
        .description("Se hur många skoldagar som återstår till loven.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    SkoldagarWidget()
} timeline: {
    SchoolCountdownEntry(
        date: .now,
        summerDays: 124,
        nextBreakName: "Höstlov",
        nextBreakDays: 20,
        isConfigured: true
    )
}
