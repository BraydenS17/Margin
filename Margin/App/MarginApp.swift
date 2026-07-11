//
//  MarginApp.swift
//  Margin
//
//  Created by Brayden Sally on 2026-07-02.
//

import SwiftUI
import SwiftData

@main
struct MarginApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workspace.self,
            Notebook.self,
            Page.self,
            Block.self,
            PDFAsset.self,
            Assignment.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // Attach the undo manager before the context is ever mutated — SwiftData needs
            // an initial snapshot to exist before the first undo-registering change.
            container.mainContext.undoManager = UndoManager()
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
