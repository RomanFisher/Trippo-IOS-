//
//   ContentView.swift
//   Trippo
//
//   Created by Виталия Ткаченко on 02.06.2026.
//

import SwiftUI
import CoreData
import Charts // Import frameworku umożliwiającego generowanie wykresów.


enum StatsStatus {
    case wszystkie, aktywne, zakonczone
}

struct ContentView: View {
    // Dostęp do globalnego kontekstu Core Data dla operacji odczytu danych.
    @Environment(\.managedObjectContext) private var viewContext
    
    // Zapytanie pobierające wszystkie podróże z bazy, posortowane chronologicznie.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: true)],
        animation: .default)
    private var trips: FetchedResults<Trip>
    
    // Zapytanie pobierające wszystkie zarejestrowane lokalizacje powiązane z podróżami.
    @FetchRequest(
        sortDescriptors: [],
        animation: .default)
    private var allLocations: FetchedResults<Location>

    // Stan przechowujący aktualnie wybrany filtr dla modułu statystyk.
    @State private var selectedStatsStatus: StatsStatus = .wszystkie
    
    // Stała tablica zawierająca dostępne kategorie wydatków.
    let categories = ["Jedzenie", "Transport", "Nocleg", "Rozrywka", "Inne"]

    
    // Właściwość filtrująca kolekcję podróży na podstawie wybranego statusu oraz bieżącej daty.
    private var filteredTripsForStats: [Trip] {
        // Ustalenie początku bieżącego dnia w celu uniknięcia problemów z dokładnym czasem (godziny/minuty).
        let today = Calendar.current.startOfDay(for: Date())
        
        switch selectedStatsStatus {
        case .wszystkie:
            return Array(trips)
        case .aktywne:
            // Zwraca podróże, których data zakończenia jest równa lub późniejsza niż dzisiaj.
            return trips.filter { Calendar.current.startOfDay(for: $0.endDate ?? Date.distantPast) >= today }
        case .zakonczone:
            // Zwraca podróże, które zakończyły się przed dzisiejszym dniem.
            return trips.filter { Calendar.current.startOfDay(for: $0.endDate ?? Date.distantPast) < today }
        }
    }
    
    // Właściwość filtrująca lokalizacje, zwracająca tylko te, które należą do odfiltrowanych wcześniej podróży.
    private var filteredLocationsForStats: [Location] {
        let today = Calendar.current.startOfDay(for: Date())
        
        return allLocations.filter { location in
            // Weryfikacja, czy lokalizacja posiada przypisaną podróż.
            guard let trip = location.trip else { return false }
            let tripEndDate = Calendar.current.startOfDay(for: trip.endDate ?? Date.distantPast)
            
            switch selectedStatsStatus {
            case .wszystkie: return true
            case .aktywne: return tripEndDate >= today
            case .zakonczone: return tripEndDate < today
            }
        }
    }

    // Obliczanie całkowitej sumy wydatków z uwzględnieniem aktywnego filtru czasowego.
    private var totalExpensesFiltered: Double {
        var sum: Double = 0
        for location in filteredLocationsForStats {
            if let expensesSet = location.expenses as? Set<Expense> {
                sum += expensesSet.reduce(0) { $0 + $1.amount }
            }
        }
        return sum
    }
    
    // Obliczanie procentowego wskaźnika wykorzystania połączonych budżetów odfiltrowanych podróży.
    private var totalBudgetSpentProgress: Double {
        let totalBudget = filteredTripsForStats.reduce(0.0) { $0 + $1.budget }
        guard totalBudget > 0 else { return 0 }
        return totalExpensesFiltered / totalBudget
    }
    
    // Agregacja wydatków z podziałem na kategorie (zwraca słownik: Kategoria -> Suma).
    private var expensesByCategory: [String: Double] {
        var breakdown: [String: Double] = ["Jedzenie": 0, "Transport": 0, "Nocleg": 0, "Rozrywka": 0, "Inne": 0]
        
        for location in filteredLocationsForStats {
            if let expensesSet = location.expenses as? Set<Expense> {
                for expense in expensesSet {
                    let cat = expense.category ?? "Inne"
                    breakdown[cat, default: 0] += expense.amount
                }
            }
        }
        return breakdown
    }
    
    // Agregacja danych dla wykresu kołowego, zliczająca wystąpienia poszczególnych typów podróży.
    private var tripTypesData: [(type: String, count: Int)] {
        var counts: [String: Int] = [:]
        for trip in filteredTripsForStats {
            let type = trip.tripType ?? "Inne"
            counts[type, default: 0] += 1
        }
        // Mapowanie słownika na tablicę krotek wymaganych przez framework Swift Charts.
        return counts.map { (type: $0.key, count: $0.value) }
    }

    var body: some View {
        TabView {
            // Pierwsza zakładka: Główny widok z listą podróży (Dashboard).
            DashboardView()
                .tabItem {
                    Label("Podróże", systemImage: "suitcase.fill")
                }
            
            // Druga zakładka: Moduł zaawansowanej analityki i statystyk.
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Przełącznik segmentowy umożliwiający zmianę analizowanego okresu.
                        Picker("Okres", selection: $selectedStatsStatus) {
                            Text("Wszystkie").tag(StatsStatus.wszystkie)
                            Text("Aktywne").tag(StatsStatus.aktywne)
                            Text("Zakończone").tag(StatsStatus.zakonczone)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Sekcja 1: Główne wskaźniki numeryczne (łączne wydatki i liczba miejsc).
                        HStack(spacing: 15) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Wydatki okresu")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(totalExpensesFiltered)) PLN")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Odwiedzone miejsca")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(filteredLocationsForStats.count)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Sekcja 2: Implementacja wykresu pierścieniowego (Doughnut Chart) przy użyciu Swift Charts.
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Kategorie wyjazdów")
                                .font(.headline)
                            
                            if tripTypesData.isEmpty {
                                Text("Brak danych do wyświetlenia wykresu")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 20)
                            } else {
                                Chart(tripTypesData, id: \.type) { item in
                                    SectorMark(
                                        angle: .value("Liczba", item.count),
                                        innerRadius: .ratio(0.6), // Definiuje pusty środek, tworząc wykres pierścieniowy.
                                        angularInset: 1.5 // Odstępy pomiędzy sekcjami wykresu.
                                    )
                                    .foregroundStyle(by: .value("Rodzaj", item.type))
                                    .cornerRadius(5)
                                }
                                .frame(height: 180)
                                .padding(.top, 5)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        // Sekcja 3: Podsumowanie ilościowe wybranego okresu i stopień wykorzystania budżetu.
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Podsumowanie okresu")
                                .font(.headline)
                            HStack {
                                // Dynamiczna zmiana ikony w zależności od wybranego statusu.
                                Image(systemName: selectedStatsStatus == .zakonczone ? "archivebox.fill" : "globe.europe.africa.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(selectedStatsStatus == .zakonczone ? .gray : .blue)
                                
                                VStack(alignment: .leading) {
                                    Text("Liczba podróży: \(filteredTripsForStats.count)")
                                        .font(.subheadline)
                                        .bold()
                                    Text("Wykorzystanie budżetu: \(Int(totalBudgetSpentProgress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        // Sekcja 4: Analiza struktury wydatków z wykorzystaniem niestandardowych pasków postępu.
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Wydatki według kategorii")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            ForEach(categories, id: \.self) { category in
                                let amount = expensesByCategory[category] ?? 0.0
                                HStack {
                                    Text(category)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(amount)) PLN")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.secondary)
                                }
                                
                                // Rysowanie poziomego paska postępu dla proporcjonalnego przedstawienia wydatków.
                                GeometryReader { categoryGeo in
                                    ZStack(alignment: .leading) {
                                        Rectangle().fill(Color(.systemGray5)).frame(height: 6).cornerRadius(3)
                                        Rectangle()
                                            .fill(Color.orange)
                                            .frame(width: totalExpensesFiltered > 0 ? CGFloat(amount / totalExpensesFiltered) * categoryGeo.size.width : 0, height: 6)
                                            .cornerRadius(3)
                                    }
                                }
                                .frame(height: 6)
                                .padding(.bottom, 5)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("Statystyka")
            }
            .tabItem {
                Label("Statystyka", systemImage: "chart.bar.xaxis")
            }
            
            // Trzecia zakładka: Interaktywna mapa wyświetlająca pinezki z lokalizacjami.
            TravelMapView()
                .tabItem {
                    Label("Mapa", systemImage: "map.fill")
                }
            
            // Czwarta zakładka: Formularz umożliwiający dodanie nowej podróży.
            AddTripView()
                .tabItem {
                    Label("Dodaj", systemImage: "plus.circle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(\.locale, Locale(identifier: "pl"))
}
