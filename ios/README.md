# SimLife na iPada — Faza 0 (szkielet projektu)

To jest natywna aplikacja SwiftUI + SpriteKit, oddzielna od wersji przeglądarkowej w katalogu głównym repo. Na razie (Faza 0) scena jest celowo minimalna — jej jedynym celem jest udowodnienie, że cały łańcuch (XcodeGen → Xcode → symulator) działa, zanim zaczniemy przenosić właściwą grę.

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
3. Po chwili powinieneś zobaczyć: niebieskie niebo (gradient), zielone izometryczne pola w stylu naszej gry przeglądarkowej, i napis „SimLife — pipeline dziala”.

Jeśli to widzisz — cały łańcuch narzędzi działa i możemy przenosić właściwą grę.

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
