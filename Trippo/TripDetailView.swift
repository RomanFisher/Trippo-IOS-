//
//   TripDetailView.swift
//   Trippo
//
//   Created by Виталия Ткаченко on 02.06.2026.
//

import SwiftUI
import CoreData

struct TripDetailView: View {
    // Środowiskowy kontekst Core Data, niezbędny do modyfikacji i usuwania powiązanych encji.
    @Environment(\.managedObjectContext) private var viewContext
    
    // Obiekt podróży (Trip) przekazany z widoku nadrzędnego.
    // Modyfikator @ObservedObject gwarantuje odświeżenie interfejsu po wykryciu zmian w tym obiekcie.
    @ObservedObject var trip: Trip
    
    // Dynamiczne zapytanie do bazy danych pobierające lokalizacje.
    @FetchRequest private var locations: FetchedResults<Location>
    
    // Stan kontrolujący aktywną zakładkę w interfejsie (0 - Plan podróży, 1 - Lista wydatków).
    @State private var selectedSegment = 0
    
    // Stany zarządzające widocznością i danymi formularza wprowadzania nowych wydatków.
    @State private var showAddExpenseModal = false
    @State private var expenseAmount = ""
    @State private var expenseCategory = "Jedzenie"
    @State private var expenseNote = ""
    
    // Wymagany stan przechowujący referencję do wybranego miejsca powiązanego z danym wydatkiem.
    @State private var selectedLocationForExpense: Location?
    
    // Predefiniowana tablica kategorii kosztów do wyboru w formularzu.
    let categories = ["Jedzenie", "Transport", "Nocleg", "Rozrywka", "Inne"]
    
    // Niestandardowy inicjalizator widoku, pozwalający na dynamiczne skonfigurowanie FetchRequest.
    init(trip: Trip) {
        self.trip = trip
        
        // Zabezpieczenie sprawdzające, czy obiekt posiada prawidłowy kontekst zarządzany.
        if trip.managedObjectContext != nil {
            // Inicjalizacja zapytania filtrującego (NSPredicate) lokalizacje wyłącznie dla tej konkretnej podróży
            // oraz sortującego wyniki rosnąco według czasu wizyty.
            self._locations = FetchRequest<Location>(
                entity: Location.entity(),
                sortDescriptors: [NSSortDescriptor(keyPath: \Location.visitTime, ascending: true)],
                predicate: NSPredicate(format: "trip == %@", trip),
                animation: .default
            )
        } else {
            // Puste zapytanie zapobiegające błędom aplikacji w przypadku braku kontekstu (np. podczas usuwania).
            self._locations = FetchRequest<Location>(
                entity: Location.entity(),
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
        }
    }
    
    // Właściwość obliczana sumująca wszystkie wydatki skojarzone z miejscami przypisanymi do tej podróży.
    private var totalSpent: Double {
        var sum: Double = 0
        for location in locations {
            // Bezpieczne rzutowanie relacji Core Data (NSSet) na strukturę Set w Swift.
            if let expensesSet = location.expenses as? Set<Expense> {
                sum += expensesSet.reduce(0) { $0 + $1.amount }
            }
        }
        return sum
    }

    var body: some View {
        VStack {
            // Sekcja prezentująca kontrolę finansów: planowany budżet vs dotychczasowe wydatki.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Budżet podróży:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(trip.budget)) PLN")
                        .font(.headline)
                        .bold()
                }
                
                HStack {
                    Text("Wydano ogółem:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(totalSpent)) PLN")
                        .font(.title3)
                        .bold()
                        // Dynamiczna zmiana koloru wskaźnika w przypadku przekroczenia zaplanowanego budżetu.
                        .foregroundColor(totalSpent > trip.budget ? .red : .green)
                }
                
                // Wizualizacja zużycia budżetu przy pomocy nakładających się prostokątów (pasek postępu).
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(totalSpent > trip.budget ? Color.red : Color.blue)
                            // Bezpieczne obliczanie szerokości paska postępu chroniące przed dzieleniem przez zero.
                            .frame(width: min(CGFloat(totalSpent / (trip.budget > 0 ? trip.budget : 1)) * geo.size.width, geo.size.width), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            
            // Przełącznik segmentowy umożliwiający nawigację pomiędzy widokiem osi czasu a listą wydatków.
            Picker("Menu", selection: $selectedSegment) {
                Text("Plan miejsca").tag(0)
                Text("Wydatki").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 5)
            
            // Renderowanie warunkowe zawartości na podstawie wybranej opcji w kontrolce Picker.
            if selectedSegment == 0 {
                if locations.isEmpty {
                    emptyStateView(msg: "Brak dodanych miejsc. Dodaj punkty na mapie!")
                } else {
                    List {
                        ForEach(locations) { location in
                            timelineRow(for: location)
                        }
                        // Implementacja systemowej funkcji usuwania elementów za pomocą gestu przesunięcia.
                        .onDelete(perform: deleteLocation)
                    }
                    .listStyle(.plain)
                }
            } else {
                allExpensesList
            }
        }
        .navigationTitle(trip.title ?? "Szczegóły")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Wyświetlanie przycisku dodawania nowego wydatku wyłącznie w aktywnej zakładce "Wydatki".
            if selectedSegment == 1 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Automatyczne ustawienie pierwszej dostępnej lokalizacji z listy w celu ułatwienia obsługi formularza.
                        selectedLocationForExpense = locations.first
                        showAddExpenseModal = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddExpenseModal) {
            addExpenseForm
        }
    }
    
    // MARK: - Komponenty interfejsu (Subviews)
    
    // Uniwersalny widok zastępczy prezentowany, gdy kolekcja danych jest pusta.
    private func emptyStateView(msg: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(msg)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding(.top, 40)
    }
    
    // Widok reprezentujący pojedynczy węzeł na osi czasu odwiedzonych miejsc (Timeline).
    private func timelineRow(for location: Location) -> some View {
        HStack(alignment: .top, spacing: 15) {
            // Rysowanie graficznego znacznika na osi czasu.
            VStack {
                Circle().fill(Color.blue).frame(width: 12, height: 12)
                Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(location.name ?? "Nieznane miejsce")
                    .font(.headline)
                
                if let visitTime = location.visitTime {
                    Text(visitTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundColor(.secondary)
                }
                
                // Konwersja surowych danych binarnych (Data) na obiekt graficzny UIImage.
                if let photoData = location.photo, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 140)
                        .cornerRadius(10).clipped()
                }
                Divider()
            }
        }
        .listRowSeparator(.hidden)
    }
    
    // Widok listy agregujący i prezentujący wszystkie wydatki poniesione w trakcie wybranej podróży.
    private var allExpensesList: some View {
        Group {
            // Wykorzystanie funkcji mapowania płaskiego (flatMap) w celu spłaszczenia hierarchii danych.
            // Konwertuje to wielopoziomową strukturę relacji (Miejsca -> Wydatki) do jednowymiarowej tablicy.
            let allExpenses = locations.flatMap { (location) -> [Expense] in
                if let set = location.expenses as? Set<Expense> {
                    return Array(set)
                }
                return []
            }
            
            if allExpenses.isEmpty {
                emptyStateView(msg: "Brak wpisanych wydatków. Kliknij '+', aby dodać!")
            } else {
                List {
                    ForEach(allExpenses, id: \.id) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(expense.note ?? "Wydatek")
                                    .font(.headline)
                                Text("Kat: \(expense.category ?? "Inne") | Miejsce: \(expense.location?.name ?? "Ogólne")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("-\(Int(expense.amount)) PLN")
                                .foregroundColor(.red)
                                .bold()
                        }
                    }
                    .onDelete { offsets in
                        // Usunięcie wybranego wydatku po odnalezieniu go na podstawie indeksu w spłaszczonej tablicy.
                        offsets.forEach { index in
                            let targetExpense = allExpenses[index]
                            viewContext.delete(targetExpense)
                        }
                        try? viewContext.save()
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // Modalny formularz odpowiedzialny za proces rejestracji nowego wydatku do bazy danych.
    private var addExpenseForm: some View {
        NavigationStack {
            Form {
                Section(header: Text("Szczegóły wydatku")) {
                    TextField("Kwota (PLN)", text: $expenseAmount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Kategoria", selection: $expenseCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat)
                        }
                    }
                    
                    TextField("Notatka (np. obiad, bilety)", text: $expenseNote)
                }
                
                // Sekcja wymuszająca powiązanie wydatku z konkretną fizyczną lokalizacją zdefiniowaną na mapie.
                Section(header: Text("Przypisz do miejsca z planu")) {
                    if locations.isEmpty {
                        Text("Brak dodanych miejsc w planie. Dodaj najpierw miejsce na mapie, aby przypisać wydatek.")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Picker("Wybierz miejsce", selection: $selectedLocationForExpense) {
                            ForEach(locations, id: \.self) { (loc: Location) in
                                Text(loc.name ?? "Nieznane").tag(loc as Location?)
                            }
                        }
                    }
                }
                
                Button("Zapisz Wydatek") {
                    guard let amountDouble = Double(expenseAmount) else { return }
                    
                    // Inicjalizacja nowej encji Core Data w obrębie głównego kontekstu.
                    let newExpense = Expense(context: viewContext)
                    newExpense.id = UUID()
                    newExpense.amount = amountDouble
                    newExpense.category = expenseCategory
                    newExpense.note = expenseNote.isEmpty ? expenseCategory : expenseNote
                    
                    // Ustanowienie relacyjności obiektu.
                    if let chosenLocation = selectedLocationForExpense {
                        newExpense.location = chosenLocation
                    }
                    
                    // Bezpieczne zatwierdzenie modyfikacji i ukrycie formularza.
                    try? viewContext.save()
                    showAddExpenseModal = false
                    expenseAmount = ""
                    expenseNote = ""
                }
                // Implementacja walidacji blokującej przycisk w momencie podania błędnych danych wejściowych.
                .disabled(expenseAmount.isEmpty || Double(expenseAmount) == nil || selectedLocationForExpense == nil)
            }
            .navigationTitle("Nowy Wydatek")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { showAddExpenseModal = false }
                }
            }
        }
    }
    
    // Metoda odpowiedzialna za usunięcie określonego miejsca powiązanego z podróżą, z opcjonalną animacją interfejsu.
    private func deleteLocation(at offsets: IndexSet) {
        withAnimation {
            offsets.map { locations[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

