import Foundation

struct BlockScheduleRevision: Codable, Hashable {
    let effectiveDate: String
    let weekdays: Set<Int>
    let isArchived: Bool
}

extension FocusBlock {
    /// Changes affect today and future days. Earlier plans remain unchanged.
    mutating func recordScheduleChange(at date: Date = Date()) {
        let key = DateTools.key(date)
        let revision = BlockScheduleRevision(
            effectiveDate: key, weekdays: weekdays, isArchived: archivedAt != nil
        )
        if let previous = scheduleHistory.last,
           previous.weekdays == revision.weekdays,
           previous.isArchived == revision.isArchived { return }
        // Replace today's revision, including when an immediate swap is undone.
        scheduleHistory.removeAll { $0.effectiveDate >= key }
        scheduleHistory.append(revision)
    }

    /// nil means a legacy plan was never recorded, not that the day was missed.
    func wasPlanned(on date: Date) -> Bool? {
        let key = DateTools.key(date)
        guard let revision = scheduleHistory.last(where: { $0.effectiveDate <= key }) else {
            return hasCompleteScheduleHistory ? false : nil
        }
        return !revision.isArchived && revision.weekdays.contains(Calendar.current.component(.weekday, from: date))
    }

    var hasValidScheduleHistory: Bool {
        guard !scheduleHistory.isEmpty else { return false }
        let keys = scheduleHistory.map(\.effectiveDate)
        guard keys == keys.sorted(), Set(keys).count == keys.count,
              scheduleHistory.allSatisfy({
                  DateTools.date(from: $0.effectiveDate) != nil && !$0.weekdays.isEmpty &&
                  $0.weekdays.allSatisfy { (1...7).contains($0) }
              }),
              let latest = scheduleHistory.last else { return false }
        return latest.weekdays == weekdays && latest.isArchived == (archivedAt != nil)
    }
}

struct DayProgress: Identifiable {
    let date: Date
    let completed: Int
    let planned: Int?
    var id: String { DateTools.key(date) }
    var remaining: Int { max(0, (planned ?? completed) - completed) }
}

enum ProgressMetrics {
    static func day(_ date: Date, blocks: [FocusBlock]) -> DayProgress {
        let key = DateTools.key(date)
        let completed = blocks.filter { $0.completedDates.contains(key) }.count
        let plans = blocks.map { $0.wasPlanned(on: date) }
        // A completed occurrence always counts, even if today's schedule was changed afterward.
        let planned = plans.contains(where: { $0 == nil }) ? nil : blocks.filter {
            $0.wasPlanned(on: date) == true || $0.completedDates.contains(key)
        }.count
        return DayProgress(date: date, completed: completed, planned: planned)
    }

    static func history(blocks: [FocusBlock], endingAt now: Date, days: Int = 7) -> [DayProgress] {
        guard days > 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - days + 1, to: today)
                .map { day($0, blocks: blocks) }
        }
    }

    /// One completion earns a practice day. Today stays open; known rest days
    /// preserve a streak without adding to it. Unknown legacy gaps stop it.
    static func streak(in blocks: [FocusBlock], at now: Date) -> Int {
        let completed = Set(blocks.flatMap(\.completedDates))
        let todayKey = DateTools.key(now)
        guard let earliest = completed.filter({ $0 <= todayKey }).min() else { return 0 }
        var date = Calendar.current.startOfDay(for: now)
        var count = 0
        while DateTools.key(date) >= earliest {
            let key = DateTools.key(date)
            if completed.contains(key) {
                count += 1
            } else if key != todayKey {
                let progress = day(date, blocks: blocks)
                if progress.planned != 0 { break }
            }
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: date), previous < date else { break }
            date = previous
        }
        return count
    }
}
