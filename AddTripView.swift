//
//  AddTripView.swift
//  Trippo
//
//  Created by Виталия Ткаченко on 02.06.2026.
//

import SwiftUI

struct AddTripView: View {
    // Zarządzanie kontekstem środowiska Core Data, umożliwiającym operacje na bazie danych (zapis, edycja).
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var tripTitle: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(86400) // Domyślnie ustawione na +1 dzień (86400 sekund).
    @State private var budget: Double = 1000.0
    
    @State private var selectedTripType: String = "Wypoczynek"
    let tripTypes = ["Wypoczynek", "Biznes", "Sport", "Inne"]
    
    // Stan kontrolujący wyświetlanie systemowego komunikatu (Alert) po pomyślnym zapisie.
    @State private var showSuccessAlert = false

    // Właściwość obliczana realizująca logiczną walidację poprawności danych formularza.
    private var isFormValid: Bool {
        // Weryfikacja, czy nazwa nie jest pusta oraz czy zawiera minimum 3 znaki po usunięciu białych znaków.
        let isTitleValid = !tripTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && tripTitle.count >= 3
        
        let areDatesValid = endDate >= startDate
        let isBudgetValid = budget > 0
        
        return isTitleValid && areDatesValid && isBudgetValid
    }

    var body: some View {
        NavigationStack {
            Form {
                // Sekcja wprowadzania danych identyfikacyjnych oraz kategorii wyjazdu.
                Section(header: Text("Informacje ogólne").foregroundColor(.blue)) {
                    TextField("Nazwa podróży (min. 3 znaki)", text: $tripTitle)
                        .autocorrectionDisabled() // Wyłączenie automatycznej korekty tekstu.
                    
                    Picker("Typ podróży", selection: $selectedTripType) {
                        ForEach(tripTypes, id: \.self) { type in
                            Text(type)
                        }
                    }
                }
                
                // Sekcja konfiguracji ram czasowych wraz z walidacją kontekstową.
                Section(header: Text("Termin podróży").foregroundColor(.blue)) {
                    DatePicker("Data rozpoczęcia", selection: $startDate, displayedComponents: .date)
                    DatePicker("Data zakończenia", selection: $endDate, displayedComponents: .date)
                    
                    // Warunkowe wyświetlanie komunikatu o błędzie w przypadku niepoprawnego zakresu dat.
                    if endDate < startDate {
                        Text("Data końca nie może być wcześniej niż początku!")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Sekcja planowania finansowego z wykorzystaniem suwaka dynamicznego.
                Section(header: Text("Budżet").foregroundColor(.blue)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Budżet:")
                            Spacer()
                            Text("\(Int(budget)) PLN")
                                .bold()
                                .foregroundColor(.green)
                        }
                        Slider(value: $budget, in: 0...15000, step: 100)
                    }
                }
                
                // Sekcja zawierająca interaktywny przycisk zatwierdzający formularz.
                Section {
                    Button(action: saveTrip) {
                        HStack {
                            Spacer()
                            Text("Zapisz Podróż")
                                .bold()
                            Spacer()
                        }
                    }
                    // Blokowanie interakcji z przyciskiem w przypadku niespełnienia kryteriów walidacji.
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? .blue : .gray)
                }
            }
            .navigationTitle("Nowa Podróż")
                .alert("Sukces", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    // Przywracanie domyślnych wartości pól formularza po zakończeniu operacji zapisu.
                    tripTitle = ""
                    budget = 1000.0
                    startDate = Date()
                    endDate = Date().addingTimeInterval(86400)
                }
            } message: {
                Text("Podróż została pomyślnie zapisana!")
            }
        }
    }
    
    // Metoda odpowiedzialna за tworzenie nowej instancji encji Core Data.
    private func saveTrip() {
        // Inicjalizacja nowego obiektu klasy Trip w bieżącym kontekście zarządzanym.
        let newTrip = Trip(context: viewContext)
        newTrip.id = UUID()
        newTrip.title = tripTitle
        newTrip.startDate = startDate
        newTrip.endDate = endDate
        newTrip.budget = budget
        newTrip.tripType = selectedTripType
        
        // Blok try-catch służący do bezpiecznego wykonania operacji zapisu w pamięci trwałej.
        do {
            try viewContext.save() // Wywołanie metody utrwalającej dane w bazie Core Data.
            showSuccessAlert = true // Aktywacja stanu wywołującego powiadomienie o sukcesie.
        } catch {
            let nserror = error as NSError
            print("Błąd zapisu w Core Data: \(nserror), \(nserror.userInfo)")
        }
    }
}

#Preview {
    AddTripView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
