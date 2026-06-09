//
//  Persistence.swift
//  Trippo
//
//  Created by Виталия Ткаченко on 02.06.2026.
//

import CoreData

struct PersistenceController {
    // Implementacja wzorca projektowego Singleton, zapewniająca globalny punkt dostępu do stosu Core Data.
    static let shared = PersistenceController()

    // Główny kontener persystencji zarządzający modelem danych, kontekstem oraz magazynem trwałym.
    let container: NSPersistentContainer

    // Inicjalizator struktury. Parametr 'inMemory' pozwala na utworzenie ulotnej bazy danych,
    // co jest optymalne dla testów jednostkowych oraz systemu podglądu (SwiftUI Preview).
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Trippo")
        
        // Jeśli flaga inMemory jest prawdziwa, przekierowujemy zapis do /dev/null,
        // co oznacza, że dane nie zostaną trwale zapisane na dysku urządzenia.
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Asynchroniczne ładowanie magazynów danych zdefiniowanych w modelu.
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Krytyczny błąd ładowania bazy danych. W środowisku produkcyjnym
                // należałoby to obsłużyć łagodniej, np. poprzez migrację lub logowanie błędu.
                fatalError("Nierozwiązany błąd Core Data: \(error), \(error.userInfo)")
            }
        })
        
        // Konfiguracja kontekstu: automatyczne scalanie zmian pochodzących z innych wątków
        // lub kontekstów tła (zapobiega to konfliktom danych).
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // Metoda pomocnicza umożliwiająca bezpieczne i wygodne zapisywanie bieżących zmian w kontekście zarządzanym.
    func saveContext() {
        let context = container.viewContext
        // Optymalizacja: wywołanie zapisu tylko wtedy, gdy w kontekście faktycznie zaszły modyfikacje.
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                // Krytyczny błąd podczas zapisu. Wymaga analizy szczegółów błędu (userInfo).
                fatalError("Nierozwiązany błąd zapisu: \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // Właściwość statyczna dostarczająca wyizolowane środowisko testowe dla podglądu (Canvas) w Xcode.
    static var preview: PersistenceController = {
        // Inicjalizacja kontrolera w trybie pamięci operacyjnej (inMemory).
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Wygenerowanie przykładowych danych testowych (tzw. mock data) w celu wizualizacji interfejsu.
        let newTrip = Trip(context: viewContext)
        newTrip.id = UUID()
        newTrip.title = "Weekend w Warszawie"
        newTrip.startDate = Date()
        // Symulacja podróży trwającej 3 dni (3 * 86400 sekund).
        newTrip.endDate = Date().addingTimeInterval(86400 * 3)
        newTrip.budget = 1500.0
        newTrip.tripType = "Wypoczynek"
        
        // Zapis wygenerowanych danych testowych do ulotnej bazy.
        do {
            try viewContext.save()
        } catch {
            let nserror = error as NSError
            fatalError("Nierozwiązany błąd danych testowych: \(nserror), \(nserror.userInfo)")
        }
        return result
    }()
}
