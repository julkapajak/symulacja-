# SimLife na iPada — Faza 8 (prawdziwe 3D)

To jest natywna aplikacja SwiftUI, oddzielna od wersji przeglądarkowej w katalogu głównym repo. Faza 0 udowodniła, że cały łańcuch narzędzi (XcodeGen → Xcode → symulator) działa. Fazy 1-7 zbudowały pełną rozgrywkę w silniku 2D (SpriteKit, izometryczny rzut jak w wersji przeglądarkowej). **Faza 8 to duża zmiana architektoniczna: przepisanie całego renderowania na prawdziwe 3D (SceneKit)** z kamerą, którą można swobodnie obracać wokół domu (pełne 360°) i przybliżać/oddalać — na życzenie, zamiast stałego kąta izometrycznego. Cała rozgrywka (potrzeby, akcje, kariera, aspiracje, tryb budowania, zapis) działa identycznie jak wcześniej — zmienił się tylko sposób rysowania i oglądania świata.

Skrót tego, co było w 2D (Fazy 1-2), teraz przeniesione na 3D:

- **Dotknij pustego pola**, żeby Sim tam poszedł — prawdziwy pathfinding (BFS) omija ściany i meble.
- **Przeciągnij**, żeby obrócić kamerę wokół domu (pełne 360°, w dowolną stronę).
- **Uszczypnij (pinch)**, żeby przybliżyć/oddalić.

Faza 3 dodaje samą rozgrywkę:

- **6 potrzeb** (głód, energia, higiena, zabawa, kontakty, pęcherz), opadających w czasie — widoczne jako paski na dole ekranu.
- **Dotknij mebla**, żeby z niego skorzystać (zjedz przy lodówce, prysznic, sen w łóżku, TV, komputer, itd.) — Sim tam podejdzie i użyje go.
- **Umiejętności** (gotowanie, kondycja, charyzma) rosnące wraz z użyciem powiązanych sprzętów.
- **Kariera**: samochód to praca — dojazd 8:00–18:00, wypłata i awanse co 3 zmiany.
- **Autonomia**: gdy potrzeba spadnie krytycznie nisko, Sim sam idzie ją zaspokoić.
- **HUD** (SwiftUI, nałożony na scenę): pieniądze, dzień, godzina, stanowisko, paski potrzeb i dymki z komunikatami.

Faza 4 dodała **zapis stanu gry** — postęp zapisuje się automatycznie co 30 sekund i przy przejściu aplikacji w tło, a wczytuje się przy starcie.

Faza 5 dodaje **tryb budowania**:

- **Przycisk 🔨** w prawym górnym rogu włącza/wyłącza tryb budowania.
- W trybie budowania na dole pojawia się **pasek zakupów** — dotknij ikonę mebla, żeby go wybrać (podświetli się), potem dotknij puste pole w domu, żeby go tam postawić (jeśli starczy pieniędzy).
- **Dotknięcie istniejącego mebla** w trybie budowania sprzedaje go za połowę ceny (samochodu nie da się sprzedać).
- Rozstawione meble zapisują się razem z resztą stanu gry.

Faza 6 dodała **aspiracje** — cel życiowy z jednorazową nagrodą pieniężną po spełnieniu (Mistrz Kuchni, Rekin Biznesu, Dusza Towarzystwa, Żelazna Kondycja), widoczny jako chip z paskiem postępu w HUD-zie.

Faza 7 dodaje **kreator postaci** — przy pierwszym uruchomieniu (bez wcześniejszego zapisu) gra pyta o imię, kolor, cechę charakteru (Towarzyski/Pracowity/Leniwy/Imprezowicz — każda ma realny wpływ na tempo opadania potrzeb albo zarobki) i aspirację życiową, zamiast przydzielać je losowo. Jeśli zapis już istnieje, kreator jest pomijany i gra wraca prosto do zapisanego Sima.

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
3. Ponieważ masz już zapisaną grę z poprzednich testów, od razu zobaczysz dom (kreator postaci pomija się, gdy zapis już istnieje). Żeby zobaczyć sam kreator, usuń aplikację z symulatora (przytrzymaj ikonę → Usuń) i uruchom ją ponownie od zera.
4. Powinnaś zobaczyć: niebieskie tło, prawdziwy trójwymiarowy dom (bryły ścian, kolorowe podłogi per pokój, meble jako kolorowe pudełka z unoszącą się nad nimi ikoną) i stojącego Sima (kapsuła + kulista głowa) w wybranym kolorze.
5. **Przeciągnij palcem/myszką** po ekranie — kamera powinna obracać się swobodnie wokół domu, włącznie z widokiem od góry i z boku (pełne 360°). **Uszczypnij** (na symulatorze: Option + przeciągnięcie) — przybliżenie/oddalenie.
6. Dotknij dowolnego wolnego pola podłogi — Sim powinien tam dojść, omijając ściany. Dotknij lodówki, łóżka, prysznica, TV albo komputera — Sim podejdzie i zacznie z nich korzystać (dymek z komunikatem, pasek potrzeby rośnie). Dotknij samochodu w godzinach 8:00–18:00, żeby poszedł do pracy.
7. Zamknij i ponownie uruchom aplikację — stan gry powinien zostać taki, jaki był.
8. Dotknij 🔨 w prawym górnym rogu, wybierz mebel z paska na dole, dotknij puste pole żeby go postawić. Dotknij dowolny mebel (nadal w trybie budowania), żeby go sprzedać za połowę ceny.
9. Obok pieniędzy/dnia/godziny w górnym pasku powinien być widoczny chip z ikoną i paskiem postępu aspiracji.

Jeśli to działa — mamy solidny szkielet gry w prawdziwym 3D. Dalej w planie: bogata personalizacja wyglądu Sima (naturalne odcienie skóry, włosy, ubrania, sylwetka) i współlokator (drugi Sim + relacje).

## Testowanie na prawdziwym iPadzie (opcjonalnie, już teraz)

Nie musisz mieć płatnego konta Apple Developer, żeby testować na własnym urządzeniu:

1. Podłącz iPada kablem do Maca, "Zaufaj temu komputerowi" na iPadzie.
2. W Xcode: **Xcode → Settings → Accounts** → dodaj swój zwykły Apple ID (za darmo).
3. Wybierz swojego iPada jako cel uruchomienia (zamiast symulatora) i naciśnij ▶.
4. Xcode poprosi o włączenie *Developer Mode* w **Ustawienia → Prywatność i bezpieczeństwo** na iPadzie — włącz i zrestartuj.

Ograniczenie darmowego konta: certyfikat wygasa po 7 dniach (trzeba wtedy ponownie uruchomić z Xcode) i nie da się przez to wysłać do TestFlight/App Store — do tego będzie potrzebne płatne członkostwo (99$/rok), ale dopiero w późniejszej fazie.

## Co dalej

`GameCoordinator.swift` (SceneKit) to teraz odpowiednik dawnego `GameScene.swift` — cała logika sceny 3D, kamera i gesty. Kolejne fazy: bogaty kreator wyglądu Sima (skóra/włosy/ubrania/sylwetka jako osobne, wymienne modele 3D) i współlokator (drugi Sim + relacje).

## CI (siatka bezpieczeństwa)

`.github/workflows/ios-build.yml` buduje projekt automatycznie na maszynie macOS w GitHub Actions przy każdym pushu zmieniającym pliki w `ios/`, i zostawia zrzut ekranu z symulatora jako załącznik do przejrzenia w zakładce *Actions* na GitHubie — przydatne, gdy akurat nie masz otwartego Xcode.
