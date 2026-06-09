//
//  TravelMapView.swift
//  Trippo
//
//  Created by Виталия Ткаченко on 02.06.2026.
//

import SwiftUI
import MapKit
import CoreData
import PhotosUI

struct TravelMapView: View {
    // Uzyskanie dostępu do globalnego kontekstu Core Data w celu zapisu nowych lokalizacji.
    @Environment(\.managedObjectContext) private var viewContext
    
    // Inicjalizacja instancji menedżera lokalizacji, odpowiedzialnego za śledzenie pozycji GPS użytkownika.
    @StateObject private var locationManager = LocationManager()
    
    // Zapytanie do Core Data pobierające dostępne podróże. Wymagane do powiązania nowej lokalizacji z konkretnym wyjazdem.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: true)],
        animation: .default)
    private var trips: FetchedResults<Trip>
    
    // Stan zarządzający aktualną pozycją kamery na mapie. Domyślnie ustawiony na lokalizację użytkownika.
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    // Stany zarządzające procesem dodawania nowej lokalizacji za pomocą gestu.
    @State private var selectedCoords: CLLocationCoordinate2D?
    @State private var showAddLocationModal = false
    @State private var newLocationName = ""
    @State private var selectedTrip: Trip?
    
    // Stany przechowujące dane wyszukiwarki miejsc (MKLocalSearch).
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    
    // Stany odpowiedzialne za integrację z natywną galerią zdjęć urządzenia.
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedPhotoData: Data? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Komponent MapReader zapewnia dostęp do obiektu proxy, umożliwiając konwersję punktów ekranu na współrzędne geograficzne.
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        // Znacznik reprezentujący aktualną pozycję użytkownika na mapie (niebieska kropka).
                        UserAnnotation()
                        
                        // Dynamiczne renderowanie znaczników na podstawie wyników zapytania z wyszukiwarki.
                        ForEach(searchResults, id: \.self) { result in
                            Marker(result.name ?? "Miejsce", coordinate: result.placemark.coordinate)
                        }
                    }
                    // Konfiguracja natywnych kontrolek mapy (przycisk lokalizacji, kompas).
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    // Implementacja zaawansowanego gestu łączonego: długie naciśnięcie mapy.
                    .gesture(
                        LongPressGesture(minimumDuration: 1.0)
                            // Sekwencjonowanie z gestem przeciągnięcia pozwala na precyzyjne odczytanie miejsca dotknięcia.
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onEnded { value in
                                switch value {
                                case .second(true, let drag):
                                    // Pobranie fizycznej lokalizacji dotknięcia na ekranie.
                                    if let location = drag?.location,
                                       // Konwersja pikseli ekranu na rzeczywiste współrzędne geograficzne (Latitude/Longitude).
                                       let coords = proxy.convert(location, from: .local) {
                                        selectedCoords = coords
                                        selectedTrip = trips.first // Domyślne przypisanie pierwszej podróży z listy.
                                        showAddLocationModal = true // Wywołanie formularza dodawania miejsca.
                                    }
                                default: break
                                }
                            }
                    )
                }
            }
            .navigationTitle("Mapa")
            // Integracja natywnego paska wyszukiwania w pasku nawigacyjnym.
            .searchable(text: $searchText, prompt: "Szukaj miejsca...")
            // Akcja wywoływana po zatwierdzeniu tekstu w wyszukiwarce (np. naciśnięcie "Szukaj" na klawiaturze).
            .onSubmit(of: .search) {
                performSearch()
            }
            // Prezentacja formularza w formie widoku modalnego (Sheet).
            .sheet(isPresented: $showAddLocationModal) {
                locationForm
            }
        }
    }
    
    // Metoda odpowiedzialna za realizację zapytań do API Apple Maps (MKLocalSearch).
    private func performSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // Definiowanie regionu wyszukiwania w celu optymalizacji i priorytetyzacji wyników.
        // Wykorzystywana jest aktualna pozycja użytkownika lub koordynaty domyślne (np. centrum Warszawy).
        let center = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            
            // Operacje aktualizacji interfejsu muszą być wykonywane w głównym wątku (Main Thread).
            DispatchQueue.main.async {
                self.searchResults = response.mapItems
                print("Znaleziono miejsc: \(response.mapItems.count)")
                
                // Celowe opóźnienie animacji kamery (0.5 sekundy).
                // Zapobiega to gubieniu klatek (frame drop) podczas jednoczesnego renderowania znaczników i animacji mapy.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let firstItem = response.mapItems.first {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            // Zmiana pozycji kamery tak, aby wyśrodkować ją na pierwszym znalezionym wyniku.
                            cameraPosition = .region(MKCoordinateRegion(
                                center: firstItem.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                            ))
                        }
                    }
                }
            }
        }
    }
    
    // Struktura formularza używanego do zapisu nowej lokalizacji w Core Data.
    private var locationForm: some View {
        NavigationStack {
            Form {
                // Sekcja podstawowych metadanych lokalizacji.
                Section(header: Text("Nowe Miejsce").foregroundColor(.blue)) {
                    TextField("Nazwa miejsca (np. Hotel, Muzeum)", text: $newLocationName)
                    
                    // Zabezpieczenie przed próbą dodania lokalizacji bez uprzedniego stworzenia podróży.
                    if !trips.isEmpty {
                        Picker("Wybierz podróż", selection: $selectedTrip) {
                            ForEach(trips, id: \.self) { trip in
                                Text(trip.title ?? "Nieznana").tag(trip as Trip?)
                            }
                        }
                    } else {
                        Text("Najpierw dodaj podróż!").foregroundColor(.red)
                    }
                }
                
                // Sekcja integracji z galerią za pośrednictwem frameworku PhotosUI.
                Section(header: Text("Zdjęcie").foregroundColor(.blue)) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text(selectedPhotoData == nil ? "Dodaj zdjęcie" : "Zmień zdjęcie")
                        }
                    }
                    // Nasłuchiwanie zmian wybranego elementu. Jeśli użytkownik wskaże zdjęcie, rozpoczyna się asynchroniczne ładowanie.
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            // Próba ekstrakcji surowych danych (Data) z wybranego obiektu Transferable.
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                // Bezpieczne zaktualizowanie stanu interfejsu w wątku głównym.
                                await MainActor.run { selectedPhotoData = data }
                            }
                        }
                    }
                    
                    // Konwersja surowych danych (Data) na obiekt UIImage w celu wyrenderowania podglądu w formularzu.
                    if let selectedPhotoData, let uiImage = UIImage(data: selectedPhotoData) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill().frame(height: 150).cornerRadius(10).clipped()
                    }
                }
                
                // Sekcja informacyjna wyświetlająca dokładne współrzędne geograficzne odczytane z gestu.
                Section(header: Text("Współrzędne").foregroundColor(.blue)) {
                    Text("Lat: \(selectedCoords?.latitude ?? 0.0)")
                    Text("Lon: \(selectedCoords?.longitude ?? 0.0)")
                }
                
                Button("Zapisz Miejsce") {
                    saveLocation()
                }
                // Logiczna blokada przycisku, zapobiegająca zapisowi niekompletnych danych.
                .disabled(newLocationName.isEmpty || selectedTrip == nil)
            }
            .navigationTitle("Dodaj punkt")
            .toolbar {
                Button("Anuluj") { showAddLocationModal = false }
            }
        }
        // Ograniczenie wielkości widoku modalnego do natywnych rozmiarów (połowa lub pełny ekran).
        .presentationDetents([.medium, .large])
    }
    
    // Metoda hermetyzująca proces zapisu obiektu Location w strukturach Core Data.
    private func saveLocation() {
        guard let coords = selectedCoords, let trip = selectedTrip else { return }
        
        let newLocation = Location(context: viewContext)
        newLocation.id = UUID()
        newLocation.name = newLocationName
        newLocation.latitude = coords.latitude
        newLocation.longitude = coords.longitude
        newLocation.visitTime = Date()
        newLocation.trip = trip
        newLocation.photo = selectedPhotoData
        
        // Próba utrwalenia kontekstu i zamknięcie formularza.
        try? viewContext.save()
        showAddLocationModal = false
        resetForm()
    }
    
    // Metoda czyszcząca stan formularza po pomyślnym zapisie, przygotowująca widok do kolejnego użycia.
    private func resetForm() {
        newLocationName = ""
        selectedPhotoItem = nil
        selectedPhotoData = nil
    }
}

#Preview {
    TravelMapView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(\.locale, Locale(identifier: "pl"))
}
