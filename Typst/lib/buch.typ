// ============================================================
//  buch.typ — das ganze Buch: Seitenlayout, Deckblatt, Impressum,
//  Inhaltsverzeichnis, Kategorien + Songs, Grifftabelle
//  (entspricht dem Gerüst von main.tex)
// ============================================================
#import "stil.typ": *
#import "songs.typ": *
#import "griffbilder.typ": griffdatei-lesen, grifftabelle

// buch: Array von (titel: "Kategorie", songs: ("datei-a", "datei-b", ...))
#let liederbuch(buch) = {
  set document(title: "Liederbuch")
  set text(lang: "de", font: serif, size: 10pt, fill: farbe.text)
  set page(
    width: papier.breite, height: papier.hoehe,
    margin: (inside: rand.innen, outside: rand.aussen, top: rand.oben, bottom: rand.unten),
    fill: farbe.papier,
    foreground: vordergrund,
  )

  // ---------------- Deckblatt ----------------
  ohne-seitenzahl
  v(45mm)
  align(center, {
    text(weight: "bold", fill: farbe.titel, ..fs(gr.covertitel), "Liederbuch")
    linebreak()
    v(2mm)
    text(style: "italic", fill: farbe.meta, ..fs(gr.coversub), "Stamm Bruder Klaus Konstanz")
  })

  // ---------------- Impressum ----------------
  pagebreak()
  ohne-seitenzahl
  v(2mm)
  ueberschrift("Impressum")
  [
    "Warum etwas sagen, wenn man es auch singen kann?" \
    *- Walt Disney* #text(style: "italic", fill: farbe.meta)[u.a. Erfinder von Mickey Mouse]
    #v(2mm)
    Falls jemand das Buch neu auflegen, erweitern oder in irgendeiner Form
    verändern möchte, stehen alle Dokumente zur freien (für private Zwecke).
    Die Quellen sind auf GitHub unter #link("https://github.com/pfadi/songbook")[github.com/pfadi/songbook]
    zur Verfügung.
    #v(2mm)
    Dieses Liederbuch dient lediglich der privaten Nutzung.
    Alle Rechte an den Texten und Melodien liegen bei den jeweiligen Urhebern.
  ]

  // ---------------- Inhaltsverzeichnis ----------------
  pagebreak()
  v(6mm)
  inhaltsverzeichnis(buch)

  // ---------------- Songs ----------------
  for (i, k) in buch.enumerate() {
    kategorie(i, k.titel)
    songliste(i, k.songs)
  }

  // ---------------- Grifftabelle ----------------
  pagebreak()
  ueberschrift("Griffe")
  grifftabelle(griffdatei-lesen("/griffe.txt"))
}
