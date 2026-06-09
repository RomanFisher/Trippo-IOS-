//
//  DashboardView.swift
//  Trippo
//
//  Created by Виталия Ткаченко on 02.06.2026.
//

import SwiftUI
import CoreData

enum SortOrder {
    case newest, oldest
}

enum TripStatus {
    case wszystkie, aktywne, zakonczone
}

struct DashboardView: View {
    // Dostęp do globalnego kontekstu Core Data dla operacji odczytu i usuwania danych.
    @Environment(\.managedObjectContext) private var viewContext
    
    // Zapytanie do Core Data pobierające wszystkie obiekty Trip, domyślnie posortowane malejąco po dacie rozpoczęcia.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default)
    private var trips: FetchedResults<Trip>
    
    // Stany przechowujące aktualne kryteria filtrowania wprowadzane przez użytkownika.
    @State private var searchText = ""
    @State private var selectedType = "Wszystkie"
    @State private var sortOrder: SortOrder = .newest
    @State private var selectedStatus: TripStatus = .wszystkie
    
    // Stała tablica dostępnych kategorii podróży wykorzystywana w interfejsie wyboru.
    let types = ["Wszystkie", "Wypoczynek", "Biznes", "Inne", "Sport"]

    // Właściwość obliczana odpowiedzialna za wieloetapowe filtrowanie i sortowanie danych wejściowych.
    var filteredTrips: [Trip] {
        var items = Array(trips)
        // Pobranie początku bieżącego dnia w celu precyzyjnego i bezbłędnego porównywania dat.
        let today = Calendar.current.startOfDay(for: Date())
        
        // Etap 1: Filtrowanie tekstowe na podstawie nazwy podróży (ignoruje wielkość liter).
        if !searchText.isEmpty {
            items = items.filter { $0.title?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        
        // Etap 2: Filtrowanie na podstawie wybranej kategorii wyjazdu.
        if selectedType != "Wszystkie" {
            items = items.filter { $0.tripType == selectedType }
        }
        
        // Etap 3: Filtrowanie na podstawie statusu (przyszłe/trwające względem zakończonych).
        if selectedStatus != .wszystkie {
            items = items.filter { trip in
                let tripEndDate = Calendar.current.startOfDay(for: trip.endDate ?? Date.distantPast)
                if selectedStatus == .aktywne {
                    return tripEndDate >= today // Podróż wciąż trwa lub jest zaplanowana na przyszłość.
                } else {
                    return tripEndDate < today // Podróż została już zakończona.
                }
            }
        }
        
        // Etap 4: Sortowanie wynikowej kolekcji na podstawie daty rozpoczęcia podróży.
        items.sort {
            let date1 = $0.startDate ?? Date.distantPast
            let date2 = $1.startDate ?? Date.distantPast
            return sortOrder == .newest ? date1 > date2 : date1 < date2
        }
        
        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Przełącznik segmentowy umożliwiający szybką zmianę widoku między wszystkimi, aktywnymi i zakończonymi podróżami.
                Picker("Status podróży", selection: $selectedStatus) {
                    Text("Wszystkie").tag(TripStatus.wszystkie)
                    Text("Aktywne").tag(TripStatus.aktywne)
                    Text("Zakończone").tag(TripStatus.zakonczone)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 5)
                
                // Pasek narzędziowy zawierający filtr kategorii oraz przycisk zmiany kierunku sortowania.
                HStack(spacing: 15) {
                    Picker("Typ", selection: $selectedType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Przycisk przełączający tryb sortowania (najnowsze/najstarsze) wraz z dynamiczną zmianą ikony.
                    Button(action: { sortOrder = (sortOrder == .newest ? .oldest : .newest) }) {
                        HStack {
                            Image(systemName: sortOrder == .newest ? "calendar.badge.minus" : "calendar.badge.plus")
                            Text(sortOrder == .newest ? "Najnowsze" : "Najstarsze")
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Warunkowe renderowanie interfejsu w zależności od tego, czy lista wyników jest pusta.
                if filteredTrips.isEmpty {
                    ContentUnavailableView("Brak podróży", systemImage: "airplane.departure", description: Text("Spróbuj zmienić filtry lub dodaj nową podróż."))
                        .padding(.top, 50)
                    Spacer()
                } else {
                    List {
                        // Iteracja po przefiltrowanej tablicy i renderowanie pojedynczych wierszy.
                        ForEach(filteredTrips) { singleTrip in
                            NavigationLink(destination: TripDetailView(trip: singleTrip)) {
                                TripRowView(trip: singleTrip)
                            }
                        }
                        // Dodanie obsługi systemowego gestu przesunięcia (swipe) w celu usunięcia obiektu z bazy danych.
                        .onDelete(perform: deleteTrips)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Moje Podróże")
            // Zintegrowana wyszukiwarka aktualizująca stan searchText podczas wpisywania.
            .searchable(text: $searchText, prompt: "Szukaj po nazwie...")
        }
    }

    // Metoda odpowiedzialna za usunięcie wybranych podróży z bazy danych Core Data.
    private func deleteTrips(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredTrips[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// Subwidok odpowiedzialny za wizualną reprezentację pojedynczej podróży na liście.
struct TripRowView: View {
    // Obserwacja obiektu Trip w celu automatycznego odświeżania widoku przy zmianach danych.
    @ObservedObject var trip: Trip

    var body: some View {
        HStack(spacing: 15) {
            // Obliczenie, czy podróż jest już zakończona, w celu odpowiedniego dostosowania kolorystyki i ikonografii.
            let isPast = (trip.endDate ?? Date.distantPast) < Calendar.current.startOfDay(for: Date())
            
            // Dynamiczna zmiana ikony: standardowa walizka dla aktywnych, archiwum dla zakończonych.
            Image(systemName: isPast ? "archivebox.fill" : "suitcase.fill")
                .font(.title)
                .foregroundColor(isPast ? .gray : .blue)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(trip.title ?? "Nieznana podróż")
                    .font(.headline)
                    .foregroundColor(isPast ? .primary.opacity(0.7) : .primary)
                
                HStack {
                    Text(trip.startDate ?? Date(), style: .date)
                    Text("-")
                    Text(trip.endDate ?? Date(), style: .date)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Text("Typ: \(trip.tripType ?? "Inne")")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(isPast ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(5)
            }
            
            Spacer()
            
            Text("\(Int(trip.budget)) PLN")
                .font(.subheadline)
                .bold()
                .foregroundColor(isPast ? .gray : .green)
        }
        .padding(.vertical, 5)
    }
}
