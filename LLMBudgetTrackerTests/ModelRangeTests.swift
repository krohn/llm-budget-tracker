import XCTest

final class ModelRangeTests: XCTestCase {
    func testThisWeekIsAvailableInPicker() {
        XCTAssertTrue(ModelRange.allCases.contains(.thisWeek))
        XCTAssertEqual(ModelRange.thisWeek.label, "This week")
        XCTAssertEqual(ModelRange(rawValue: "thisWeek"), .thisWeek)
        XCTAssertEqual(ModelRange(rawValue: "thisMonth"), .thisMonth)
        XCTAssertEqual(ModelRange(rawValue: "lastMonth"), .lastMonth)
        XCTAssertNil(ModelRange(rawValue: "last28"))
    }

    func testLastWeekIsAvailableInPicker() {
        XCTAssertTrue(ModelRange.allCases.contains(.lastWeek))
        XCTAssertEqual(ModelRange.lastWeek.label, "Last week")
        XCTAssertEqual(ModelRange(rawValue: "lastWeek"), .lastWeek)
    }

    func testLastWeekIncludesOnlyPreviousCalendarWeek() throws {
        let range = try dates(.lastWeek, at: "2026-10-08T12:00:00Z")
        XCTAssertEqual(range, "2026-09-28"..<"2026-10-05")
        XCTAssertFalse(range.contains("2026-09-27"))
        XCTAssertTrue(range.contains("2026-09-28"))
        XCTAssertTrue(range.contains("2026-10-04"))
        XCTAssertFalse(range.contains("2026-10-05"))
    }

    func testLastWeekChangesOnMonday() throws {
        XCTAssertEqual(
            try dates(.lastWeek, at: "2026-10-12T00:00:00Z"),
            "2026-10-05"..<"2026-10-12"
        )
        XCTAssertEqual(
            try dates(.lastWeek, at: "2026-10-11T23:59:59Z"),
            "2026-09-28"..<"2026-10-05"
        )
    }

    func testLastWeekCrossesYearBoundary() throws {
        XCTAssertEqual(
            try dates(.lastWeek, at: "2027-01-04T12:00:00Z"),
            "2026-12-28"..<"2027-01-04"
        )
    }

    func testLastWeekUsesUTC() throws {
        XCTAssertEqual(
            try dates(.lastWeek, at: "2026-10-12T01:00:00+02:00"),
            "2026-09-28"..<"2026-10-05"
        )
    }

    func testMondayStartsNewWeek() throws {
        let range = try dates(.thisWeek, at: "2026-10-05T00:00:00Z")
        XCTAssertEqual(range, "2026-10-05"..<"2026-10-12")
        XCTAssertFalse(range.contains("2026-10-04"))
        XCTAssertTrue(range.contains("2026-10-05"))
        XCTAssertTrue(range.contains("2026-10-11"))
        XCTAssertFalse(range.contains("2026-10-12"))
    }

    func testSundayStillBelongsToSameWeek() throws {
        XCTAssertEqual(
            try dates(.thisWeek, at: "2026-10-11T23:59:59Z"),
            "2026-10-05"..<"2026-10-12"
        )
    }

    func testWeekCrossesMonthBoundary() throws {
        XCTAssertEqual(
            try dates(.thisWeek, at: "2026-10-01T12:00:00Z"),
            "2026-09-28"..<"2026-10-05"
        )
    }

    func testWeekCrossesYearBoundary() throws {
        XCTAssertEqual(
            try dates(.thisWeek, at: "2027-01-01T12:00:00Z"),
            "2026-12-28"..<"2027-01-04"
        )
    }

    func testWeekUsesUTCEvenWhenTimestampHasOffset() throws {
        XCTAssertEqual(
            try dates(.thisWeek, at: "2026-10-12T01:00:00+02:00"),
            "2026-10-05"..<"2026-10-12"
        )
    }

    func testTodayIncludesOnlyCurrentUTCDay() throws {
        let range = try dates(.today, at: "2026-10-08T12:00:00Z")
        XCTAssertEqual(range, "2026-10-08"..<"2026-10-09")
        XCTAssertFalse(range.contains("2026-10-07"))
        XCTAssertFalse(range.contains("2026-10-09"))
        XCTAssertEqual(ModelRange.today.label, "Today")
        XCTAssertEqual(ModelRange(rawValue: "today"), .today)
    }

    func testTodayUsesUTCAndCrossesYearBoundary() throws {
        XCTAssertEqual(try dates(.today, at: "2027-01-01T00:30:00+01:00"), "2026-12-31"..<"2027-01-01")
    }

    func testThisMonthIncludesOnlyCurrentMonth() throws {
        let range = try dates(.thisMonth, at: "2026-10-08T12:00:00Z")
        XCTAssertEqual(range, "2026-10-01"..<"2026-11-01")
        XCTAssertFalse(range.contains("2026-09-30"))
        XCTAssertTrue(range.contains("2026-10-31"))
        XCTAssertFalse(range.contains("2026-11-01"))
    }

    func testLastMonthIncludesOnlyPreviousCalendarMonth() throws {
        let range = try dates(.lastMonth, at: "2026-10-08T12:00:00Z")
        XCTAssertEqual(range, "2026-09-01"..<"2026-10-01")
        XCTAssertFalse(range.contains("2026-08-31"))
        XCTAssertTrue(range.contains("2026-09-30"))
        XCTAssertFalse(range.contains("2026-10-01"))
        XCTAssertEqual(ModelRange.lastMonth.label, "Last month")
    }

    func testYesterdayIncludesOnlyPreviousUTCDay() throws {
        XCTAssertEqual(try dates(.yesterday, at: "2026-10-08T12:00:00Z"), "2026-10-07"..<"2026-10-08")
        XCTAssertEqual(try dates(.yesterday, at: "2027-01-01T00:30:00+01:00"), "2026-12-30"..<"2026-12-31")
        XCTAssertEqual(ModelRange.yesterday.label, "Yesterday")
    }

    func testThisMonthHandlesLeapYear() throws {
        XCTAssertEqual(
            try dates(.thisMonth, at: "2028-02-29T12:00:00Z"),
            "2028-02-01"..<"2028-03-01"
        )
    }

    func testLastMonthCrossesYearBoundary() throws {
        XCTAssertEqual(try dates(.lastMonth, at: "2027-01-15T12:00:00Z"), "2026-12-01"..<"2027-01-01")
    }

    func testLastMonthIncludesLeapDay() throws {
        XCTAssertEqual(try dates(.lastMonth, at: "2028-03-01T12:00:00Z"), "2028-02-01"..<"2028-03-01")
    }

    func testWeekRangesAreAdjacentAcrossDaylightSavingChange() throws {
        let timestamp = "2026-10-25T12:00:00+01:00"
        let previous = try dates(.lastWeek, at: timestamp)
        let current = try dates(.thisWeek, at: timestamp)
        XCTAssertEqual(previous, "2026-10-12"..<"2026-10-19")
        XCTAssertEqual(current, "2026-10-19"..<"2026-10-26")
        XCTAssertEqual(previous.upperBound, current.lowerBound)
    }

    func testPickerOrderAndStableIdentifiers() throws {
        XCTAssertEqual(ModelRange.allCases, [.today, .yesterday, .thisWeek, .lastWeek, .thisMonth, .lastMonth])
        XCTAssertEqual(ModelRange.groups.flatMap { $0 }, ModelRange.allCases)
        for range in ModelRange.allCases {
            XCTAssertEqual(range.id, range.rawValue)
            XCTAssertEqual(try JSONDecoder().decode(ModelRange.self, from: JSONEncoder().encode(range)), range)
        }
        XCTAssertNil(ModelRange(rawValue: "unknown"))
    }

    func testMetricLabelsAndIdentifiers() {
        XCTAssertEqual(MetricKind.allCases.map(\.label), ["Spend", "Tokens", "Requests"])
        for metric in MetricKind.allCases {
            XCTAssertEqual(metric.id, metric.rawValue)
        }
    }

    private func dates(_ range: ModelRange, at timestamp: String) throws -> Range<String> {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: timestamp))
        return try XCTUnwrap(range.dateRange(relativeTo: now))
    }
}
