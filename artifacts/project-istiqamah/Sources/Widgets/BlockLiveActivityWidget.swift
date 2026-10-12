import ActivityKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct BlockLiveActivityWidget: Widget {
    private let timerAccent = Color(red: 0.95, green: 0.96, blue: 0.95)
    private let secondaryText = Color(red: 0.62, green: 0.67, blue: 0.65)
    private let divider = Color(red: 0.13, green: 0.16, blue: 0.15)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(BlockWidgetPalette.background(for: context.attributes.blockID, dark: true))
                .activitySystemActionForegroundColor(timerAccent)
                .widgetURL(context.attributes.deepLink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    dynamicIslandActions(context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundStyle(timerAccent)
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                        .frame(maxWidth: 120, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        blockIdentity(context)
                        metricGrid(context)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                IstiqamahMark(primary: accent(context), secondary: accent(context).opacity(0.65))
                    .frame(width: 16, height: 16)
                    .accessibilityLabel("\(blockTitle(context)), \(statusLabel(context))")
            } compactTrailing: {
                compactTimer(context)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(timerAccent)
                    .frame(width: 48, alignment: .trailing)
            } minimal: {
                minimalContent(context)
            }
            .widgetURL(context.attributes.deepLink)
            .keylineTint(accent(context))
            .contentMargins(.horizontal, 20, for: .expanded)
            .contentMargins(.bottom, 20, for: .expanded)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            blockIdentity(context)
            HStack(alignment: .center, spacing: 12) {
                IstiqamahMark(primary: accent(context), secondary: accent(context).opacity(0.65))
                    .frame(width: 30, height: 30)
                Spacer(minLength: 8)
                countdown(context)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundStyle(timerAccent)
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                activityActions(context)
            }

            Divider()
                .overlay(divider)

            metricGrid(context)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(blockTitle(context))
    }

    private func accent(_ context: ActivityViewContext<BlockActivityAttributes>) -> Color {
        BlockWidgetPalette.accent(for: context.attributes.blockID, dark: true)
    }

    private func blockIdentity(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        let intention = (context.state.intention ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return VStack(alignment: .leading, spacing: 3) {
            Text(context.state.blockName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent(context))
                .lineLimit(1)
            if !intention.isEmpty {
                Text(intention)
                    .font(.caption)
                    .foregroundStyle(timerAccent.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func activityActions(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        activityControls(context, buttonSize: 40)
    }

    private func dynamicIslandActions(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        activityControls(context, buttonSize: 36)
    }

    @ViewBuilder
    private func activityControls(
        _ context: ActivityViewContext<BlockActivityAttributes>,
        buttonSize: CGFloat
    ) -> some View {
        if !context.isStale {
            HStack(spacing: 8) {
                Button(intent: SetBlockPausedIntent(
                    blockID: context.attributes.blockID,
                    dateKey: context.attributes.dateKey,
                    paused: !context.state.isPaused
                )) {
                    Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: buttonSize * 0.36, weight: .bold))
                        .foregroundStyle(accent(context))
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Circle().fill(accent(context).opacity(0.30)))
                        .overlay {
                            Circle().stroke(accent(context).opacity(0.45))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(context.state.isPaused ? "Resume" : "Pause")

                Button(intent: EndBlockIntent(
                    blockID: context.attributes.blockID,
                    dateKey: context.attributes.dateKey
                )) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: buttonSize * 0.32, weight: .bold))
                        .foregroundStyle(timerAccent.opacity(0.88))
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Circle().fill(.white.opacity(0.10)))
                        .overlay {
                            Circle().stroke(.white.opacity(0.16))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End block")
            }
        }
    }

    private func compactTimer(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        Group {
            if context.isStale {
                Text("00:00")
            } else if let pausedAt = context.state.pausedAt {
                Text(formattedDuration(context.state.endDate.timeIntervalSince(pausedAt)))
            } else {
                Text(
                    timerInterval: context.state.startDate...context.state.endDate,
                    countsDown: true
                )
            }
        }
        .monospacedDigit()
        .minimumScaleFactor(0.68)
        .lineLimit(1)
        .accessibilityLabel("Time remaining")
    }

    @ViewBuilder
    private func minimalContent(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        IstiqamahMark(primary: accent(context), secondary: accent(context).opacity(0.65))
            .frame(width: 16, height: 16)
            .accessibilityLabel("\(blockTitle(context)), \(statusLabel(context))")
    }

    private func metricGrid(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        HStack(alignment: .top, spacing: 8) {
            metric(label: context.isStale ? "DURATION" : "ELAPSED") {
                elapsed(context)
            }
            metric(label: "START") {
                Text(context.state.startDate, style: .time)
            }
            metric(label: "END") {
                Text(context.state.endDate, style: .time)
            }
            metric(label: "STATUS") {
                Text(statusLabel(context))
            }
        }
    }

    private func metric<Content: View>(
        label: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(spacing: 3) {
            value()
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(timerAccent)
                .minimumScaleFactor(0.68)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func elapsed(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if context.isStale {
            Text(formattedDuration(context.state.endDate.timeIntervalSince(context.state.startDate)))
                .monospacedDigit()
        } else if let pausedAt = context.state.pausedAt {
            Text(formattedDuration(pausedAt.timeIntervalSince(context.state.startDate)))
                .monospacedDigit()
        } else {
            Text(context.state.startDate, style: .timer)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if context.isStale {
            Text("00:00")
                .monospacedDigit()
                .lineLimit(1)
        } else if let pausedAt = context.state.pausedAt {
            Text(formattedDuration(context.state.endDate.timeIntervalSince(pausedAt)))
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text(context.state.endDate, style: .timer)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func statusLabel(_ context: ActivityViewContext<BlockActivityAttributes>) -> String {
        if context.isStale { return "BLOCK ENDED" }
        if context.state.isPaused { return "PAUSED" }
        return "FOCUS"
    }

    private func blockTitle(_ context: ActivityViewContext<BlockActivityAttributes>) -> String {
        context.isStale ? "Block complete" : context.state.blockName
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#if DEBUG
private let previewAttributes = BlockActivityAttributes(
    blockID: UUID(),
    dateKey: "2026-09-17"
)

private let previewState = BlockActivityAttributes.ContentState(
    blockName: "Deep Work Session",
    startDate: Date().addingTimeInterval(-20 * 60),
    endDate: Date().addingTimeInterval(40 * 60),
    timeLabel: "09:00 – 10:00",
    pausedAt: nil,
    intention: "Start the day before the noise."
)

private let previewLongState = BlockActivityAttributes.ContentState(
    blockName: "Physics Revision and Practice",
    startDate: Date().addingTimeInterval(-35 * 60),
    endDate: Date().addingTimeInterval(3 * 60 * 60),
    timeLabel: "18:35 – 22:10",
    pausedAt: nil
)

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    BlockLiveActivityWidget()
} contentStates: {
    previewState
    previewLongState
}
#endif
