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
    // Computed property ensures lazy initialization - CoreData setup happens
    // when first accessed (after app scene is ready), preventing CA Event errors
    private var persistenceController: PersistenceController {
        PersistenceController.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
