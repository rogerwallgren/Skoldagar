import Foundation
import Observation
import WidgetKit

enum CalendarImportState: Equatable {
    case idle
    case loading
    case success(Date)
    case failed(String)
}

struct CustomSchoolDay: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let date: Date
}

struct AutomaticDayOff: Identifiable, Equatable {
    let title: String
    let date: Date

    var id: String {
        "\(title)-\(date.timeIntervalSinceReferenceDate)"
    }
}

@MainActor
@Observable
final class SchoolCalendarStore {
    private(set) var schoolYear = SchoolYearCalendar.sample
    private(set) var customDays: [CustomSchoolDay] = []
    private(set) var hasImportedSchoolYear = false
    var sourceURLString: String
    private(set) var importState: CalendarImportState = .idle

    private static let appGroupIdentifier = "group.com.rogerwallgren.Lasarsnedrakning"
    private let importer = SchoolCalendarImporter()
    private let defaults: UserDefaults
    private var importedSchoolYear = SchoolYearCalendar.sample

    init(defaults: UserDefaults? = nil) {
        let sharedDefaults = defaults
            ?? UserDefaults(suiteName: Self.appGroupIdentifier)
            ?? .standard
        self.defaults = sharedDefaults
        sourceURLString = sharedDefaults.string(forKey: "schoolCalendarSourceURL") ?? ""

        if let data = sharedDefaults.data(forKey: "importedSchoolYearCalendar"),
           let savedCalendar = try? JSONDecoder().decode(
               SchoolYearCalendar.self,
               from: data
           ) {
            importedSchoolYear = savedCalendar
            hasImportedSchoolYear = true
        }

        if let data = sharedDefaults.data(forKey: "customSchoolDays"),
           let savedDays = try? JSONDecoder().decode(
               [CustomSchoolDay].self,
               from: data
           ) {
            customDays = savedDays.sorted { $0.date < $1.date }
        }

        rebuildSchoolYear()
    }

    func importCalendar() async {
        let trimmedURL = sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else {
            importState = .failed("Kontrollera att länken börjar med https://")
            return
        }

        importState = .loading

        do {
            importedSchoolYear = try await importer.importCalendar(from: url)
            hasImportedSchoolYear = true
            defaults.set(trimmedURL, forKey: "schoolCalendarSourceURL")
            if let data = try? JSONEncoder().encode(importedSchoolYear) {
                defaults.set(data, forKey: "importedSchoolYearCalendar")
            }
            rebuildSchoolYear()
            importState = .success(.now)
        } catch {
            importState = .failed(error.localizedDescription)
        }
    }

    var automaticDaysOff: [AutomaticDayOff] {
        guard hasImportedSchoolYear else {
            return []
        }
        let summerYear = Calendar.current.component(.year, from: importedSchoolYear.summerBreakStart)
        let schoolYearStart = Calendar.current.date(
            from: DateComponents(year: summerYear - 1, month: 7, day: 1)
        ) ?? .distantPast
        return SwedishPublicHolidays.namedDates(
            fromYear: summerYear - 1,
            throughYear: summerYear
        )
        .filter {
            $0.date >= schoolYearStart
                && $0.date < importedSchoolYear.summerBreakStart
        }
        .sorted { $0.date < $1.date }
    }

    func updateSummerBreakStart(_ date: Date) {
        importedSchoolYear = SchoolYearCalendar(
            summerBreakStart: Calendar.current.startOfDay(for: date),
            milestones: importedSchoolYear.milestones,
            daysOff: importedSchoolYear.daysOff
        )
        saveImportedSchoolYear()
    }

    func updateMilestone(id: String, title: String, date: Date) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let milestones = importedSchoolYear.milestones.map { milestone in
            guard milestone.id == id else {
                return milestone
            }
            return SchoolMilestone(
                id: milestone.id,
                title: trimmedTitle.isEmpty ? milestone.title : trimmedTitle,
                symbolName: milestone.symbolName,
                date: Calendar.current.startOfDay(for: date),
                tint: milestone.tint
            )
        }
        importedSchoolYear = SchoolYearCalendar(
            summerBreakStart: importedSchoolYear.summerBreakStart,
            milestones: milestones.sorted { $0.date < $1.date },
            daysOff: importedSchoolYear.daysOff
        )
        saveImportedSchoolYear()
    }

    func removeMilestones(at offsets: IndexSet) {
        var milestones = importedSchoolYear.milestones
        for index in offsets.sorted(by: >) {
            milestones.remove(at: index)
        }
        importedSchoolYear = SchoolYearCalendar(
            summerBreakStart: importedSchoolYear.summerBreakStart,
            milestones: milestones,
            daysOff: importedSchoolYear.daysOff
        )
        saveImportedSchoolYear()
    }

    func addCustomDay(title: String, date: Date) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let day = CustomSchoolDay(
            id: UUID(),
            title: trimmedTitle.isEmpty ? "Ledig dag" : trimmedTitle,
            date: Calendar.current.startOfDay(for: date)
        )
        customDays.append(day)
        customDays.sort { $0.date < $1.date }
        saveCustomDays()
        rebuildSchoolYear()
    }

    func removeCustomDays(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            customDays.remove(at: index)
        }
        saveCustomDays()
        rebuildSchoolYear()
    }

    private func rebuildSchoolYear() {
        var daysOff = importedSchoolYear.daysOff
        customDays.forEach { daysOff.insert($0.date) }

        let customMilestones = customDays.map { day in
            SchoolMilestone(
                id: "custom-\(day.id.uuidString)",
                title: day.title,
                symbolName: "calendar.badge.minus",
                date: day.date,
                tint: .pink
            )
        }
        let milestones = (importedSchoolYear.milestones + customMilestones)
            .sorted { $0.date < $1.date }

        schoolYear = SchoolYearCalendar(
            summerBreakStart: importedSchoolYear.summerBreakStart,
            milestones: milestones,
            daysOff: daysOff
        )

        if hasImportedSchoolYear,
           let data = try? JSONEncoder().encode(schoolYear) {
            defaults.set(data, forKey: "schoolYearCalendar")
        } else {
            defaults.removeObject(forKey: "schoolYearCalendar")
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "SkoldagarWidget")
    }

    private func saveImportedSchoolYear() {
        hasImportedSchoolYear = true
        if let data = try? JSONEncoder().encode(importedSchoolYear) {
            defaults.set(data, forKey: "importedSchoolYearCalendar")
        }
        rebuildSchoolYear()
    }

    private func saveCustomDays() {
        if let data = try? JSONEncoder().encode(customDays) {
            defaults.set(data, forKey: "customSchoolDays")
        }
    }
}

struct SchoolCalendarImporter: Sendable {
    enum ImportError: LocalizedError {
        case invalidResponse
        case unsupportedPage
        case missingSchoolYear

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Skolans sida kunde inte hämtas."
            case .unsupportedPage:
                "Sidan saknar läsårstider som appen kan tolka."
            case .missingSchoolYear:
                "Appen kunde inte hitta vilket läsår datumen gäller."
            }
        }
    }

    func importCalendar(from url: URL) async throws -> SchoolYearCalendar {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode,
              let html = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidResponse
        }

        return try parse(html: html)
    }

    func parse(html: String) throws -> SchoolYearCalendar {
        let text = normalizedText(from: html)
        guard let years = schoolYears(in: text) else {
            throw ImportError.missingSchoolYear
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var milestones: [SchoolMilestone] = []
        var daysOff = SwedishPublicHolidays.dates(
            fromYear: years.autumn,
            throughYear: years.spring
        )

        var autumnLastSchoolDay: Date?
        var springStart: Date?
        var summerBreakStart: Date?

        for line in lines {
            let lowercased = line.lowercased()

            if let week = weekNumber(in: lowercased) {
                if lowercased.contains("höstlov"),
                   let range = weekRange(week, year: years.autumn) {
                    addRange(range, to: &daysOff)
                    milestones.append(
                        milestone(
                            id: "hostlov",
                            title: "Höstlov",
                            symbol: "leaf.fill",
                            date: range.lowerBound,
                            tint: .orange
                        )
                    )
                } else if lowercased.contains("sportlov"),
                          let range = weekRange(week, year: years.spring) {
                    addRange(range, to: &daysOff)
                    milestones.append(
                        milestone(
                            id: "sportlov",
                            title: "Sportlov",
                            symbol: "figure.skiing.downhill",
                            date: range.lowerBound,
                            tint: .blue
                        )
                    )
                } else if lowercased.contains("påsklov"),
                          let range = weekRange(week, year: years.spring) {
                    addRange(range, to: &daysOff)
                    milestones.append(
                        milestone(
                            id: "pasklov",
                            title: "Påsklov",
                            symbol: "hare.fill",
                            date: range.lowerBound,
                            tint: .pink
                        )
                    )
                }
            }

            guard let dateRange = dateRange(in: lowercased, years: years) else {
                continue
            }

            if lowercased.contains("studiedag") || lowercased.contains("lovdag") {
                addRange(dateRange, to: &daysOff)
            }

            if lowercased.contains("sista skoldag innan jullov") {
                autumnLastSchoolDay = dateRange.lowerBound
            } else if lowercased.contains("skolstart"),
                      monthNumber(in: lowercased) ?? 0 <= 6 {
                springStart = dateRange.lowerBound
            } else if lowercased.contains("sista skoldag"),
                      lowercased.contains("åk") {
                summerBreakStart = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: dateRange.upperBound
                )
            }
        }

        if let autumnLastSchoolDay, let springStart,
           let christmasBreakStart = calendar.date(
               byAdding: .day,
               value: 1,
               to: autumnLastSchoolDay
           ) {
            let christmasRange = christmasBreakStart...springStart
            addRange(christmasRange, to: &daysOff)
            milestones.append(
                milestone(
                    id: "jullov",
                    title: "Jullov",
                    symbol: "snowflake",
                    date: christmasBreakStart,
                    tint: .blue
                )
            )
        }

        guard let summerBreakStart, !milestones.isEmpty else {
            throw ImportError.unsupportedPage
        }

        return SchoolYearCalendar(
            summerBreakStart: summerBreakStart,
            milestones: milestones.sorted { $0.date < $1.date },
            daysOff: daysOff
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        return calendar
    }

    private func normalizedText(from html: String) -> String {
        let blockSeparated = html.replacingOccurrences(
            of: "<[^>]+>",
            with: "\n",
            options: .regularExpression
        )

        return blockSeparated
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8211;", with: "-")
            .replacingOccurrences(of: "&#038;", with: "&")
    }

    private func schoolYears(in text: String) -> (autumn: Int, spring: Int)? {
        guard let match = text.firstMatch(
            of: /(?i)Läsåret\s+(\d{4})\/(\d{2,4})/
        ), let autumn = Int(match.1) else {
            return nil
        }

        let springText = String(match.2)
        let spring = springText.count == 2
            ? (autumn / 100) * 100 + (Int(springText) ?? 0)
            : Int(springText)

        guard let spring else {
            return nil
        }

        return (autumn, spring)
    }

    private func weekNumber(in line: String) -> Int? {
        guard let match = line.firstMatch(of: /vecka\s+(\d{1,2})/),
              let week = Int(match.1) else {
            return nil
        }
        return week
    }

    private func weekRange(_ week: Int, year: Int) -> ClosedRange<Date>? {
        var components = DateComponents()
        components.calendar = calendar
        components.weekOfYear = week
        components.yearForWeekOfYear = year
        components.weekday = 2

        guard let monday = calendar.date(from: components),
              let friday = calendar.date(byAdding: .day, value: 4, to: monday) else {
            return nil
        }

        return monday...friday
    }

    private func dateRange(
        in line: String,
        years: (autumn: Int, spring: Int)
    ) -> ClosedRange<Date>? {
        guard let match = line.firstMatch(
            of: /(\d{1,2})(?:-(\d{1,2}))?\s+(jan(?:uari)?|feb(?:ruari)?|mar(?:s)?|apr(?:il)?|maj|jun(?:i)?|jul(?:i)?|aug(?:usti)?|sep(?:tember)?|okt(?:ober)?|nov(?:ember)?|dec(?:ember)?)/
        ), let firstDay = Int(match.1) else {
            return nil
        }

        let secondDay = match.2.flatMap { Int($0) } ?? firstDay
        let monthName = String(match.3)
        guard let month = monthNumber(in: monthName) else {
            return nil
        }

        let year = month >= 7 ? years.autumn : years.spring
        guard let start = calendar.date(
            from: DateComponents(year: year, month: month, day: firstDay)
        ), let end = calendar.date(
            from: DateComponents(year: year, month: month, day: secondDay)
        ) else {
            return nil
        }

        return start...end
    }

    private func monthNumber(in text: String) -> Int? {
        let lowercased = text.lowercased()
        let months = [
            "jan": 1, "feb": 2, "mar": 3, "apr": 4,
            "maj": 5, "jun": 6, "jul": 7, "aug": 8,
            "sep": 9, "okt": 10, "nov": 11, "dec": 12
        ]

        return months.first { lowercased.contains($0.key) }?.value
    }

    private func addRange(
        _ range: ClosedRange<Date>,
        to dates: inout Set<Date>
    ) {
        var date = range.lowerBound
        while date <= range.upperBound {
            dates.insert(calendar.startOfDay(for: date))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = next
        }
    }

    private func milestone(
        id: String,
        title: String,
        symbol: String,
        date: Date,
        tint: MilestoneTint
    ) -> SchoolMilestone {
        SchoolMilestone(
            id: id,
            title: title,
            symbolName: symbol,
            date: date,
            tint: tint
        )
    }
}

enum SwedishPublicHolidays {
    static func dates(fromYear: Int, throughYear: Int) -> Set<Date> {
        Set(namedDates(fromYear: fromYear, throughYear: throughYear).map(\.date))
    }

    static func namedDates(fromYear: Int, throughYear: Int) -> [AutomaticDayOff] {
        var days: [AutomaticDayOff] = []
        for year in fromYear...throughYear {
            days += [
                AutomaticDayOff(title: "Nyårsdagen", date: date(year, 1, 1)),
                AutomaticDayOff(title: "Trettondedag jul", date: date(year, 1, 6)),
                AutomaticDayOff(title: "Första maj", date: date(year, 5, 1)),
                AutomaticDayOff(title: "Sveriges nationaldag", date: date(year, 6, 6)),
                AutomaticDayOff(title: "Julafton", date: date(year, 12, 24)),
                AutomaticDayOff(title: "Juldagen", date: date(year, 12, 25)),
                AutomaticDayOff(title: "Annandag jul", date: date(year, 12, 26)),
                AutomaticDayOff(title: "Nyårsafton", date: date(year, 12, 31))
            ]

            let easter = easterSunday(year: year)
            [
                ("Långfredagen", -2),
                ("Annandag påsk", 1),
                ("Kristi himmelsfärdsdag", 39)
            ].forEach { title, offset in
                if let holiday = calendar.date(byAdding: .day, value: offset, to: easter) {
                    days.append(AutomaticDayOff(title: title, date: holiday))
                }
            }
        }
        return days
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
            ?? .distantPast
    }

    private static func easterSunday(year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return date(year, month, day)
    }
}
