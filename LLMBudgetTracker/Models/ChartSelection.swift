import Foundation

enum MetricKind: String, CaseIterable, Codable, Identifiable {
    case spend
    case tokens
    case requests

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spend: return "Spend"
        case .tokens: return "Tokens"
        case .requests: return "Requests"
        }
    }
}

enum ModelRange: String, CaseIterable, Codable, Identifiable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth

    /// Menu sections, separated by dividers.
    static let groups: [[Self]] = [[.today, .yesterday], [.thisWeek, .lastWeek], [.thisMonth, .lastMonth]]

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This week"
        case .lastWeek: return "Last week"
        case .thisMonth: return "This month"
        case .lastMonth: return "Last month"
        }
    }

    /// UTC date bounds matching the API's daily `yyyy-MM-dd` values; the end is exclusive.
    func dateRange(relativeTo now: Date) -> Range<String>? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2 // Monday, regardless of the user's locale.
        let today = calendar.startOfDay(for: now)
        let start: Date?
        let end: Date?
        switch self {
        case .thisMonth:
            let interval = calendar.dateInterval(of: .month, for: today)
            start = interval?.start
            end = interval?.end
        case .lastMonth:
            let interval = calendar.dateInterval(of: .month, for: today)
            end = interval?.start
            start = end.flatMap { calendar.date(byAdding: .month, value: -1, to: $0) }
        case .thisWeek:
            let interval = calendar.dateInterval(of: .weekOfYear, for: today)
            start = interval?.start
            end = interval?.end
        case .lastWeek:
            let interval = calendar.dateInterval(of: .weekOfYear, for: today)
            end = interval?.start
            start = end.flatMap { calendar.date(byAdding: .day, value: -7, to: $0) }
        case .today:
            start = today
            end = calendar.date(byAdding: .day, value: 1, to: today)
        case .yesterday:
            start = calendar.date(byAdding: .day, value: -1, to: today)
            end = today
        }
        guard let start, let end else { return nil }

        func dateString(_ date: Date) -> String {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return String(
                format: "%04d-%02d-%02d",
                components.year ?? 0, components.month ?? 0, components.day ?? 1
            )
        }
        return dateString(start)..<dateString(end)
    }
}
