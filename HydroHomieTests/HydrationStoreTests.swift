import XCTest
@testable import HydroHomie

final class HydrationStoreTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    func testTotalSumsAmounts() {
        let entries = [
            DrinkEntry(amountML: 250),
            DrinkEntry(amountML: 500),
            DrinkEntry(amountML: 125)
        ]
        XCTAssertEqual(HydrationStore.total(of: entries), 875, accuracy: 0.0001)
    }

    func testTotalOfEmptyIsZero() {
        XCTAssertEqual(HydrationStore.total(of: []), 0)
    }

    func testDailyTotalsPadsDaysWithoutEntries() {
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let entries = [
            DrinkEntry(amountML: 300, timestamp: today.addingTimeInterval(3600)),
            DrinkEntry(amountML: 200, timestamp: twoDaysAgo.addingTimeInterval(3600))
        ]

        let totals = HydrationStore.dailyTotals(
            from: entries, lastDays: 3, endingOn: today, calendar: calendar
        )

        XCTAssertEqual(totals.count, 3)
        XCTAssertEqual(totals[0].totalML, 200, accuracy: 0.0001)  // two days ago
        XCTAssertEqual(totals[1].totalML, 0, accuracy: 0.0001)    // yesterday, no entries
        XCTAssertEqual(totals[2].totalML, 300, accuracy: 0.0001)  // today
    }

    func testDailyTotalsAreOldestFirst() {
        let today = calendar.startOfDay(for: Date())
        let totals = HydrationStore.dailyTotals(
            from: [], lastDays: 7, endingOn: today, calendar: calendar
        )
        XCTAssertEqual(totals.count, 7)
        XCTAssertEqual(totals.first?.date, calendar.date(byAdding: .day, value: -6, to: today))
        XCTAssertEqual(totals.last?.date, today)
    }

    func testDailyTotalsGroupsMultipleEntriesOnSameDay() {
        let today = calendar.startOfDay(for: Date())
        let entries = [
            DrinkEntry(amountML: 250, timestamp: today.addingTimeInterval(3600)),
            DrinkEntry(amountML: 500, timestamp: today.addingTimeInterval(7200))
        ]
        let totals = HydrationStore.dailyTotals(
            from: entries, lastDays: 1, endingOn: today, calendar: calendar
        )
        XCTAssertEqual(totals.first?.totalML ?? 0, 750, accuracy: 0.0001)
    }
}
