//
//  HumansApp.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import CoreData

@main
struct HumansApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
