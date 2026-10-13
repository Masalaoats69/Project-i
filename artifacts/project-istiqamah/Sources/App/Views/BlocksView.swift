import SwiftUI

private struct ScheduleSwap {
    let first: FocusBlock
    let second: FocusBlock
}

struct BlocksView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft: FocusBlock?
    @State private var restoreError: String?
    @State private var showingBlockGuide = false
    @State private var showingArchived = false
    @State private var isSwapping = false
    @State private var swapSourceID: UUID?
    @State private var pendingSwap: ScheduleSwap?
    @State private var undoSwap: ScheduleSwap?

    private var activeBlocks: [FocusBlock] {
        store.activeBlocks.sorted {
            if $0.startTime == $1.startTime { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.startTime < $1.startTime
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    introduction
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))

                    if activeBlocks.isEmpty {
                        ContentUnavailableView {
                            Label("Make room for what matters", systemImage: "calendar.badge.plus")
                        } description: {
                            Text("Give one part of your day a little structure. Actions are optional.")
                        } actions: {
                            Button("Create a block", systemImage: "plus", action: addBlock)
                                .buttonStyle(.borderedProminent)
                        }
                        .listRowBackground(AppTheme.surface)
                    }

                    ForEach(activeBlocks) { block in
                        Button {
                            select(block)
                        } label: {
                            blockCard(block)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(isSwapping ? "Choose this block to swap schedules." : "Edit this block.")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                        .swipeActions(allowsFullSwipe: false) {
                            if !isSwapping {
                                Button {
                                    undoSwap = nil
                                    store.archive(block)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(AppTheme.warning)
                            }
                        }
                    }

                    if let undoSwap {
                        HStack {
                            Label("Schedules swapped", systemImage: "checkmark.circle")
                                .font(.subheadline)
                            Spacer()
                            Button("Undo") {
                                store.swapBlockTimeSlots(undoSwap.first.id, with: undoSwap.second.id)
                                self.undoSwap = nil
                            }
                            .frame(minHeight: 44)
                        }
                        .listRowBackground(AppTheme.elevatedSurface)
                    }
                }
                .listRowSeparator(.hidden)

                if !store.archivedBlocks.isEmpty {
                    Section {
                        DisclosureGroup(isExpanded: $showingArchived) {
                            ForEach(store.archivedBlocks) { block in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(block.name).font(.headline)
                                    Text(scheduleSummary(block))
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    HStack {
                                        Button("Edit", systemImage: "pencil") {
                                            undoSwap = nil
                                            draft = block
                                        }
                                        Spacer()
                                        Button("Restore", systemImage: "arrow.uturn.backward") {
                                            undoSwap = nil
                                            restoreError = store.restore(block)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .frame(minHeight: 44)
                                    .disabled(isSwapping)
                                }
                                .padding(.vertical, 6)
                            }
                        } label: {
                            Label("Archived · \(store.archivedBlocks.count)", systemImage: "archivebox")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .listRowBackground(AppTheme.surface)
                }
            }
            .listSectionSpacing(16)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Blocks")
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.primary)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSwapping ? "Done" : "Swap") {
                        isSwapping.toggle()
                        swapSourceID = nil
                    }
                    .disabled(activeBlocks.count < 2)
                    .accessibilityLabel(isSwapping ? "Done" : "Swap schedules")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingBlockGuide = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About blocks and actions")
                    Button(action: addBlock) { Image(systemName: "plus") }
                        .accessibilityLabel("Add block")
                        .disabled(isSwapping)
                }
            }
            .sheet(item: $draft) { block in
                BlockEditor(block: block, isNew: !store.blocks.contains(where: { $0.id == block.id }), existingBlocks: store.activeBlocks) { saved in
                    if store.blocks.contains(where: { $0.id == saved.id }) {
                        store.update(saved)
                    } else {
                        store.add(saved)
                    }
                    draft = nil
                }
            }
            .sheet(isPresented: $showingBlockGuide) { BlockGuideView() }
            .alert("Could not restore block", isPresented: Binding(
                get: { restoreError != nil }, set: { if !$0 { restoreError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: { Text(restoreError ?? "") }
            .confirmationDialog("Swap these schedules?", isPresented: Binding(
                get: { pendingSwap != nil }, set: { if !$0 { pendingSwap = nil } }
            ), titleVisibility: .visible, presenting: pendingSwap) { swap in
                Button("Swap days and times") {
                    store.swapBlockTimeSlots(swap.first.id, with: swap.second.id)
                    undoSwap = swap
                    swapSourceID = nil
                    isSwapping = false
                }
                Button("Cancel", role: .cancel) { swapSourceID = nil }
            } message: { swap in
                Text("\(swap.first.name) → \(scheduleSummary(swap.second))\n\n\(swap.second.name) → \(scheduleSummary(swap.first))\n\nEarlier progress stays the same.")
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSwapping ? "Swap schedules" : "A little structure. More intention.")
                .font(.title3.weight(.semibold))
            Text(isSwapping
                 ? (swapSourceID == nil ? "Choose the first block. Swapping exchanges both days and times." : "Now choose the second block. You’ll review the change before saving.")
                 : "\(activeBlocks.count) active \(activeBlocks.count == 1 ? "block" : "blocks") · Built around your week")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func blockCard(_ block: FocusBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.primary)
                    .frame(width: 4, height: 38)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(block.name).font(.headline)
                    Text(DateTools.timeRange(for: block))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: isSwapping
                      ? (swapSourceID == block.id ? "checkmark.circle.fill" : "circle")
                      : "chevron.right")
                    .foregroundStyle(isSwapping ? AppTheme.primary : AppTheme.secondaryText)
                    .accessibilityHidden(true)
            }
            Text(DateTools.durationLabel(for: block))
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.primary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { blockMetadata(block) }
                VStack(alignment: .leading, spacing: 8) { blockMetadata(block) }
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            if !block.note.isEmpty {
                Text(block.note)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .istiqamahCard()
        .overlay {
            if swapSourceID == block.id {
                RoundedRectangle(cornerRadius: 22).stroke(AppTheme.primary, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func blockMetadata(_ block: FocusBlock) -> some View {
        Label(DateTools.weekdaySummary(block.weekdays), systemImage: "repeat")
        if !block.actions.isEmpty {
            Label("\(block.actions.count) \(block.actions.count == 1 ? "action" : "actions")", systemImage: "checklist")
        }
    }

    private func scheduleSummary(_ block: FocusBlock) -> String {
        "\(DateTools.timeRange(for: block)) · \(DateTools.weekdaySummary(block.weekdays))"
    }

    private func addBlock() {
        undoSwap = nil
        draft = FocusBlock(name: "", startTime: "09:00", endTime: "10:00", note: "")
    }

    private func select(_ block: FocusBlock) {
        guard isSwapping else {
            undoSwap = nil
            draft = block
            return
        }
        if let source = activeBlocks.first(where: { $0.id == swapSourceID }), source.id != block.id {
            pendingSwap = ScheduleSwap(first: source, second: block)
        } else {
            swapSourceID = swapSourceID == block.id ? nil : block.id
        }
    }
}

struct BlockGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.primary)
                        .accessibilityHidden(true)
                    Text("Time for what matters.").font(.title2.weight(.semibold))
                    Text("A block protects time for a repeated commitment: study, exercise, work, or your morning routine.")
                        .foregroundStyle(AppTheme.secondaryText)
                    Label("Choose the days and time you want to protect.", systemImage: "calendar")
                    Label("Add a note to remind yourself of the intention.", systemImage: "text.alignleft")
                    Label("Add up to five small actions, if they help. You can complete a block without checking every action.", systemImage: "checklist")
                    Text("Build a rhythm you can return to.")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(AppTheme.background)
            .foregroundStyle(AppTheme.primaryText)
            .navigationTitle("About Blocks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(AppTheme.primary)
    }
}

private struct BlockEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var block: FocusBlock
    @State private var errorMessage: String?
    let isNew: Bool
    let existingBlocks: [FocusBlock]
    let onSave: (FocusBlock) -> Void

    init(block: FocusBlock, isNew: Bool, existingBlocks: [FocusBlock], onSave: @escaping (FocusBlock) -> Void) {
        _block = State(initialValue: block)
        self.isNew = isNew
        self.existingBlocks = existingBlocks
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Intention") {
                    TextField("Block name", text: $block.name)
                        .accessibilityIdentifier("blockEditor.name")
                        .submitLabel(.done)
                    TextField("A note to yourself (optional)", text: $block.note, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("blockEditor.note")
                }
                Section {
                    DatePicker("Start", selection: timeBinding(\.startTime), displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("blockEditor.startTime")
                    DatePicker("End", selection: timeBinding(\.endTime), displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("blockEditor.endTime")
                    Label(DateTools.durationLabel(for: block), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primary)
                        .accessibilityIdentifier("blockEditor.duration")
                    if let conflict {
                        Label("Overlaps \(conflict.name). Choose another time or day.", systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.error)
                    }
                } header: {
                    Text("Time")
                } footer: { Text("Times follow your iPhone’s clock format. An end time before the start finishes the next day.") }

                Section("Repeat on") {
                    WeekdayPicker(selection: $block.weekdays)
                }
                Section {
                    ForEach($block.actions) { $action in
                        TextField("Action", text: $action.name)
                            .submitLabel(.done)
                    }
                    .onDelete { block.actions.remove(atOffsets: $0) }
                    if block.actions.count < 5 {
                        Button("Add action", systemImage: "plus") { block.actions.append(BlockAction(name: "")) }
                    }
                } header: {
                    Text("Actions · \(block.actions.count)/5")
                } footer: { Text("Optional steps that help you focus. Swipe an action to remove it.") }
            }
            .keyboardDismissal()
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(isNew ? "New Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
            }
            .alert("Check this block", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
        .tint(AppTheme.primary)
    }

    private var conflict: FocusBlock? {
        existingBlocks.first { $0.id != block.id && DateTools.overlaps(block, $0) }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<FocusBlock, String>) -> Binding<Date> {
        Binding(
            get: { DateTools.date(for: block[keyPath: keyPath]) ?? Date() },
            set: { block[keyPath: keyPath] = DateTools.timeString(from: $0) }
        )
    }

    private func save() {
        block.name = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
        block.note = block.note.trimmingCharacters(in: .whitespacesAndNewlines)
        block.actions = block.actions.compactMap { action in
            var action = action
            action.name = action.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return action.name.isEmpty ? nil : action
        }
        guard !block.name.isEmpty, !block.weekdays.isEmpty else {
            errorMessage = "Add a name and select at least one day."
            return
        }
        guard DateTools.isValid(time: block.startTime), DateTools.isValid(time: block.endTime), block.startTime != block.endTime else {
            errorMessage = "Choose different start and end times. For an overnight block, set the end earlier than the start."
            return
        }
        if let conflict {
            errorMessage = "This schedule overlaps \(conflict.name). Choose another time or day."
            return
        }
        onSave(block)
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    @ScaledMetric(relativeTo: .subheadline) private var dayWidth: CGFloat = 64
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: dayWidth), spacing: 8)] }
    private var weekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { weekday in
                    let selected = selection.contains(weekday)
                    Button {
                        if selected { selection.remove(weekday) } else { selection.insert(weekday) }
                    } label: {
                        Text(DateTools.weekdayName(weekday))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selected ? AppTheme.onPrimary : AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? AppTheme.primary : AppTheme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { presets }
                VStack(alignment: .leading, spacing: 8) { presets }
            }
            .buttonStyle(.borderless)
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var presets: some View {
        Button("Every day") { selection = FocusBlock.everyDay }.frame(minHeight: 44)
        Button("Weekdays") { selection = [2, 3, 4, 5, 6] }.frame(minHeight: 44)
        Button("Weekend") { selection = [1, 7] }.frame(minHeight: 44)
    }
}
