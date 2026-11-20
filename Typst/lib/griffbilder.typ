// ============================================================
//  griffbilder.typ — Griffbilder (Akkorddiagramme) einlesen und zeichnen
//  (entspricht style/griffbilder.tex)
// ============================================================
#import "stil.typ": *

#let saite = 2.0mm  // Saitenabstand
#let bund = 2.5mm   // Bundabstand

// Eine Griff-Zeile lesen:  Name  Marken  Punkte  [Bund]  [Barré]
//   Marken: 6x x/o/. (tiefe E -> hohe e), kommagetrennt
//   Punkte: Saite:Bund:Finger, kommagetrennt (Finger optional), "-" = keine
//   Bund:   Startbund-Beschriftung ("-" = keine)
//   Barré:  Bund:StartSaite:EndSaite
#let griff-lesen(zeile) = {
  let f = zeile.trim().split(regex("\s+"))
  let opt(i) = if f.len() > i and f.at(i) != "-" { f.at(i) } else { none }
  (
    name: f.at(0),
    marken: f.at(1).split(","),
    punkte: if opt(2) == none { () } else {
      opt(2).split(",").map(p => p.split(":"))
    },
    bund: opt(3),
    barre: if opt(4) == none { none } else { opt(4).split(":").map(int) },
  )
}

// Griffdatei (griffe.txt) -> Zeilen der Grifftabelle, jede ein Array von
// Griffen (none = leeres Griffbrett). "/" beendet eine Zeile.
#let griffdatei-lesen(pfad) = {
  let zeilen = ((),)
  for z in read(pfad).split("\n").map(z => z.trim()) {
    if z == "" or z.starts-with("#") { continue }
    if z == "/" { zeilen.push(()); continue }
    zeilen.last().push(if z == "leer" { none } else { griff-lesen(z) })
  }
  zeilen.filter(r => r.len() > 0)
}

#let leergriff = (name: "", marken: (".",) * 6, punkte: (), bund: none, barre: none)

// Griffbild zeichnen. grau: true -> alles in farbe.griffe (für \griffe)
#let griffbild(g, grau: false) = context {
  let g = if g == none { leergriff } else { g }
  let c(f) = if grau { farbe.griffe } else { f }
  let duenn = 0.4pt
  set text(font: serif, weight: "bold", top-edge: "cap-height", bottom-edge: "baseline")

  let name = text(size: gr.griffname.at(0), fill: c(farbe.titel), g.name)
  let nm = measure(name)
  let bundtext = if g.bund != none { text(size: 7pt, fill: c(farbe.akkord), g.bund) }
  let bm = if bundtext != none { measure(bundtext).width + 0.3 * saite } else { 0pt }
  let gw = 5 * saite
  // Rand links/rechts/oben/unten um das Gitter (wie die TikZ-Bounding-Box)
  let ox = calc.max(nm.width / 2 - gw / 2, 2.3pt + duenn, bm)
  let rechts = calc.max(nm.width / 2 - gw / 2, 2.3pt + duenn)
  let oy = 1.05 * bund + 2.35pt + nm.height + 3.67pt  // wie TikZ-Knoten (inner sep)
  let unten = 0.35 * bund + 4pt

  // Punkt (x, y) in Gitterkoordinaten -> Position im Kasten
  let pt(x, y) = (ox + x * saite, oy + y * bund)
  let mitte(x, y, body) = {
    let (px, py) = pt(x, y)
    place(top + left, dx: px, dy: py, box(width: 0pt, height: 0pt, place(center + horizon, body)))
  }
  let strich(x1, y1, x2, y2, s) = place(top + left, line(start: pt(x1, y1), end: pt(x2, y2), stroke: s))

  box(width: ox + gw + rechts, height: oy + 4 * bund + unten, {
    // Name (unten mittig über dem Gitter)
    let (nx, ny) = pt(2.5, -1.05)
    place(top + left, dx: nx - nm.width / 2, dy: ny - nm.height - 2.35pt, name)
    // Saiten
    for i in range(6) { strich(i, 0, i, 4, duenn + c(farbe.linie)) }
    // Sattel bzw. Startbund
    if g.bund == none {
      strich(0, 0, 5, 0, 1pt + c(farbe.text))
    } else {
      strich(0, 0, 5, 0, duenn + c(farbe.linie))
      let (bx, by) = pt(-0.3, 0.5)
      place(top + left, dx: bx - measure(bundtext).width, dy: by - measure(bundtext).height / 2, bundtext)
    }
    for j in range(1, 5) { strich(0, j, 5, j, duenn + c(farbe.linie)) }
    // Marken über dem Sattel
    for (i, m) in g.marken.enumerate() {
      if m == "x" { mitte(i, -0.32, text(size: 7pt, fill: c(farbe.akkord), "×")) }
      if m == "o" { mitte(i, -0.32, circle(radius: 2pt, stroke: duenn + c(farbe.akkord))) }
    }
    // Barré
    if g.barre != none {
      let (b, s1, s2) = g.barre
      strich(s1 - 1, b - 0.42, s2 - 1, b - 0.42,
        (paint: c(farbe.akkord), thickness: 4.2pt, cap: "round"))
    }
    // Punkte + Fingernummern
    for p in g.punkte {
      let s = int(p.at(0))
      let b = int(p.at(1))
      mitte(s - 1, b - 0.5, circle(radius: 2.3pt, fill: c(farbe.akkord)))
      if p.len() > 2 and p.at(2) != "" {
        mitte(s - 1, 4.35, text(size: 6.5pt, fill: c(farbe.text), p.at(2)))
      }
    }
  })
}

// Grifftabelle (wie chords.tex am Ende des Buchs): Zeilen wie in der Datei,
// Griffe gleichmäßig verteilt (\hfill)
#let grifftabelle(zeilen) = for r in zeilen {
  block(width: 100%, above: 4mm, r.map(g => griffbild(g)).join(h(1fr)))
}
