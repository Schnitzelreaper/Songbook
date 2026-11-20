# Liederbuch in Typst

Das Liederbuch, gesetzt mit [Typst](https://typst.app). Die Songs sind einfache
Textdateien, und das ganze Buch ist in rund 3 Sekunden gebaut. Eigenständig:
Alles, was gebraucht wird (Songs, Griffe, Grafiken, Schrift), liegt in diesem Ordner.

## Bauen

Typst installieren (einmalig), z. B. mit `winget install Typst.Typst`. Dann in diesem Ordner:

```bash
typst compile --font-path fonts main.typ
```

Mit `typst watch --font-path fonts main.typ` wird die PDF bei jeder Änderung sofort neu gebaut.

## Songs hinzufügen

1. Datei `songs/<name>.txt` anlegen (Format siehe unten)
2. `<name>` in `main.typ` in die passende Kategorie eintragen, alphabetisch nach
   Titel. So erscheint der Song im Inhaltsverzeichnis. Im Buch sortiert Typst die
   Songs selbst so um, dass zweiseitige Songs auf einer Doppelseite liegen.

## Songformat (`songs/*.txt`)

```
titel: Africa
interpret: Toto
info: Capo 2
griff: Bb  x,x,.,.,.,.  3:3:3,4:3:4,5:3:2,6:1:1     (nur für diesen Song, optional)
---
{Intro:}
[G  Bm   G  Bm]
{1.}[A                C#m     F#m]
I hear the drums echoing tonight
```

| Schreibweise | Bedeutung |
|---|---|
| `[G  Bm]` | Akkorde (fett) |
| `{Chorus:}` | Label (grau) |
| `<(Zweitstimme)>` | Zweitstimme / Zusatzinfo (grau) |
| `\|` | Wiederholungszeichen (grau) |
| `@griffe{C, G}` / `@griffe[1]{C, G}` | Griffbilder rechts am Rand auf Höhe der Zeile (`[1]` = 1 Griff pro Reihe) |
| `@schlagmuster{datei}[Beschriftung]` | Schlagmuster aus `graphics/` rechts am Rand |
| `@illustration[30mm]{datei}{x}{y}` | Bild aus `graphics/illustrationen/`, x/y = Abstand von der linken oberen Papierecke |
| `@anmerkung{Text}` | Fußnote am Songende (unten, sonst rechts neben dem Text) |
| `@seite` | neue Seite |
| `\[`, `\{`, `\<`, `\@` | das Zeichen selbst |

Leerzeichen werden genau so übernommen, wie sie in der Datei stehen.

## Griffe (`griffe.txt`, `griffe-zusatz.txt`)

Eine Zeile pro Griff: `Name  Marken  Punkte  [Bund]  [Barré]`

- Marken: 6× `x`/`o`/`.`, tiefe E → hohe e
- Punkte: `Saite:Bund:Finger`, kommagetrennt (`-` = keine)
- Bund: Startbund-Beschriftung (`-` = keine)
- Barré: `Bund:StartSaite:EndSaite`

`griffe.txt` wird am Ende des Buchs als Tabelle gedruckt (`leer` = leeres
Griffbrett, `/` = neue Zeile). `griffe-zusatz.txt` ist nur für `@griffe` da.

## Aufbau

- `main.typ`: Kategorien und Songs
- `lib/stil.typ`: Schriften, Größen, Farben, Ränder
- `lib/songs.typ`: Songs lesen und setzen, Griffe, Schlagmuster, Illustrationen,
  Anmerkungen, Songreihenfolge, Inhaltsverzeichnis
- `lib/griffbilder.typ`: Griffbilder zeichnen, Grifftabelle
- `lib/buch.typ`: Deckblatt, Impressum, Gerüst des Buchs
- `graphics/`: Schlagmuster und Illustrationen (PDF)
- `fonts/`: Inconsolata. Die Serifenschrift ist im Moment „Times New Roman“
  (Windows); für andere Rechner besser TeX Gyre Termes nach `fonts/` legen und
  in `lib/stil.typ` eintragen.
- `tools/latex2song.py`: Umzugswerkzeug, übernimmt Songs aus einem LaTeX-Liederbuch:
  `python tools/latex2song.py <latex-ordner> --alle` (mit `--buch` wird auch
  `main.typ` neu geschrieben, Achtung: überschreibt)
