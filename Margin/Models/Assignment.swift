import Foundation
import SwiftData

@Model
final class Assignment {
    var id: UUID = UUID()
    var title: String = "Untitled Assignment"
    var detail: String = ""
    var dueDate: Date?
    var isDone: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()

    // The course this belongs to — notebooks double as courses.
    var course: Notebook?

    init(title: String = "Untitled Assignment", dueDate: Date? = nil, course: Notebook? = nil) {
        self.id = UUID()
        self.title = title
        self.dueDate = dueDate
        self.course = course
        self.createdAt = Date()
    }
}

/// Due-date buckets for the planner, computed as a pure function for testability.
enum PlannerSection: String, CaseIterable {
    case overdue = "Overdue"
    case today = "Today"
    case thisWeek = "This Week"
    case later = "Later"
    case done = "Done"

    static func section(for assignment: Assignment, now: Date, calendar: Calendar = .current) -> PlannerSection {
        if assignment.isDone { return .done }
        guard let due = assignment.dueDate else { return .later }
        let startOfToday = calendar.startOfDay(for: now)
        if due < startOfToday { return .overdue }
        if calendar.isDate(due, inSameDayAs: now) { return .today }
        if let weekOut = calendar.date(byAdding: .day, value: 7, to: startOfToday), due < weekOut {
            return .thisWeek
        }
        return .later
    }

    static func grouped(_ assignments: [Assignment], now: Date, calendar: Calendar = .current) -> [(PlannerSection, [Assignment])] {
        var buckets: [PlannerSection: [Assignment]] = [:]
        for assignment in assignments {
            buckets[section(for: assignment, now: now, calendar: calendar), default: []].append(assignment)
        }
        return PlannerSection.allCases.compactMap { section in
            guard var items = buckets[section], !items.isEmpty else { return nil }
            items.sort {
                switch ($0.dueDate, $1.dueDate) {
                case let (a?, b?): return a < b
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return $0.createdAt < $1.createdAt
                }
            }
            return (section, items)
        }
    }
}
