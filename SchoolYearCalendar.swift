import Foundation

struct SchoolMilestone: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let symbolName: String
    let date: Date
    let tint: MilestoneTint
}

enum MilestoneTint: String, Equatable, Codable {
    case orange
    case blue
    case pink
}

struct SchoolYearCalendar: Codable {
    let summerBreakStart: Date
    let milestones: [SchoolMilestone]
    let daysOff: Set<Date>

    func schoolDaysRemaining(until targetDate: Date, from startDate: Date = .now) -> Int {
        let calendar = Self.calendar
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: targetDate)

        guard start < target else {
            return 0
        }

        var count = 0
        var date = start

        while date < target {
            if !calendar.isDateInWeekend(date), !daysOff.contains(date) {
                count += 1
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return count
    }

    var nextMilestone: SchoolMilestone? {
        milestones
            .filter { $0.date > Self.calendar.startOfDay(for: .now) }
            .min { $0.date < $1.date }
    }

    static let sample = SchoolYearCalendar(
        summerBreakStart: date(2027, 6, 11),
        milestones: [
            SchoolMilestone(
                id: "hostlov",
                title: "Höstlov",
                symbolName: "leaf.fill",
                date: date(2026, 10, 26),
                tint: .orange
            ),
            SchoolMilestone(
                id: "jullov",
                title: "Jullov",
                symbolName: "snowflake",
                date: date(2026, 12, 21),
                tint: .blue
            ),
            SchoolMilestone(
                id: "sportlov",
                title: "Sportlov",
                symbolName: "figure.skiing.downhill",
                date: date(2027, 2, 22),
                tint: .blue
            ),
            SchoolMilestone(
                id: "pasklov",
                title: "Påsklov",
                symbolName: "hare.fill",
                date: date(2027, 3, 29),
                tint: .pink
            )
        ],
        daysOff: closedDates()
    )

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "sv_SE")
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private static func closedDates() -> Set<Date> {
        var dates = Set<Date>()
        let ranges = [
            (date(2026, 10, 26), date(2026, 10, 30)),
            (date(2026, 12, 21), date(2027, 1, 8)),
            (date(2027, 2, 22), date(2027, 2, 26)),
            (date(2027, 3, 29), date(2027, 4, 2))
        ]

        for (start, end) in ranges {
            var current = start
            while current <= end {
                dates.insert(current)
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                    break
                }
                current = next
            }
        }

        [
            date(2027, 1, 6),
            date(2027, 4, 2),
            date(2027, 4, 5),
            date(2027, 5, 6),
            date(2027, 5, 14)
        ].forEach { dates.insert($0) }

        return dates
    }
}
