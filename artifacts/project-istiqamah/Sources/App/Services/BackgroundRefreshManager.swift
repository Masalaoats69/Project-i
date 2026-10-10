import BackgroundTasks
import Foundation
import WidgetKit

final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    static let taskIdentifier = "com.projectistiqamah.app.refresh"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    @discardableResult
    func schedule(blocks: [FocusBlock], now: Date = Date()) -> String? {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = nextRefreshDate(blocks: blocks, now: now)

        do {
            try BGTaskScheduler.shared.submit(request)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        let work = Task {
            do {
                let snapshot = try loadSnapshot()
                schedule(blocks: snapshot.blocks)

                let widgetSnapshot = Self.widgetSnapshot(from: snapshot)
                let widgetSaved = IstiqamahWidgetStore.save(widgetSnapshot)
                if widgetSaved {
                    WidgetCenter.shared.reloadAllTimelines()
                }

                async let notificationSync = NotificationManager.shared.sync(
                    blocks: snapshot.blocks,
                    preferences: snapshot.preferences
                )
                async let activitySync = LiveActivityManager.shared.sync(
                    blocks: snapshot.blocks,
                    pausedBlocks: snapshot.pausedBlocks ?? [:],
                    alertSoundFileName: snapshot.preferences.notificationSoundFileName
                )
                _ = await activitySync
                _ = await notificationSync
                task.setTaskCompleted(success: widgetSaved && !Task.isCancelled)
            } catch {
                schedule(blocks: [])
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            work.cancel()
        }
    }

    private func nextRefreshDate(blocks: [FocusBlock], now: Date) -> Date {
        let minimumDate = now.addingTimeInterval(1)
        let candidates = DateTools.schedule(for: blocks, around: now)
            .flatMap { item in
                let startWake = item.start > minimumDate
                    ? max(item.start.addingTimeInterval(-2 * 60), minimumDate)
                    : nil
                return [startWake, item.end].compactMap { $0 }
            }
            .filter { $0 >= minimumDate }

        return candidates.min() ?? now.addingTimeInterval(6 * 60 * 60)
    }

    private func loadSnapshot() throws -> AppSnapshot {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let url = support
            .appendingPathComponent("ProjectIstiqamah", isDirectory: true)
            .appendingPathComponent("data.json")
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppSnapshot.self, from: data)
    }

    // Rebuild from local data even when the app has not been opened since a block ended.
    static func widgetSnapshot(from appSnapshot: AppSnapshot, now: Date = Date()) -> IstiqamahWidgetSnapshot {
        let activeBlocks = appSnapshot.blocks.filter { $0.archivedAt == nil }
        let schedule = DateTools.schedule(for: activeBlocks, around: now, days: 2)
        let available = schedule.filter { !$0.block.completedDates.contains($0.dateKey) }
        let current = available.first { $0.start <= now && now < $0.end }
        let next = available.first { $0.start > now }
        let todayKey = DateTools.key(now)
        let today = schedule.filter { $0.dateKey == todayKey }
        let completedToday = today.filter { $0.block.completedDates.contains(todayKey) }.count
        let completedDates = Set(appSnapshot.blocks.flatMap(\.completedDates))
        var streakDate = now
        var currentStreak = 0
        while completedDates.contains(DateTools.key(streakDate)) {
            currentStreak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: streakDate) else {
                break
            }
            streakDate = previous
        }
        return IstiqamahWidgetSnapshot(
            updatedAt: now,
            personalMessage: appSnapshot.preferences.widgetMessage,
            plainText: appSnapshot.preferences.plainWidgetText,
            currentBlock: current.map { widgetSummary($0, pausedBlocks: appSnapshot.pausedBlocks ?? [:]) },
            nextBlock: next.map { widgetSummary($0, pausedBlocks: appSnapshot.pausedBlocks ?? [:]) },
            completedToday: completedToday,
            totalToday: today.count,
            currentStreak: currentStreak
        )
    }

    private static func widgetSummary(
        _ item: ScheduledBlock,
        pausedBlocks: [String: Date]
    ) -> WidgetBlockSummary {
        WidgetBlockSummary(
            id: item.block.id,
            name: item.block.name,
            dateKey: item.dateKey,
            startDate: item.start,
            endDate: item.end,
            isPaused: pausedBlocks[item.id] != nil
        )
    }
}
