//
//  LocationManager.swift
//  Trippo
//
//  Created by Виталия Ткаченко on 09.06.2026.
//

import Foundation
import CoreLocation // Natywny framework Apple dostarczający usługi geolokalizacyjne i nawigacyjne.

// Klasa pełniąca rolę głównego serwisu zarządzającego lokalizacją urządzenia.
// Protokół ObservableObject umożliwia wiązanie instancji tej klasy z interfejsem SwiftUI.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // Inicjalizacja sprzętowego menedżera lokalizacji, który komunikuje się bezpośrednio z systemem operacyjnym.
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    
    // Konstruktor bezparametrowy inicjujący podstawową konfigurację modułu GPS.
    override init() {
        super.init()
        
        manager.delegate = self
        
        // Ustawienie pożądanej precyzji odczytów. Wybrano najwyższą dostępną dokładność (kCLLocationAccuracyBest),
        // co jest kluczowe dla prawidłowego działania i responsywności interaktywnej mapy.
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Asynchroniczne wywołanie żądania o uprawnienia użytkownika do korzystania z usług GPS
        // wyłącznie wtedy, gdy aplikacja jest aktywna (widoczna na ekranie).
        manager.requestWhenInUseAuthorization()
        
        // Uruchomienie ciągłego procesu pobierania współrzędnych w tle.
        manager.startUpdatingLocation()
    }
    
    // Metoda protokołu CLLocationManagerDelegate, wywoływana automatycznie przez system iOS
    // w momencie odnotowania nowej, zweryfikowanej pozycji geograficznej.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Bezpieczne rozpakowanie ostatniego elementu z tablicy lokalizacji (gwarancja najświeższego odczytu).
        // Wykorzystanie instrukcji 'guard' zabezpiecza przed błędami w przypadku pustej tablicy.
        guard let location = locations.last else { return }
        
        // Aktualizacja opublikowanego stanu aplikacji nowymi współrzędnymi.
        self.location = location
    }
}
