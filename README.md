# Patronette – tipare de croitorie pe măsura ta

Aplicație mobilă (Flutter) care generează tipare de haine din măsurile
corpului și le exportă ca PDF la scară reală, de printat pe coli A4.

## Ce face

1. **Profiluri de măsuri** – salvezi măsurile mai multor persoane, pe telefon.
2. **Ghid de măsurare** – fiecare măsură are un desen și o explicație.
3. **Patru modele** – fustă dreaptă, fustă cloș (cerc sau semicerc),
   tricou, corsaj de bază.
4. **Previzualizare** – tiparul se redesenează imediat când schimbi
   lungimea, lărgimea sau rezervele de cusătură.
5. **Calculator de material** – spune câți metri trebuie cumpărați la
   lățimea aleasă (110, 140 sau 150 cm) și arată așezarea pieselor pe
   materialul pliat.
6. **Export PDF** – o pagină cu instrucțiuni, pătrat de test de 5 × 5 cm și
   harta paginilor, apoi tiparul 1:1 împărțit pe A4, cu romburi de potrivire.

## Cum rulezi aplicația

Ai nevoie de [Flutter](https://docs.flutter.dev/get-started/install).
Pentru telefon Android îți mai trebuie Android Studio (de la el vine
Android SDK-ul).

```bash
# o singură dată: generează folderele pentru Android și iOS
flutter create --project-name croi --platforms android,ios,web .

flutter pub get
flutter test          # testele formulelor și ale exportului PDF
flutter run           # pe telefonul conectat prin USB sau pe emulator
flutter run -d chrome # în browser, pentru o probă rapidă
```

## Cum este organizat codul

| Folder / fișier | Ce conține |
| --- | --- |
| `lib/geometry.dart` | Puncte, linii, curbe, arce; calculul rezervei de cusătură |
| `lib/models/` | Măsurile, profilul, piesa de tipar |
| `lib/garments/` | Câte un fișier pentru fiecare model, cu formulele lui |
| `lib/drawing/` | Așezarea pieselor pe planșă și desenarea lor |
| `lib/export/` | Împărțirea pe pagini A4 și generarea PDF-ului |
| `lib/fabric/` | Calculatorul de material și desenul cu așezarea pe material |
| `lib/screens/` | Ecranele aplicației |
| `lib/data/profile_store.dart` | Salvarea profilurilor pe telefon |
| `test/` | Teste automate |

### Ideea principală: tipare parametrice

Fiecare model este o clasă care primește măsurile și întoarce piesele
(`Garment.draft`). Piesele sunt descrise în centimetri, ca linii și curbe.
De exemplu, la fusta cloș raza taliei este `talie / 2π`, ca lungimea
cercului să fie exact talia.

Tiparul se desenează o singură dată, în `drawing/pattern_canvas.dart`,
printr-o interfață (`PatternCanvas`) cu două implementări: una pentru ecran
și una pentru PDF. Așa ecranul și hârtia arată identic.

### Rezerva de cusătură

Fiecare margine a unei piese are un tip: cusătură, tiv sau pliu
(`EdgeKind`). Linia de tăiere se obține mutând fiecare margine spre
exterior cu rezerva ei (pliul nu primește rezervă) și intersectând
marginile vecine (`offsetOutline` din `geometry.dart`).

### Calculatorul de material

Materialul se consideră pliat în două pe lung. Piesele „pe pliu” se
lipesc de îndoitură, iar celelalte se taie prin ambele straturi, deci o
tăietură dă două piese în oglindă. Piesele stau cu firul drept pe lungimea
materialului și coboară, ca la Tetris, până ating piesele de dedesubt,
după forma lor reală (`lib/fabric/fabric_plan.dart`). Se încearcă mai
multe ordini de așezare și se păstrează cea mai scurtă. La rezultat se
adaugă 10 cm pentru intrarea la spălat.

### Ce verifică testele

- rezerva de cusătură mută corect fiecare latură, inclusiv 0 cm pe pliu;
- talia fustei cloș are exact măsura taliei;
- la fusta dreaptă, talia minus pense este sfertul de talie;
- capul mânecii are aceeași lungime ca răscroiala;
- toate modelele dau contururi corecte și la măsuri extreme;
- fiecare model se exportă ca PDF (fișierele ajung în `build/pdf_test/`);
- calculatorul de material taie fiecare piesă de câte ori trebuie, fără
  suprapuneri, cu cantități realiste;
- ecranul tiparului arată materialul necesar și deschide desenul de așezare.

## Limite cunoscute

- Formulele sunt simplificate: tiparele trebuie probate o dată pe material
  ieftin înainte de a tăia materialul bun.
- Corsajul nu are pensă de bust.

## Licențe

Fonturile Noto Sans din `assets/fonts/` sunt sub licența SIL Open Font
License 1.1 (The Noto Project Authors).
