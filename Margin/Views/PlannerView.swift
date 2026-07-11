import SwiftUI
import SwiftData

/// The student planner: assignments grouped by urgency, linkable to a course notebook.
/// Sits alongside the notebook shelf as its own space — notes on one side, deadlines
/// on the other.
struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Assignment.createdAt) private var assignments: [Assignment]
    @Query(sort: \Notebook.sortIndex) private var notebooks: [Notebook]

    @State private var showingComposer = false

    private var grouped: [(PlannerSection, [Assignment])] {
        PlannerSection.grouped(assignments, now: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if assignments.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.0) { section, items in
                            sectionView(section, items)
                        }
                    }
                }
                .padding(24)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingComposer) {
                AssignmentComposer(courses: notebooks.filter { $0.parent == nil })
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Planner")
                    .font(.editorialDisplay(36))
                    .foregroundStyle(Theme.text)
                Spacer()
                FlatIconButton(systemName: "plus", label: "New Assignment") {
                    showingComposer = true
                }
                .accessibilityIdentifier("New Assignment")
            }
            AccentRule()
            let open = assignments.filter { !$0.isDone }.count
            Text("\(open) open · \(assignments.count - open) done")
                .metaLabel()
        }
    }

    private func sectionView(_ section: PlannerSection, _ items: [Assignment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.rawValue)
                .metaLabel()
                .foregroundStyle(section == .overdue ? Color.red : Theme.muted)
            VStack(spacing: 0) {
                ForEach(items) { assignment in
                    AssignmentRow(assignment: assignment, overdue: section == .overdue)
                    if assignment.id != items.last?.id {
                        Rectangle().fill(Theme.border).frame(height: 1)
                    }
                }
            }
            .background(Theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("Nothing due")
                .font(.editorialDisplay(24))
                .foregroundStyle(Theme.text)
            Button {
                showingComposer = true
            } label: {
                Text("Add your first assignment")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct AssignmentRow: View {
    @Bindable var assignment: Assignment
    var overdue: Bool

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 13) {
            Button {
                assignment.isDone.toggle()
                assignment.completedAt = assignment.isDone ? Date() : nil
            } label: {
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(assignment.isDone ? Theme.accent : Theme.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.isDone ? "Mark Incomplete" : "Mark Complete")

            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(assignment.isDone ? Theme.muted : Theme.text)
                    .strikethrough(assignment.isDone)
                HStack(spacing: 6) {
                    if let course = assignment.course {
                        Circle().fill(course.color.swatch).frame(width: 7, height: 7)
                        Text(course.title).metaLabel()
                    }
                    if let due = assignment.dueDate {
                        Text(due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .metaLabel()
                            .foregroundStyle(overdue ? Color.red : Theme.muted)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
                modelContext.delete(assignment)
            }
        }
    }
}

private struct AssignmentComposer: View {
    let courses: [Notebook]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var course: Notebook?
    @State private var hasDueDate = true
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("What's due?", text: $title)
                Picker("Course", selection: $course) {
                    Text("None").tag(Notebook?.none)
                    ForEach(courses) { notebook in
                        Text(notebook.title).tag(Notebook?.some(notebook))
                    }
                }
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Assignment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        let assignment = Assignment(
                            title: trimmed.isEmpty ? "Untitled Assignment" : trimmed,
                            dueDate: hasDueDate ? dueDate : nil,
                            course: course
                        )
                        modelContext.insert(assignment)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
