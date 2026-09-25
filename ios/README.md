# SimLife na iPada — Faza 2 (ruch i gesty)

To jest natywna aplikacja SwiftUI + SpriteKit, oddzielna od wersji przeglądarkowej w katalogu głównym repo. Faza 0 udowodniła, że cały łańcuch narzędzi (XcodeGen → Xcode → symulator) działa. Faza 1 przeniosła prawdziwy dom z `app.js`: 16×9 pól, 5 pokoi z automatycznie wygenerowanymi ścianami/drzwiami/oknami i starterowe meble. Faza 2 dodaje interakcję:

- **Dotknij pustego pola**, żeby Sim tam poszedł — prawdziwy pathfinding (BFS) omija ściany i meble, tak jak w wersji przeglądarkowej.
- **Przeciągnij**, żeby przesunąć widok kamery.
- **Uszczypnij (pinch)**, żeby przybliżyć/oddalić — zoomuje w punkt pod palcami.

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

Jeśli to działa — ruch i kamera są gotowe, możemy przejść do kolejnej fazy: potrzeb, umiejętności, kariery i trybu budowania.

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
