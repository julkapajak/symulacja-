# SimLife na iPada — Faza 3 (rozgrywka)

To jest natywna aplikacja SwiftUI + SpriteKit, oddzielna od wersji przeglądarkowej w katalogu głównym repo. Faza 0 udowodniła, że cały łańcuch narzędzi (XcodeGen → Xcode → symulator) działa. Faza 1 przeniosła prawdziwy dom z `app.js`. Faza 2 dodała ruch i gesty:

- **Dotknij pustego pola**, żeby Sim tam poszedł — prawdziwy pathfinding (BFS) omija ściany i meble.
- **Przeciągnij**, żeby przesunąć widok kamery.
- **Uszczypnij (pinch)**, żeby przybliżyć/oddalić — zoomuje w punkt pod palcami.

Faza 3 dodaje samą rozgrywkę:

- **6 potrzeb** (głód, energia, higiena, zabawa, kontakty, pęcherz), opadających w czasie — widoczne jako paski na dole ekranu.
- **Dotknij mebla**, żeby z niego skorzystać (zjedz przy lodówce, prysznic, sen w łóżku, TV, komputer, itd.) — Sim tam podejdzie i użyje go.
- **Umiejętności** (gotowanie, kondycja, charyzma) rosnące wraz z użyciem powiązanych sprzętów.
- **Kariera**: samochód to praca — dojazd 8:00–18:00, wypłata i awanse co 3 zmiany.
- **Autonomia**: gdy potrzeba spadnie krytycznie nisko, Sim sam idzie ją zaspokoić.
- **HUD** (SwiftUI, nałożony na scenę): pieniądze, dzień, godzina, stanowisko, paski potrzeb i dymki z komunikatami.

Masz MacBooka Air M1 — to wystarczy, żeby zrobić i przetestować całość lokalnie, bez czekania na CI.

## Jednorazowe przygotowanie Maca

1. **Zainstaluj Xcode** z Mac App Store (szukaj "Xcode", ok. 10–15 GB, instalacja chwilę potrwa). Wersja 15 lub nowsza.
2. Otwórz Xcode raz, zaakceptuj licencję i poczekaj, aż doinstaluje dodatkowe komponenty.
3. Zainstaluj **Homebrew** (menedżer pakietów), jeśli go nie masz — instrukcja na [brew.sh](https://brew.sh), to jedna komenda w Terminalu.
4. Zainstaluj **XcodeGen** (generuje projekt Xcode z prostego pliku `project.yml`, żebyśmy nie musieli ręcznie trzymać w repo kruchego formatu `.xcodeproj`):
   ```
   brew install xcodegen
   ```

## Uruchomienie projektu

```bash
git clone <adres-twojego-repo>   # albo: git pull, jeśli już masz sklonowane
cd symulacja-/ios
xcodegen generate
open SimLife.xcodeproj
```

W Xcode:
1. Przy przycisku ▶ (Play) w górnym pasku wybierz symulator, np. **iPad Pro 13-inch (M4)**.
2. Naciśnij ▶ (albo `Cmd+R`).
3. Po chwili powinieneś zobaczyć: niebieskie niebo ze słońcem, izometryczny dom z pięcioma pokojami (kolorowe podłogi, ściany, okna, dwoje drzwi), startowe meble (lodówka, łóżko, telewizor, itd.) i Sima.
4. Dotknij dowolnego wolnego pola (na symulatorze: kliknij myszką) — Sim powinien tam dojść, omijając ściany. Przeciągnij, żeby przesunąć widok. Uszczypnij (na symulatorze: przytrzymaj Option i przeciągnij), żeby przybliżyć/oddalić.
5. Na dole ekranu powinny być widoczne paski potrzeb, a u góry pieniądze/dzień/godzina/stanowisko. Dotknij lodówki, łóżka, prysznica, TV albo komputera — Sim powinien tam podejść i zacząć z nich korzystać (pojawi się dymek z komunikatem, a odpowiedni pasek potrzeby zacznie rosnąć). Dotknij samochodu w godzinach 8:00–18:00, żeby Sim poszedł do pracy.

Jeśli to działa — cała podstawowa rozgrywka jest gotowa. Dalej w planie: aspiracje, tryb budowania i współlokator.

## Testowanie na prawdziwym iPadzie (opcjonalnie, już teraz)

Nie musisz mieć płatnego konta Apple Developer, żeby testować na własnym urządzeniu:

1. Podłącz iPada kablem do Maca, "Zaufaj temu komputerowi" na iPadzie.
2. W Xcode: **Xcode → Settings → Accounts** → dodaj swój zwykły Apple ID (za darmo).
3. Wybierz swojego iPada jako cel uruchomienia (zamiast symulatora) i naciśnij ▶.
4. Xcode poprosi o włączenie *Developer Mode* w **Ustawienia → Prywatność i bezpieczeństwo** na iPadzie — włącz i zrestartuj.

Ograniczenie darmowego konta: certyfikat wygasa po 7 dniach (trzeba wtedy ponownie uruchomić z Xcode) i nie da się przez to wysłać do TestFlight/App Store — do tego będzie potrzebne płatne członkostwo (99$/rok), ale dopiero w późniejszej fazie.

## Co dalej

Kolejne fazy (patrz plan w rozmowie z Claude) przeniosą właściwą logikę gry — świat, Sima, potrzeby, kariery, tryb budowania — z wersji przeglądarkowej (`app.js`) na Swift, rozbudowując pliki w `SimLife/`. `GameScene.swift` to miejsce, gdzie to wszystko będzie się działo.

## CI (siatka bezpieczeństwa)

`.github/workflows/ios-build.yml` buduje projekt automatycznie na maszynie macOS w GitHub Actions przy każdym pushu zmieniającym pliki w `ios/`, i zostawia zrzut ekranu z symulatora jako załącznik do przejrzenia w zakładce *Actions* na GitHubie — przydatne, gdy akurat nie masz otwartego Xcode.
