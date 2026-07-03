import Foundation

struct PageTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let systemImage: String
    let background: PageBackground
    let blockSpecs: [BlockSpec]
}

struct BlockSpec {
    let type: BlockType
    var text: String = ""
    var isChecked: Bool = false
    var table: BlockTableData? = nil
}

extension PageTemplate {
    static let blank = PageTemplate(
        name: "Blank",
        description: "An empty page",
        systemImage: "doc",
        background: .blank,
        blockSpecs: []
    )

    static let dayPlanner = PageTemplate(
        name: "Day Planner",
        description: "Hourly schedule with top priorities and notes",
        systemImage: "calendar.day.timeline.left",
        background: .blank,
        blockSpecs: [
            BlockSpec(type: .heading, text: "Monday, July 6"),
            BlockSpec(type: .table, table: BlockTableData(rows: [
                ["Time", "Plan"],
                ["7:00 AM", ""],
                ["8:00 AM", ""],
                ["9:00 AM", ""],
                ["10:00 AM", ""],
                ["11:00 AM", ""],
                ["12:00 PM", ""],
                ["1:00 PM", ""],
                ["2:00 PM", ""],
                ["3:00 PM", ""],
                ["4:00 PM", ""],
                ["5:00 PM", ""],
                ["6:00 PM", ""],
                ["7:00 PM", ""],
                ["8:00 PM", ""]
            ])),
            BlockSpec(type: .callout, text: "Top 3 Priorities"),
            BlockSpec(type: .checkbox, text: "Priority 1"),
            BlockSpec(type: .checkbox, text: "Priority 2"),
            BlockSpec(type: .checkbox, text: "Priority 3"),
            BlockSpec(type: .heading, text: "Notes"),
            BlockSpec(type: .paragraph, text: "")
        ]
    )

    static let courseLandingPage = PageTemplate(
        name: "Course Landing Page",
        description: "Syllabus, calendar, and assignments in one place",
        systemImage: "graduationcap",
        background: .blank,
        blockSpecs: [
            BlockSpec(type: .heading, text: "Course Name & Number"),
            BlockSpec(type: .table, table: BlockTableData(rows: [
                ["Instructor", ""],
                ["Office Hours", ""],
                ["Email", ""],
                ["Location", ""]
            ])),
            BlockSpec(type: .heading, text: "Syllabus"),
            BlockSpec(type: .bulletList, text: "Grading breakdown"),
            BlockSpec(type: .bulletList, text: "Attendance policy"),
            BlockSpec(type: .bulletList, text: "Late work policy"),
            BlockSpec(type: .bulletList, text: "Required materials"),
            BlockSpec(type: .heading, text: "Course Calendar"),
            BlockSpec(type: .table, table: BlockTableData(rows: [
                ["Week", "Topic", "Reading", "Due"],
                ["1", "", "", ""],
                ["2", "", "", ""],
                ["3", "", "", ""],
                ["4", "", "", ""],
                ["5", "", "", ""]
            ])),
            BlockSpec(type: .heading, text: "Assignments"),
            BlockSpec(type: .checkbox, text: "Assignment 1"),
            BlockSpec(type: .checkbox, text: "Assignment 2"),
            BlockSpec(type: .checkbox, text: "Assignment 3")
        ]
    )

    static let weeklyStudyPlanner = PageTemplate(
        name: "Weekly Study Planner",
        description: "A week-at-a-glance grid plus weekly goals",
        systemImage: "calendar",
        background: .blank,
        blockSpecs: [
            BlockSpec(type: .heading, text: "Week Of"),
            BlockSpec(type: .table, table: BlockTableData(rows: [
                ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                ["Morning", "", "", "", "", "", "", ""],
                ["Afternoon", "", "", "", "", "", "", ""],
                ["Evening", "", "", "", "", "", "", ""]
            ])),
            BlockSpec(type: .heading, text: "Weekly Goals"),
            BlockSpec(type: .checkbox, text: "Goal 1"),
            BlockSpec(type: .checkbox, text: "Goal 2"),
            BlockSpec(type: .checkbox, text: "Goal 3")
        ]
    )

    static let cornellNotes = PageTemplate(
        name: "Lecture / Cornell Notes",
        description: "Cues, notes, and a summary for lecture-style note taking",
        systemImage: "text.book.closed",
        background: .ruled,
        blockSpecs: [
            BlockSpec(type: .heading, text: "Lecture Title — Date"),
            BlockSpec(type: .callout, text: "Cornell layout: jot cues and questions in the margin as you write your notes below, then summarize at the end."),
            BlockSpec(type: .paragraph, text: ""),
            BlockSpec(type: .heading, text: "Summary"),
            BlockSpec(type: .paragraph, text: ""),
            BlockSpec(type: .heading, text: "Key Questions"),
            BlockSpec(type: .bulletList, text: ""),
            BlockSpec(type: .bulletList, text: "")
        ]
    )

    static let readingTracker = PageTemplate(
        name: "Reading & Assignment Tracker",
        description: "Track readings and due dates with a checklist",
        systemImage: "checklist",
        background: .blank,
        blockSpecs: [
            BlockSpec(type: .heading, text: "Reading & Assignment Tracker"),
            BlockSpec(type: .table, table: BlockTableData(rows: [
                ["Reading", "Due Date", "Status", "Notes"],
                ["Ch. 1 — Introduction", "", "Not Started", ""],
                ["Ch. 2 — Overview", "", "Not Started", ""],
                ["Ch. 3 — Case Study", "", "Not Started", ""]
            ])),
            BlockSpec(type: .checkbox, text: "Finish Ch. 1"),
            BlockSpec(type: .checkbox, text: "Finish Ch. 2"),
            BlockSpec(type: .checkbox, text: "Finish Ch. 3")
        ]
    )

    static let all: [PageTemplate] = [
        .blank,
        .dayPlanner,
        .courseLandingPage,
        .weeklyStudyPlanner,
        .cornellNotes,
        .readingTracker
    ]
}
