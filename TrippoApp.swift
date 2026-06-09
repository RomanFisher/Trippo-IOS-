//
//  TrippoApp.swift
//  Trippo
//
//  Created by Виталия Ткаченко on 02.06.2026.
//

import SwiftUI

@main
struct TrippoApp: App {
    // Zapewnia to, że stos bazy danych (Core Data Stack) jest tworzony tylko raz podczas cyklu życia aplikacji.
    let persistenceController = PersistenceController.shared

    var body: some Scene {
       
        WindowGroup {
            // Wywołanie głównego widoku kontenerowego (TabView), w którym zawarta jest logika nawigacji.
            ContentView()
                // Wstrzyknięcie zależności: przekazanie zarządzanego kontekstu obiektów
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
