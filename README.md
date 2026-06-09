# Trippo – Asystent Podróży dla Iphone

## Opis projektu
Trippo to aplikacja mobilna stworzona w ekosystemie iOS (SwiftUI), zaprojektowana do kompleksowego planowania wyjazdów, dokumentowania miejsc oraz zarządzania budżetem podróży. Aplikacja pozwala użytkownikom na tworzenie list wyjazdów, oznaczanie odwiedzonych lokalizacji na interaktywnej mapie oraz śledzenie wydatków z podziałem na kategorie.

## Kluczowe funkcjonalności
* **Zarządzanie podróżami:** Tworzenie, edycja i usuwanie wyjazdów z walidacją budżetu i dat.
* **Mapa:** Interaktywna mapa z możliwością oznaczania punktów za pomocą długiego naciśnięcia (LongPressGesture) oraz wyszukiwania miejsc (MKLocalSearch).
* **Analityka:** Moduł statystyk wykorzystujący framework *Swift Charts* do wizualizacji struktury wydatków oraz typów podróży.
* **Core Data:** Trwała warstwa danych z trzema powiązanymi encjami (*Trip*, *Location*, *Expense*).
* **Multimedia:** Obsługa zdjęć przypisanych do odwiedzonych miejsc za pośrednictwem *PhotosPicker*.

## Technologie
* **Język:** Swift
* **UI:** SwiftUI
* **Persystencja:** Core Data
* **Mapy:** MapKit
* **Wykresy:** Swift Charts

## Instrukcja uruchomienia
1. Sklonuj repozytorium na swój komputer.
2. Otwórz projekt w Xcode.
3. Wybierz symulator (zalecany iPhone 15/16).
4. Skompiluj i uruchom aplikację (Cmd + R).
