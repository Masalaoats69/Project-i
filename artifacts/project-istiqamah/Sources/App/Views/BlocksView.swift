import SwiftUI

struct BlocksView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft: FocusBlock?
    @State private var editMode: EditMode = .inactive
    @State private var restoreError: String?
    @State private var showingBlockGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.activeBlocks) { block in
                        blockCard(block)
                        .contentShape(Rectangle())
                        .onTapGesture { draft = block }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { draft = block }
                        .accessibilityHint("Double-tap to edit this important time block. Use Reorder to move it into another time slot.")
                        .listRowBackground(AppTheme.surface)
                        .swipeActions {
                            Button { store.archive(block) } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(AppTheme.warning)
                        }
                    }
                    .onMove(perform: moveBlocks)
                } footer: {
                    Text("Tap Reorder, then drag a block by its handle. The moved block and destination block exchange time slots.")
                }

                if !store.archivedBlocks.isEmpty {
                    Section("Archived") {
                        ForEach(store.archivedBlocks) { block in
                            HStack(spacing: 12) {
                                Image(systemName: "archivebox.fill")
                                    .foregroundStyle(AppTheme.tertiaryText)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(block.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(block.startTime) – \(block.endTime) · \(weekdaySummary(block.weekdays))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Button {
                                    draft = block
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Edit \(block.name)")
                                Button("Restore") {
                                    restoreError = store.restore(block)
                                }
                                .buttonStyle(.bordered)
                                .tint(AppTheme.primary)
                                .controlSize(.small)
                            }
                            .listRowBackground(AppTheme.surface)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Blocks")
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.primary)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        Button(editMode.isEditing ? "Done" : "Reorder") {
                            withAnimation(.snappy) {
                                editMode = editMode.isEditing ? .inactive : .active
                            }
                        }
                        Button {
                            showingBlockGuide = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("About blocks and important tasks")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { draft = FocusBlock(name: "", startTime: "09:00", endTime: "10:00", note: "") } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add block")
                }
            }
            .sheet(item: $draft) { block in
                BlockEditor(block: block, existingBlocks: store.activeBlocks) { saved in
                    if store.blocks.contains(where: { $0.id == saved.id }) {
                        store.update(saved)
                    } else {
                        store.add(saved)
                    }
                    draft = nil
                }
            }
            .sheet(isPresented: $showingBlockGuide) {
                BlockGuideView()
            }
            .alert("Could not restore block", isPresented: Binding(
                get: { restoreError != nil },
                set: { if !$0 { restoreError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreError ?? "")
            }
        }
    }

    private func moveBlocks(from sourceOffsets: IndexSet, to destination: Int) {
        let activeBlocks = store.activeBlocks
        guard sourceOffsets.count == 1,
              let sourceIndex = sourceOffsets.first,
              activeBlocks.indices.contains(sourceIndex) else { return }
        let targetIndex = destination > sourceIndex ? destination - 1 : destination
        guard activeBlocks.indices.contains(targetIndex), targetIndex != sourceIndex else { return }
        store.swapBlockTimeSlots(activeBlocks[sourceIndex].id, with: activeBlocks[targetIndex].id)
    }

    private func blockCard(_ block: FocusBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.elevatedSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Label("\(block.startTime) – \(block.endTime)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.top, 4)
            }

            HStack(spacing: 6) {
                Image(systemName: "repeat")
                Text(weekdaySummary(block.weekdays))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.primary)

            HStack(spacing: 6) {
                Image(systemName: block.actions.isEmpty ? "circle.dashed" : "checklist")
                Text(taskSummary(for: block))
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 10)
    }

    private func taskSummary(for block: FocusBlock) -> String {
        switch block.actions.count {
        case 0: "No important tasks added"
        case 1: "1 important task"
        default: "\(block.actions.count) important tasks"
        }
    }

    private func weekdaySummary(_ weekdays: Set<Int>) -> String {
        if weekdays == FocusBlock.everyDay { return "Every day" }
        return weekdays.sorted().map { DateTools.weekdayName($0) }.joined(separator: " · ")
    }
}

struct BlockGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 38))
                        .foregroundStyle(AppTheme.primary)
                    Text("What is a Block?")
                        .font(.title2.weight(.semibold))
                    Text("A Block protects time for work that matters. Create one for a repeated commitment like Deep Work, study, exercise, or your morning routine.")
                        .foregroundStyle(AppTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Set the days and time you want to protect.", systemImage: "clock")
                        Label("Add a short note to clarify the focus.", systemImage: "text.alignleft")
                        Label("Add important tasks only when they help you focus. They are optional, and a Block can still be complete without every task being checked.", systemImage: "checklist")
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primaryText)
                    Text("This app is for consistent, intentional time—not for every small errand.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(AppTheme.background)
            .navigationTitle("About Blocks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct BlockEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var block: FocusBlock
    @State private var errorMessage: String?
    let existingBlocks: [FocusBlock]
    let onSave: (FocusBlock) -> Void

    init(
        block: FocusBlock,
        existingBlocks: [FocusBlock],
        onSave: @escaping (FocusBlock) -> Void
    ) {
        _block = State(initialValue: block)
        self.existingBlocks = existingBlocks
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Block name", text: $block.name)
                    DatePicker(
                        "Start",
                        selection: timeBinding(\.startTime),
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("blockEditor.startTime")
                    DatePicker(
                        "End",
                        selection: timeBinding(\.endTime),
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("blockEditor.endTime")
                    TextField("Note", text: $block.note, axis: .vertical)
                } header: {
                    Text("Block")
                } footer: {
                    Text("Times use your iPhone's preferred 12-hour or 24-hour format.")
                }

                Section("Scheduled days") {
                    WeekdayPicker(selection: $block.weekdays)
                }

                Section("Actions · up to 5") {
                    ForEach($block.actions) { $action in
                        TextField("Action", text: $action.name)
                    }
                    .onDelete { block.actions.remove(atOffsets: $0) }
                    if block.actions.count < 5 {
                        Button("Add action", systemImage: "plus") {
                            block.actions.append(BlockAction(name: ""))
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(AppTheme.error)
                    }
                }
            }
            .navigationTitle(block.name.isEmpty ? "New Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<FocusBlock, String>) -> Binding<Date> {
        Binding(
            get: { DateTools.date(for: block[keyPath: keyPath]) ?? Date() },
            set: { block[keyPath: keyPath] = DateTools.timeString(from: $0) }
        )
    }

    private func save() {
        block.name = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
        block.startTime = block.startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        block.endTime = block.endTime.trimmingCharacters(in: .whitespacesAndNewlines)
        block.actions = block.actions
            .map { action in
                var action = action
                action.name = action.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return action
            }
            .filter { !$0.name.isEmpty }
            .prefix(5)
            .map { $0 }
        guard !block.name.isEmpty,
              DateTools.isValid(time: block.startTime),
              DateTools.isValid(time: block.endTime),
              !block.weekdays.isEmpty else {
            errorMessage = "Add a name, choose start and end times, and select at least one day."
            return
        }
        if let overlappingBlock = existingBlocks.first(where: {
            $0.id != block.id && DateTools.overlaps(block, $0)
        }) {
            errorMessage = "This time overlaps \(overlappingBlock.name). Choose an open time slot."
            return
        }
        onSave(block)
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let selected = selection.contains(weekday)
                Button {
                    if selected {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(DateTools.weekdayName(weekday, width: .narrow))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? AppTheme.onPrimary : AppTheme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(selected ? AppTheme.primary : AppTheme.elevatedSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DateTools.weekdayName(weekday))
                .accessibilityValue(selected ? "Selected" : "Not selected")
            }
        }
        .padding(.vertical, 4)
    }
}
