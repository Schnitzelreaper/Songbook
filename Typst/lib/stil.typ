// ============================================================
//  stil.typ — Schriften, Größen, Farben, Seitenränder
//  (entspricht style/schriften.tex + Teilen von style/layout.tex)
//  Hier ändern, sonst nirgends.
// ============================================================

// --- Schriften ----------------------------------------------
// Serifenschrift (Titel, Meta, Inhaltsverzeichnis, Seitenzahl)
#let serif = "Times New Roman"
// Monospace (Akkorde + Songtext). MUSS dickten-gleich bleiben!
#let mono = "Inconsolatazi4"

// --- Schriftgrößen: (Größe, Zeilenabstand) ------------------
#let gr = (
  body:       (9.5pt, 10.5pt),  // Songtext
  songnum:    (28pt, 22pt),     // Songnummer
  songtitel:  (17pt, 19pt),     // Songtitel
  meta:       (9pt, 11pt),      // Interpret / Capo
  covertitel: (28pt, 32pt),
  coversub:   (12pt, 14pt),
  kat:        (19pt, 22pt),     // Kategorie / Überschriften
  katbuchst:  (72pt, 72pt),     // Buchstabe auf Kategorie-Seite
  katseite:   (24pt, 28pt),     // Titel auf Kategorie-Seite
  seitenzahl: (9pt, 11pt),
  anmerkung:  (8.5pt, 11pt),
  griffname:  (11pt, 13pt),
)

// --- Farbpalette --------------------------------------------
#let farbe = (
  papier:   rgb("#fbfbf9"),  // Papierfarbe (Vintage-Creme)
  text:     rgb("#000000"),  // Haupttext
  akkord:   rgb("#232323"),  // Akkorde
  titel:    rgb("#282828"),  // Überschriften
  meta:     rgb("#8e8e8e"),  // Interpret / Capo-Zeile
  griffe:   rgb("#c3c3c1"),  // Griffbilder im Songtext (= Schwarz mit 22 % Deckkraft auf Papier)
  linie:    rgb("#999999"),  // Trennlinien / Punktlinien
)
// Schlagmuster: Schwarz mit dieser Deckkraft (wird durch einen
// halbdurchsichtigen Papier-Schleier über dem Bild erreicht)
#let schlagmuster-deckkraft = 22%
#let schlagmuster-skala = 0.32
#let griffe-skala = 0.75
#let griffe-abstand = 3mm

// --- Seite (DIN A5, zweiseitig) -----------------------------
#let papier = (breite: 148mm, hoehe: 210mm)
#let rand = (innen: 14mm + 4mm /* Bindekorrektur */, aussen: 10mm, oben: 12mm, unten: 10mm)
#let textbreite = papier.breite - rand.innen - rand.aussen
// linker Textrand (vom Papierrand) auf Seite p: ungerade = rechte Seite
#let textlinks(p) = if calc.odd(p) { rand.innen } else { rand.aussen }

// Schrift mit festem Zeilenabstand (wie \fontsize{a}{b}\selectfont):
// Jede Zeile ist genau `b` hoch, die Grundlinie liegt bei 70 %.
#let fs(paar) = (size: paar.at(0), top-edge: 0.7 * paar.at(1), bottom-edge: -0.3 * paar.at(1))
