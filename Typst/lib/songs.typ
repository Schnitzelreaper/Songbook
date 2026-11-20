// ============================================================
//  songs.typ — Songdateien lesen und setzen
//  (entspricht style/songs.tex, griffe.tex, schlagmuster.tex,
//   illustrationen.tex, anmerkungen.tex)
// ============================================================
#import "stil.typ": *
#import "griffbilder.typ": *

// Griffe aus der Tabelle und den Zusatzgriffen, abrufbar per Name
#let alle-griffe = {
  let d = (:)
  for g in (griffdatei-lesen("/griffe.txt") + griffdatei-lesen("/griffe-zusatz.txt")).flatten() {
    if g != none { d.insert(g.name, g) }
  }
  d
}

// Typografie für Serifentext (wie LaTeX: ' -> ’, -- -> –)
#let typo(s) = s.replace("---", "—").replace("--", "–").replace("'", "’")

// ------------------------------------------------------------
//  Songdatei lesen: Kopf (titel/interpret/info/griff) + Text
// ------------------------------------------------------------
#let song-lesen(id) = {
  let roh = read("/songs/" + id + ".txt").replace("\r", "")
  let (kopf, ..text) = roh.split("\n---\n")
  let k = (titel: id, interpret: "", info: "", griffe: (:))
  for z in kopf.split("\n") {
    let m = z.match(regex("^(\w+):\s*(.*)$"))
    if m == none { continue }
    let (key, val) = m.captures
    if key == "griff" {
      let g = griff-lesen(val)
      k.griffe.insert(g.name, g)
    } else { k.insert(key, typo(val.trim())) }
  }
  k.text = text.join("\n---\n")
  k
}

// ------------------------------------------------------------
//  Eine Textzeile in Stücke zerlegen
// ------------------------------------------------------------
#let muster = (
  (art: "griffe",       re: regex("^@griffe(?:\[(\d+)\])?\{([^}]*)\}")),
  (art: "schlagmuster", re: regex("^@schlagmuster\{([^}]*)\}(?:\[([^\]]*)\])?")),
  (art: "illustration", re: regex("^@illustration(?:\[([^\]]*)\])?\{([^}]*)\}\{([^}]*)\}\{([^}]*)\}(?:\[([^\]]*)\])?")),
  (art: "anmerkung",    re: regex("^@anmerkung\{([^}]*)\}")),
  (art: "seite",        re: regex("^@seite")),
  (art: "akkord",       re: regex("^\[((?:[^\]\\\\]|\\\\.)*)\]")),
  (art: "label",        re: regex("^\{([^}]*)\}")),
  (art: "stimme",       re: regex("^<([^>]*)>")),
  (art: "text",         re: regex("^\\\\(.)")),
  (art: "text",         re: regex("^([^\[\]{}<>@\\\\]+|.)")),
)
#let zeile-zerlegen(z) = {
  let stuecke = ()
  let rest = z
  while rest.len() > 0 {
    for m in muster {
      let t = rest.match(m.re)
      if t != none {
        stuecke.push((art: m.art, args: t.captures))
        rest = rest.slice(t.end)
        break
      }
    }
  }
  stuecke
}

// ------------------------------------------------------------
//  Bausteine
// ------------------------------------------------------------
// Escapes auflösen, Leerzeichen geschützt (kein Umbruch, kein Zusammenfassen).
// Inconsolata zeichnet ' gebogen; U+A78C ist im selben Font ein gerader Strich
// (wie in der LaTeX-Version).
#let nbsp(s) = (
  s.replace(regex("\\\\(.)"), m => m.captures.at(0))
    .replace(" ", "\u{00A0}")
    .replace("'", "\u{A78C}")
)
#let teil(art, s) = {
  let s = nbsp(s)
  if art == "akkord" { text(weight: "bold", fill: farbe.akkord, s) }
  else if art == "label" or art == "stimme" { text(style: "italic", fill: farbe.meta, s) }
  else { show "|": text.with(fill: farbe.meta); s }
}

// Griffe-Block: rechtsbündige Zeilen, pro Zeile k Griffe (0 = so viele wie passen)
#let griffe-block(namen, k, lokal) = context {
  let bilder = namen.map(n => {
    let g = lokal.at(n, default: alle-griffe.at(n, default: none))
    if g == none { g = leergriff + (name: n) }
    griffbild(g, grau: true)
  })
  let reihen(k) = bilder.chunks(k).map(r => r.join(h(griffe-abstand)))
  let bau(k) = scale(griffe-skala * 100%, reflow: true, origin: top + right,
    stack(dir: ttb, spacing: griffe-abstand, ..reihen(k).map(r => align(right, r))))
  let k = if k > 0 { calc.min(k, bilder.len()) } else {
    let k = bilder.len()
    while k > 1 and measure(bau(k)).width > textbreite { k -= 1 }
    k
  }
  bau(k)
}

// Schlagmuster: Bild-Oberkante auf Zeilenhöhe, Beschriftung darüber.
// -> (inhalt, ueber: Höhe über der Zeile)
#let schlagmuster-block(datei, beschriftung) = {
  let pfad = "/graphics/" + datei + ".pdf"
  let schleier = farbe.papier.transparentize(schlagmuster-deckkraft)
  let bild = context {
    let nat = measure(image(pfad))
    let w = nat.width * schlagmuster-skala
    let h = nat.height * schlagmuster-skala
    box(width: w, height: h, {
      image(pfad, width: w)
      place(top + left, rect(width: w, height: h, fill: schleier, stroke: none))
    })
  }
  let text = if beschriftung != none {
    text(font: serif, style: "italic", size: 7.5pt, fill: farbe.griffe,
      top-edge: "ascender", bottom-edge: "descender", beschriftung)
  }
  (
    inhalt: stack(dir: ttb, spacing: 0.5mm, align(right, text), align(right, bild)),
    ueber: text,
  )
}

// Anmerkung (Fußnote am Songende) mit Breite b
#let anmerkung-block(t, b) = block(width: b, {
  set text(font: serif, style: "italic", fill: farbe.meta, hyphenate: auto, ..fs(gr.anmerkung))
  set par(leading: 0pt, justify: b >= textbreite)
  line(length: 25mm, stroke: 0.4pt + farbe.linie)
  v(1.2mm)
  t
})

// ------------------------------------------------------------
//  Anmerkung platzieren: unten auf die letzte Seite, sonst rechts daneben
// ------------------------------------------------------------
#let anmerkung-setzen(t, id) = context {
  let abstand = 3mm
  let unten = papier.hoehe - rand.unten
  // Ende des Songtexts (feste Markierung, hängt nicht von der Anmerkung ab)
  let marke = query(<songtext-ende>).filter(m => m.value == id)
  let pos = if marke.len() > 0 { marke.first().location().position() } else { here().position() }
  let voll = anmerkung-block(t, textbreite)
  let h = measure(voll).height
  if pos.y + abstand + h <= unten + 1pt {
    // letzte Grundlinie genau auf dem unteren Textrand (wie in LaTeX)
    place(bottom + left, dy: 0.3 * gr.anmerkung.at(1), voll)
    return
  }
  // daneben: Hindernisse (Textzeilen + Griffe/Schlagmuster) dieser Seite
  let p = here().page()
  let links = textlinks(p)
  let hind = (
    query(<songzeile>)
      .filter(m => m.value.song == id and m.location().page() == p)
      .map(m => {
        let q = m.location().position()
        (x: q.x - links + m.value.w, oben: q.y + m.value.dy, unten: q.y + m.value.dy + m.value.h)
      })
  )
  if hind.len() == 0 { voll; return }
  let lueckeV = 1.5mm
  let grenze-unten = unten - 12pt   // Seitenzahl freihalten
  let grenze-oben = calc.min(..hind.map(o => o.oben))
  for anteil in (0.5, 0.42, 0.6, 0.35) {
    let b = anteil * textbreite
    let blk = anmerkung-block(t, b)
    let bh = measure(blk).height
    let limit = textbreite - b - griffe-abstand
    let stoert = hind.filter(o => o.x > limit)
    let kandidaten = (grenze-unten,) + stoert.map(o => o.oben - lueckeV)
    let frei(u) = u <= grenze-unten and u - bh >= grenze-oben and stoert.all(o =>
      not (o.unten + lueckeV > u - bh and o.oben - lueckeV < u))
    let gut = kandidaten.filter(frei)
    if gut.len() > 0 {
      let u = calc.max(..gut)
      place(top + left, dx: textbreite - b, dy: u - bh - rand.oben, blk)
      return
    }
  }
  // passt nirgends: trotzdem unten anhängen (landet ggf. auf neuer Seite)
  v(abstand)
  voll
}

// ------------------------------------------------------------
//  Song setzen
// ------------------------------------------------------------
#let zeilenhoehe = gr.body.at(1)

#let song(id, nummer: none) = {
  let s = song-lesen(id)
  let anmerkungen = ()

  pagebreak(weak: true)
  [#metadata((id: id, nummer: nummer, titel: s.titel)) <song-start>]

  set block(spacing: 0pt)
  set par(leading: 0pt, justify: false)
  set smartquote(enabled: false)

  // Kopf: Nummer | Titel + Interpret · Info
  // (Grundlinien wie in der LaTeX-Version: Nummer 28.8pt, Titel 21.6pt,
  //  Meta 33.5pt unter dem oberen Textrand, Linie bei 41.9pt)
  set text(font: serif, fill: farbe.titel)
  grid(
    columns: (21mm, 1fr),
    text(weight: "bold", size: gr.songnum.at(0), top-edge: 28.8pt, bottom-edge: "baseline",
      if nummer != none { nummer }),
    stack(dir: ttb,
      text(weight: "bold", size: gr.songtitel.at(0), top-edge: 21.6pt, bottom-edge: "baseline", s.titel),
      text(style: "italic", fill: farbe.meta, size: gr.meta.at(0), top-edge: 11.9pt, bottom-edge: -3.3pt,
        s.interpret + if s.info != "" { " · " + s.info }),
    ),
  )
  v(5.1pt)
  line(length: 100%, stroke: 0.4pt + farbe.linie)
  v(1.95pt)

  // Songtext: jede Zeile ein Block mit fester Höhe
  set text(font: mono, fill: farbe.text, ..fs(gr.body), hyphenate: false)
  let zeichenbreite = 0.5 * gr.body.at(0) // Inconsolata: halbe Geviertbreite

  let zeilen = s.text.trim("\n", at: end).split("\n")
  // Leerzeilen sammeln: als "schwache" Abstände setzen, die (wie in LaTeX)
  // am Seitenanfang wegfallen
  let leer = 0
  let angefangen = false
  for z in zeilen {
    if z.trim() == "" { if angefangen { leer += 1 }; continue }
    if leer > 0 { v(leer * zeilenhoehe, weak: true); leer = 0 }
    let stuecke = zeile-zerlegen(z)
    let inhalt = ()
    let rand-elemente = ()   // rechts am Rand überlagert
    let illus = ()
    let neue-seite = false
    let nur-anmerkung = stuecke.len() > 0 and stuecke.all(t => t.art == "anmerkung")
    let breite = 0
    let leerzeichen = 0
    for t in stuecke {
      let a = t.args
      if t.art in ("text", "akkord", "label", "stimme") {
        inhalt.push(teil(t.art, a.at(0)))
        breite += nbsp(a.at(0)).clusters().len()
        leerzeichen += a.at(0).split(" ").len() - 1
      } else if t.art == "griffe" {
        let k = if a.at(0) == none { 0 } else { int(a.at(0)) }
        let namen = a.at(1).split(",").map(n => n.trim()).filter(n => n != "")
        rand-elemente.push((inhalt: griffe-block(namen, k, s.griffe), ueber: none))
      } else if t.art == "schlagmuster" {
        rand-elemente.push(schlagmuster-block(a.at(0), a.at(1)))
      } else if t.art == "illustration" {
        illus.push((breite: a.at(0), datei: a.at(1), x: a.at(2), y: a.at(3), opt: a.at(4)))
      } else if t.art == "anmerkung" {
        anmerkungen.push(typo(a.at(0)))
      } else if t.art == "seite" {
        neue-seite = true
      }
    }
    if neue-seite { pagebreak(); continue }
    if nur-anmerkung { continue }
    // Zeilen vor dem ersten sichtbaren Text (Leerzeilen, nur Befehle wie
    // @illustration) brauchen in LaTeX keinen Platz
    if inhalt.len() > 0 { angefangen = true }
    // Zu lange Zeile: Leerzeichen stauchen wie TeX (Inconsolata: höchstens
    // 0.1em pro Leerzeichen), was dann noch übersteht, läuft über den Rand
    let natur = breite * zeichenbreite
    let stauchung = if natur > textbreite and leerzeichen > 0 {
      calc.min((natur - textbreite) / leerzeichen, 0.1 * gr.body.at(0))
    } else { 0pt }
    breite = (natur - leerzeichen * stauchung) / zeichenbreite
    block(width: 100%, height: if angefangen { zeilenhoehe } else { 0pt }, breakable: false, {
      // Position + Breite dieser Zeile merken (für die Platzsuche der Anmerkung)
      if breite > 0 {
        place(top + left, [#metadata((song: id, w: breite * zeichenbreite, h: zeilenhoehe, dy: 0pt)) <songzeile>])
      }
      for i in illus { [#metadata(i) <illustration>] }
      for r in rand-elemente {
        place(top + right, context {
          let dy = -1pt
          if r.ueber != none { dy -= measure(r.ueber).height + 0.5mm }
          let hoehe = measure(r.inhalt).height
          // Fläche als Hindernis für die Anmerkung merken (ganze Breite rechts)
          [#metadata((song: id, w: 1000mm, h: hoehe, dy: dy)) <songzeile>]
          move(dy: dy, r.inhalt)
        })
      }
      // nie umbrechen: zu lange Zeilen laufen (wie in LaTeX) über den Rand
      box(width: 3 * textbreite, if stauchung > 0pt {
        show "\u{00A0}": h(zeichenbreite - stauchung)
        inhalt.join()
      } else { inhalt.join() })
    })
  }

  set text(font: serif)
  // Markierung in eigenem Block, damit ihre Position nicht vom
  // nachfolgenden v(1fr) der Anmerkung abhängt
  block(height: 0pt, [#metadata(id) <songtext-ende>])
  for t in anmerkungen { anmerkung-setzen(t, id) }
  [#metadata(id) <song-ende>]
}

// ------------------------------------------------------------
//  Illustrationen (Vordergrund, absolute Position auf dem Papier)
// ------------------------------------------------------------
#let mm(s) = float(s.trim().trim("mm", at: end).trim()) * 1mm
#let illustration-zeichnen(i) = context {
  let pfad = "/graphics/illustrationen/" + i.datei + ".pdf"
  let w = if i.breite == none { 40mm } else { mm(i.breite) }
  let bild = if i.opt != none and i.opt.contains("trim") {
    // trim=links unten rechts oben (pt), wie bei \includegraphics
    let (l, b, r, o) = i.opt.match(regex("trim\s*=\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)"))
      .captures.map(float).map(x => x * 1pt)
    let nat = measure(image(pfad))
    let f = w / (nat.width - l - r)
    box(width: w, height: (nat.height - b - o) * f, clip: true,
      place(top + left, dx: -l * f, dy: -o * f, image(pfad, width: nat.width * f)))
  } else { image(pfad, width: w) }
  place(top + left, dx: mm(i.x), dy: mm(i.y), bild)
}

// ------------------------------------------------------------
//  Seitenvordergrund: Illustrationen + Seitenzahl
// ------------------------------------------------------------
#let vordergrund = context {
  let p = here().page()
  for m in query(<illustration>) {
    if m.location().page() == p { illustration-zeichnen(m.value) }
  }
  let ohne = query(<ohne-seitenzahl>).any(m => m.location().page() == p)
  if not ohne {
    let zahl = text(font: serif, fill: farbe.meta, size: gr.seitenzahl.at(0),
      bottom-edge: "baseline", str(p))
    if calc.odd(p) {
      place(bottom + right, dx: -rand.aussen, dy: -6mm, zahl)
    } else {
      place(bottom + left, dx: rand.aussen, dy: -6mm, zahl)
    }
  }
}
#let ohne-seitenzahl = [#metadata(none) <ohne-seitenzahl>]

// ------------------------------------------------------------
//  Kategorien, Songreihenfolge, Inhaltsverzeichnis
// ------------------------------------------------------------
#let buchstabe(i) = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".at(i)

#let kategorie(i, titel) = {
  pagebreak(weak: true)
  [#metadata((i: i, titel: titel)) <kategorie>]
  v(1fr)
  align(center, {
    set text(font: serif, weight: "bold", fill: farbe.titel)
    text(..fs(gr.katbuchst), buchstabe(i))
    v(4mm)
    line(length: 30mm, stroke: 0.7pt + farbe.linie)
    v(5mm)
    text(..fs(gr.katseite), titel)
  })
  v(1fr)
  v(12mm)
}

// Songs einer Kategorie setzen. Liste alphabetisch (= Inhaltsverzeichnis).
// Im Buch wird so umsortiert, dass Songs mit gerader Seitenzahl (2, 4)
// immer auf einer linken (geraden) Seite beginnen -> Doppelseite.
// Ein- und dreiseitige Songs füllen die Lücken; nur wenn es gar nicht
// anders geht, bleibt eine Seite leer. Seitenzahlen kommen aus dem
// vorigen Layout-Durchlauf (Typst wiederholt das automatisch).
#let songliste(i, ids) = context {
  let start = query(<song-start>)
  let ende = query(<song-ende>)
  let seiten(id) = {
    let a = start.filter(m => m.value.id == id)
    let e = ende.filter(m => m.value == id)
    if a.len() > 0 and e.len() > 0 { e.first().location().page() - a.first().location().page() + 1 } else { 1 }
  }
  // Seite der Kategorie-Trennseite (here() läge schon auf der Folgeseite)
  let kat = query(<kategorie>).filter(m => m.value.i == i)
  let seite = if kat.len() > 0 { kat.first().location().page() } else { here().page() }
  let rest = ids
  let nr = 0
  while rest.len() > 0 {
    let gerade = calc.even(seite + 1)
    let wahl = rest.position(id => gerade or calc.odd(seiten(id)))
    if wahl == none {
      pagebreak(weak: true)
      ohne-seitenzahl
      seite += 1
    } else {
      let id = rest.remove(wahl)
      nr += 1
      song(id, nummer: buchstabe(i) + str(nr))
      seite += seiten(id)
    }
  }
}

#let ueberschrift(t) = block(spacing: 0pt, {
  set block(spacing: 0pt)
  block(text(font: serif, weight: "bold", fill: farbe.titel, size: gr.kat.at(0),
    top-edge: "cap-height", bottom-edge: "descender", t))
  v(0.5mm)
  line(length: 100%, stroke: 0.7pt + farbe.linie)
  v(4mm)
})

#let inhaltsverzeichnis(buch) = context {
  set text(font: serif, ..fs((10pt, 12pt)))
  set par(leading: 0pt)
  let start = query(<song-start>)
  let kats = query(<kategorie>)
  let nummernbreite = 6mm
  ueberschrift("Inhaltsverzeichnis")
  for (i, k) in buch.enumerate() {
    let km = kats.filter(m => m.value.i == i)
    let kseite = if km.len() > 0 { km.first().location().page() } else { "?" }
    v(4mm, weak: true)
    block(spacing: 0pt, link(if km.len() > 0 { km.first().location() } else { (page: 1, x: 0pt, y: 0pt) },
      text(weight: "bold", fill: farbe.titel,
        box(width: nummernbreite, buchstabe(i)) + k.titel + h(1fr) + str(kseite))))
    for id in k.songs {
      let m = start.filter(m => m.value.id == id)
      let titel = song-lesen(id).titel
      if m.len() == 0 { block(above: 1.1mm, box(width: nummernbreite, "?") + titel); continue }
      let m = m.first()
      block(above: 1.1mm, link(m.location(),
        box(width: nummernbreite, m.value.nummer.slice(1)) + titel + " "
        + box(width: 1fr, repeat(gap: 4.5pt, justify: false, text(fill: farbe.linie, ".")))
        + " " + text(fill: farbe.meta, str(m.location().page()))))
    }
  }
}
