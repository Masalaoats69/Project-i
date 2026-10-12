import XCTest
@testable import ProjectIstiqamah

final class ProgressMetricsTests: XCTestCase {
    private func date(_ key: String) throws -> Date {
        try XCTUnwrap(DateTools.date(from: key))
    }

    private func block(created: String = "2026-10-05", weekdays: Set<Int> = FocusBlock.everyDay) throws -> FocusBlock {
        FocusBlock(name: "Practice", startTime: "09:00", endTime: "10:00", note: "",
                   weekdays: weekdays, createdAt: try date(created))
    }

    func testNewBlockDoesNotInventPlansBeforeCreation() throws {
        let block = try block(created: "2026-10-12")
        XCTAssertEqual(ProgressMetrics.day(try date("2026-10-11"), blocks: [block]).planned, 0)
        XCTAssertEqual(ProgressMetrics.day(try date("2026-10-12"), blocks: [block]).planned, 1)
    }

    func testWeekdayEditPreservesEarlierPlans() throws {
        var block = try block(weekdays: [2]) // Monday
        block.weekdays = [3] // Tuesday
        block.recordScheduleChange(at: try date("2026-10-12"))
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-05")), true)
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-06")), false)
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-12")), false)
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-13")), true)
    }

    func testRestoreDoesNotCountArchivedDaysAsMisses() throws {
        var block = try block()
        block.archivedAt = try date("2026-10-07")
        block.recordScheduleChange(at: try date("2026-10-07"))
        block.archivedAt = nil
        block.recordScheduleChange(at: try date("2026-10-10"))
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-06")), true)
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-08")), false)
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-10")), true)
    }

    func testSameDaySwapUndoPreservesHistoryAndCompletion() throws {
        var block = try block(weekdays: [2])
        block.completedDates = ["2026-10-05"]
        block.weekdays = [3]
        block.recordScheduleChange(at: try date("2026-10-12"))
        block.weekdays = [2]
        block.recordScheduleChange(at: try date("2026-10-12"))
        XCTAssertTrue(block.hasValidScheduleHistory)
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-05")), true)
        XCTAssertEqual(block.wasPlanned(on: try date("2026-10-12")), true)
        XCTAssertEqual(block.completedDates, ["2026-10-05"])
    }

    func testCompletionStillCountsAfterSameDayArchive() throws {
        var block = try block()
        block.completedDates = ["2026-10-07"]
        block.archivedAt = try date("2026-10-07")
        block.recordScheduleChange(at: try date("2026-10-07"))
        let progress = ProgressMetrics.day(try date("2026-10-07"), blocks: [block])
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.planned, 1)
        XCTAssertEqual(progress.remaining, 0)
    }

    func testLegacyMigrationPreservesCompletionsWithoutInventingPlans() throws {
        let json = Data(#"{"name":"Legacy","startTime":"09:00","endTime":"10:00","completedDates":["2026-01-01"]}"#.utf8)
        let block = try JSONDecoder().decode(FocusBlock.self, from: json)
        XCTAssertFalse(block.hasCompleteScheduleHistory)
        XCTAssertNil(block.wasPlanned(on: try date("2026-01-01")))
        let progress = ProgressMetrics.day(try date("2026-01-01"), blocks: [block])
        XCTAssertEqual(progress.completed, 1)
        XCTAssertNil(progress.planned)
        let restored = try JSONDecoder().decode(FocusBlock.self, from: JSONEncoder().encode(block))
        XCTAssertEqual(restored.scheduleHistory, block.scheduleHistory)
        XCTAssertEqual(restored.completedDates, block.completedDates)
        XCTAssertFalse(restored.hasCompleteScheduleHistory)
    }

    func testStreakRemainsOpenTodayAndSkipsRestDays() throws {
        var block = try block(weekdays: [2, 3, 4, 5, 6])
        block.completedDates = ["2026-10-08", "2026-10-09"]
        XCTAssertEqual(ProgressMetrics.streak(in: [block], at: try date("2026-10-12")), 2)
        block.completedDates.insert("2026-10-12")
        XCTAssertEqual(ProgressMetrics.streak(in: [block], at: try date("2026-10-12")), 3)
    }

    func testMissedScheduledDayBreaksStreak() throws {
        var block = try block()
        block.completedDates = ["2026-10-09", "2026-10-10"]
        XCTAssertEqual(ProgressMetrics.streak(in: [block], at: try date("2026-10-12")), 0)
    }

    func testSelectedPeriodExcludesOlderCompletions() throws {
        var block = try block()
        block.completedDates = ["2026-10-05", "2026-10-12"]
        let history = ProgressMetrics.history(blocks: [block], endingAt: try date("2026-10-12"))
        XCTAssertEqual(history.count, 7)
        XCTAssertEqual(history.reduce(0) { $0 + $1.completed }, 1)
    }

    @MainActor
    func testBackupRoundTripRetainsArchiveIntervals() throws {
        var block = try block()
        block.archivedAt = try date("2026-10-07")
        block.recordScheduleChange(at: try date("2026-10-07"))
        block.archivedAt = nil
        block.recordScheduleChange(at: try date("2026-10-10"))
        let snapshot = AppSnapshot(version: 5, exportedAt: try date("2026-10-12"), blocks: [block], preferences: AppPreferences())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(AppSnapshot.self, from: encoder.encode(snapshot))
        XCTAssertNoThrow(try AppStore.validateBackup(restored))
        XCTAssertEqual(restored.blocks[0].wasPlanned(on: try date("2026-10-08")), false)
    }

    @MainActor
    func testBackupRejectsInvalidScheduleHistory() throws {
        var block = try block()
        block.scheduleHistory = [BlockScheduleRevision(effectiveDate: "not-a-date", weekdays: [9], isArchived: false)]
        let snapshot = AppSnapshot(version: 5, exportedAt: Date(), blocks: [block], preferences: AppPreferences())
        XCTAssertThrowsError(try AppStore.validateBackup(snapshot))
    }
}
