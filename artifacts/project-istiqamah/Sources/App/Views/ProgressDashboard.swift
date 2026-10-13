import Charts
import SwiftUI

struct ProgressDashboard: View {
    @EnvironmentObject private var store: AppStore
    @State private var days = 7
    @State private var selectedDate: Date?
    @State private var chartSelection: Date?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                dashboard(now: context.date)
            }
            .background(AppTheme.background)
            .navigationTitle("Progress")
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.primary)
        }
    }

    private func dashboard(now: Date) -> some View {
        let history = ProgressMetrics.history(blocks: store.blocks, endingAt: now, days: days)
        let selected = history.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate ?? now) } ?? history.last ?? ProgressMetrics.day(now, blocks: store.blocks)
        let practiced = history.filter { $0.completed > 0 }.count
        let streak = ProgressMetrics.streak(in: store.blocks, at: now)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Progress period", selection: $days) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .onChange(of: days) { _, _ in
                    selectedDate = nil
                    chartSelection = nil
                }

                summary(history)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 140), spacing: 12)], spacing: 12) {
                    stat("Days practiced", value: "\(practiced)", symbol: "calendar")
                    stat("Current streak", value: "\(streak) \(streak == 1 ? "day" : "days")", symbol: "flame")
                }
                Text("A completion earns a practice day. Rest days keep your streak; today stays open until midnight.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                chart(history, selected: selected, now: now)
                dayDetail(selected, now: now)
                blockBreakdown(history)
            }
            .padding(18)
        }
    }

    private func summary(_ history: [DayProgress]) -> some View {
        let known = history.filter { $0.planned != nil }
        let planned = known.reduce(0) { $0 + ($1.planned ?? 0) }
        let completed = known.reduce(0) { $0 + $1.completed }
        let percentage = planned > 0 ? Int((Double(completed) / Double(planned) * 100).rounded()) : 0
        let hasUnknown = known.count != history.count

        return VStack(alignment: .leading, spacing: 16) {
            Label("One block at a time", systemImage: "leaf")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primary)
            if planned > 0 {
                Text("\(completed) of \(planned)")
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityLabel("\(completed) of \(planned) planned blocks completed")
                Text("planned blocks completed")
                    .font(.headline)
                ProgressView(value: Double(completed), total: Double(planned))
                    .tint(AppTheme.primary)
                    .accessibilityLabel("Completion rate")
                    .accessibilityValue("\(percentage) percent")
                Text("\(percentage)% complete · \(dateRange(known))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else if history.contains(where: { $0.completed > 0 }) {
                Text("Your progress is here.")
                    .font(.title2.weight(.semibold))
                Text("\(history.reduce(0) { $0 + $1.completed }) recorded completions in this period.")
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Every rhythm starts somewhere.")
                    .font(.title2.weight(.semibold))
                Text("Complete a scheduled block to start seeing your progress here.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if hasUnknown {
                Label("Earlier completions are saved. Completion rates use only days with a recorded plan.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Today’s planned blocks are included, even if they haven’t started yet.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .istiqamahCard()
    }

    private func chart(_ history: [DayProgress], selected: DayProgress, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your last \(days) days").font(.headline)
            Text("\(history.reduce(0) { $0 + $1.completed }) recorded completions · \(dateRange(history))")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Chart(history) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Blocks", day.completed)
                )
                .foregroundStyle(by: .value("Status", "Completed"))
                .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                .accessibilityValue(dayAccessibility(day, now: now))

                if day.remaining > 0 {
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Blocks", day.remaining)
                    )
                    .foregroundStyle(by: .value("Status", "Remaining"))
                    .accessibilityHidden(true)
                }
                if day.id == selected.id {
                    RuleMark(x: .value("Selected day", day.date, unit: .day))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .accessibilityHidden(true)
                }
            }
            .chartForegroundStyleScale(["Completed": AppTheme.primary, "Remaining": AppTheme.border])
            .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
            .chartYScale(domain: 0...max(1, history.map { max($0.planned ?? 0, $0.completed) }.max() ?? 1))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days == 7 ? 1 : 7)) { _ in
                    AxisValueLabel(format: days == 7 ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day())
                }
            }
            .chartXSelection(value: $chartSelection)
            .onChange(of: chartSelection) { _, date in
                if let date { selectedDate = date }
            }
            .frame(height: 200)

            // These buttons also make zero-height/rest days selectable with VoiceOver.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(history) { day in
                        Button {
                            selectedDate = day.date
                        } label: {
                            VStack(spacing: 6) {
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                Text(day.date.formatted(.dateTime.day())).fontWeight(.semibold)
                                Image(systemName: daySymbol(day, now: now))
                            }
                            .font(.caption)
                            .frame(minWidth: 48, minHeight: 72)
                            .padding(4)
                            .foregroundStyle(day.id == selected.id ? AppTheme.onPrimary : AppTheme.primaryText)
                            .background(day.id == selected.id ? AppTheme.primary : AppTheme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(dayAccessibility(day, now: now))
                        .accessibilityAddTraits(day.id == selected.id ? .isSelected : [])
                    }
                }
            }
            Text("Choose a day to see its blocks. A dash means a rest day; a question mark means the plan wasn’t recorded.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(18)
        .istiqamahCard()
    }

    private func dayDetail(_ day: DayProgress, now: Date) -> some View {
        let blocks = store.blocks.filter { $0.wasPlanned(on: day.date) == true || $0.completedDates.contains(day.id) }
        return VStack(alignment: .leading, spacing: 14) {
            Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.headline)
            Text(dayAccessibility(day, now: now))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            ForEach(blocks) { block in
                let complete = block.completedDates.contains(day.id)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(complete ? AppTheme.completed : AppTheme.secondaryText)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.name).font(.subheadline.weight(.medium))
                        Text(complete ? "Completed" : (Calendar.current.isDate(day.date, inSameDayAs: now) ? "Open today" : "Not completed"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .istiqamahCard()
    }

    private func blockBreakdown(_ history: [DayProgress]) -> some View {
        let keys = Set(history.map(\.id))
        let blocks = store.blocks.filter { block in
            !block.completedDates.isDisjoint(with: keys) || history.contains { block.wasPlanned(on: $0.date) == true }
        }.sorted { first, second in
            let a = first.completedDates.intersection(keys).count
            let b = second.completedDates.intersection(keys).count
            return a == b ? first.name.localizedStandardCompare(second.name) == .orderedAscending : a > b
        }
        return VStack(alignment: .leading, spacing: 16) {
            Text("By block").font(.headline)
            Text("Completions in the last \(days) days")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            if blocks.isEmpty {
                Text("Your blocks will appear here as you build your routine.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            ForEach(blocks) { block in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.name).font(.subheadline.weight(.medium))
                        if block.archivedAt != nil {
                            Label("Archived", systemImage: "archivebox")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    Spacer(minLength: 4)
                    Text("\(block.completedDates.intersection(keys).count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppTheme.primary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .istiqamahCard()
    }

    private func stat(_ label: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(AppTheme.primary).accessibilityHidden(true)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
            Text(label).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private func dateRange(_ history: [DayProgress]) -> String {
        guard let first = history.first, let last = history.last else { return "No recorded plans" }
        return "\(first.date.formatted(.dateTime.month(.abbreviated).day())) – \(last.date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func daySymbol(_ day: DayProgress, now: Date) -> String {
        if day.planned == nil { return "questionmark" }
        if day.planned == 0 { return "minus" }
        if day.remaining == 0 { return "checkmark" }
        return Calendar.current.isDate(day.date, inSameDayAs: now) ? "clock" : "circle.dotted"
    }

    private func dayAccessibility(_ day: DayProgress, now: Date) -> String {
        guard let planned = day.planned else { return "\(day.completed) completed · plan not recorded" }
        if planned == 0 { return "Rest day · no blocks planned" }
        let suffix = Calendar.current.isDate(day.date, inSameDayAs: now) ? " · Today is still in progress" : ""
        return "\(day.completed) of \(planned) completed\(suffix)"
    }
}
