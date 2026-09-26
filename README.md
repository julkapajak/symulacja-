# SimLife

Przeglądarkowa gra życiowa inspirowana serią *The Sims* — bez żadnych zależności, frameworków ani kroku budowania. Całość to czysty HTML, CSS i JavaScript renderujący izometryczny świat 3D na `<canvas>`.

Zagraj od razu: otwórz `index.html` w przeglądarce (lub zobacz opublikowaną wersję / wersję na GitHub Pages, jeśli została skonfigurowana — patrz sekcja [Wystawienie w sieci](#wystawienie-w-sieci)).

> **Wersja na iPada (natywna aplikacja)** jest w budowie w katalogu [`ios/`](ios/README.md) — SwiftUI + SceneKit (prawdziwe 3D, kamera obracana o 360°), docelowo do App Store. Zobacz `ios/README.md` po instrukcje uruchomienia w Xcode.

## Funkcje

**Świat**
- Izometryczny dom 16×9 pól z prawdziwą architekturą: ściany generowane automatycznie z układu pokoi, drzwi (które trzeba faktycznie obejść — blokują ruch tak jak prawdziwa ściana) i dekoracyjne okna
- Podłogi z teksturą zależną od pokoju (kafelki w kuchni/łazience, deski w sypialni/salonie, trawa w ogrodzie)
- Pełny cykl dnia i nocy: gradient nieba, poruszające się słońce/księżyc z poświatą, gwiazdy nocą
- Pory roku (Wiosna/Lato/Jesień/Zima, 7 dni każda) zmieniające kolor trawnika, oraz losowa pogoda (deszcz/śnieg) renderowana jako cząsteczki na ekranie

**Sim**
- Tworzenie postaci: imię, kolor, cecha charakteru, **aspiracja życiowa** (cel na dłuższą metę)
- 6 potrzeb (głód, energia, higiena, zabawa, kontakty, pęcherz), opadających w czasie i uzupełnianych czynnościami
- Autonomia: gdy jakaś potrzeba spadnie krytycznie nisko, Sim sam idzie ją zaspokoić
- Pathfinding (BFS) po siatce, z uwzględnieniem ścian i drzwi
- System umiejętności (gotowanie, kondycja, charyzma) rosnący wraz z użyciem powiązanych obiektów, wpływający na wyniki czynności
- Kariera z 6 stanowiskami (Stażysta → Prezes) i automatycznymi awansami
- Aspiracje życiowe z jednorazową nagrodą pieniężną po spełnieniu

**Współlokator**
- Opcjonalna druga postać z własnymi potrzebami, umiejętnościami i karierą
- W pełni autonomiczne zachowanie (nie tylko reaguje na krytyczne potrzeby — sam sobie znajduje zajęcie)
- System relacji ze wspólnym paskiem bliskości i interakcjami (Porozmawiaj / Przytul / Pocałuj), odblokowywanymi poziomem relacji i bliskością fizyczną

**Tryb budowania**
- Przełącznik 🔨 w górnym pasku
- Stawianie dowolnego mebla z pełnego katalogu na dowolnym wolnym polu
- Przenoszenie istniejących mebli w nowe miejsce
- Sprzedawanie mebli za połowę ceny zakupu

**Sterowanie kamerą**
- Przybliżanie: scroll/kółko myszy (w miejsce kursora) lub uszczypnięcie dwoma palcami
- Przesuwanie widoku: przeciąganie (rozróżniane od kliknięcia po dystansie ruchu)
- Przyciski ➖ / ⛶ / ➕ w górnym pasku

**Ogólne**
- Pełnoekranowy interfejs ze szklanym, półprzezroczystym HUD-em pływającym nad światem gry
- Responsywny — działa na telefonie, tablecie i desktopie
- Zapis stanu gry w `localStorage` (automatyczny co 30 s i przy zamknięciu karty), wczytywany przy starcie

## Jak grać

1. Stwórz Sima: imię, kolor, cechę charakteru i aspirację życiową.
2. Zdecyduj, czy dodać współlokatora.
3. Klikaj obiekty w domu, aby wykonywać czynności (jedzenie, sen, prysznic, telewizor, praca itd.).
4. Klikaj puste pole, aby Sim tam podszedł.
5. Klikaj współlokatora (gdy jesteście blisko siebie), aby wejść w interakcję społeczną.
6. Użyj 🔨, aby wejść w tryb budowania i zmienić wystrój domu.
7. Przybliżaj i oddalaj widok kółkiem myszy / gestem, żeby przyjrzeć się szczegółom.

## Struktura projektu

```
index.html   – struktura strony, HUD, modale (kreator postaci, sklep, itp.)
style.css    – pełny wygląd: pełnoekranowy layout, szklany HUD, modale
app.js       – cała logika gry: świat, pathfinding, Sim/AI, renderowanie izometryczne, input
```

Gra jest napisana jako jeden plik JavaScript bez modułów ani zależności — całość działa po prostu przez otwarcie `index.html` w przeglądarce, offline, bez serwera (choć lokalny serwer, np. `python3 -m http.server`, też działa i jest wygodny do developmentu).

### Krótko o architekturze

- **Świat** to siatka pól; ściany są generowane raz przy starcie na podstawie granic stref (`ZONES`) — tam, gdzie sąsiadują dwie różne strefy albo brzeg mapy, powstaje ściana (chyba że pole jest oznaczone jako drzwi).
- **Renderowanie** jest w pełni odtwarzane co klatkę na `<canvas>` przy użyciu rzutowania izometrycznego (funkcje `project`, `isoX`/`isoY`) i sortowania malarskiego w trzech przebiegach (podłoga → ściany → meble/Simowie), żeby uniknąć błędów głębi przy wysokich obiektach.
- **Meble** to poszczególne instancje (`state.items`) wskazujące na typ w `ITEM_CATALOG` (wygląd, koszt, czynność) — dzięki temu tryb budowania może stawiać/przenosić/sprzedawać je bez specjalnych przypadków.
- **Kamera** (`state.camera`) to osobna warstwa zoom/pan nałożona na bazowe dopasowanie sceny do okna (`fitScale`), tak żeby scena zawsze była ostra niezależnie od rozdzielczości i proporcji ekranu.
- Zapis gry serializuje `Sim`ów, przedmioty, pogodę i licznik dni do jednego obiektu JSON w `localStorage`.

## Wystawienie w sieci

Repozytorium nie zawiera żadnego kroku budowania — GitHub Pages może serwować je bezpośrednio:

1. Wejdź w **Settings → Pages** repozytorium.
2. W **Build and deployment → Source** wybierz **Deploy from a branch**.
3. Jako branch wybierz gałąź z tym kodem, folder **/ (root)**.
4. Zapisz — po chwili gra będzie dostępna pod adresem `https://<użytkownik>.github.io/<repozytorium>/`.

## Możliwe kierunki rozwoju

- Własny układ ścian w trybie budowania (obecnie ściany są generowane automatycznie z układu pokoi)
- Więcej niż dwóch mieszkańców domu, dzieci i starzenie się postaci
- Rozszerzony zestaw aspiracji i "cech" wpływających na rozgrywkę
- Wielo-pokojowe, edytowalne plany domu zamiast jednego stałego układu
