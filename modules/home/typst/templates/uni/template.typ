// ═══════════════════════════════════════════════════════════════════════
//  TU Wien – Vorlage für Übungen & Arbeiten
//
//  Verwendung:
//    #import "uni-template.typ": *
//    #show: uni.with(title: "…", author: "…", subject: "…", semester: "…")
// ═══════════════════════════════════════════════════════════════════════

// ── Farbpalette ────────────────────────────────────────────────────────
// Basis ist das TU-Wien-Blau (#006699). Für ein ruhigeres Gesamtbild wird
// es abgedunkelt und entsättigt; Flächen verwenden nur sehr helle Tints.
#let tuw-blau    = rgb("#006699")  // Referenz: originales TU-Wien-Blau
#let tuw-primary = rgb("#2B5F7C")  // Akzentfarbe (Linien, Labels, Links)
#let tuw-dark    = rgb("#1B3A4B")  // Titel & Überschriften
#let tuw-ink     = rgb("#1F2933")  // Fließtext (weiches Schwarz)
#let tuw-muted   = rgb("#5F6B76")  // Sekundärtext (Kopf-/Fußzeile, Labels)
#let tuw-line    = rgb("#D3DCE3")  // feine Trennlinien
#let tuw-tint    = rgb("#EDF3F6")  // helle Flächen (Tabellenkopf, Info-Box)
#let tuw-wash    = rgb("#F7F9FA")  // fast weiß (Code, Tabellen-Zebra)

// ── Schriften (Fallback-Listen) ────────────────────────────────────────
// Tipp: Wer z. B. "Source Sans 3" oder "Inter" installiert hat, kann sie hier
// an erster Stelle eintragen (Typst warnt bei nicht installierten Schriften).
#let tuw-serif = ("Libertinus Serif",)
#let tuw-sans  = ("Liberation Sans", "DejaVu Sans")
#let tuw-mono  = ("DejaVu Sans Mono",)

// ═══════════════════════════════════════════════════════════════════════
//  Hauptvorlage
// ═══════════════════════════════════════════════════════════════════════
#let uni(
  title: "Titel der Übung / Arbeit",
  subtitle: none,
  author: none,
  subject: none,
  semester: none,
  date: datetime.today().display("[day].[month].[year]"),
  matrikel: none,   // optional: Matrikelnummer
  lecturer: none,   // optional: Lehrveranstaltungsleitung
  logo: none,       // optional: z. B. image("tuwien.svg", height: 1.1cm)
  toc: false,       // true = Inhaltsverzeichnis nach dem Titelblock
  body,
) = {
  // ── PDF-Metadaten ────────────────────────────────────────────────────
  set document(
    title: if type(title) == str { title } else { none },
    author: if type(author) == str { author } else { () },
  )

  // ── Seite, Kopf- & Fußzeile ──────────────────────────────────────────
  set page(
    paper: "a4",
    margin: (x: 2.5cm, top: 3cm, bottom: 2.8cm),
    // dezenter Farbstreifen am oberen Seitenrand
    background: place(top, rect(width: 100%, height: 4pt, fill: tuw-primary, stroke: none)),
    header: context {
      if counter(page).get().first() > 1 {
        set text(8.5pt, fill: tuw-muted, font: tuw-sans)
        block(
          width: 100%,
          inset: (bottom: 6pt),
          stroke: (bottom: 0.5pt + tuw-line),
          grid(
            columns: (1fr, auto),
            align: (left, right),
            [#if subject != none [#subject#h(0.5em)·#h(0.5em)]#title],
            [#if author != none [#author]],
          ),
        )
      }
    },
    footer: context {
      set text(8.5pt, fill: tuw-muted, font: tuw-sans)
      block(
        width: 100%,
        inset: (top: 6pt),
        stroke: (top: 0.5pt + tuw-line),
        grid(
          columns: (1fr, auto),
          align: (left, right),
          [#if semester != none [#semester#h(0.5em)·#h(0.5em)]#date],
          [Seite #counter(page).display() von #counter(page).final().first()],
        ),
      )
    },
  )

  // ── Typografie ───────────────────────────────────────────────────────
  set text(font: tuw-serif, size: 11pt, lang: "de", region: "AT", fill: tuw-ink)
  set par(justify: true, leading: 0.7em, spacing: 1em)

  // ── Überschriften ────────────────────────────────────────────────────
  set heading(numbering: "1.1")
  show heading: set text(font: tuw-sans, weight: "semibold", fill: tuw-dark)
  show heading: set par(justify: false)
  show heading: set block(above: 1.6em, below: 0.8em)
  show heading.where(level: 1): set text(size: 15pt)
  show heading.where(level: 2): set text(size: 12.5pt, fill: tuw-primary)
  show heading.where(level: 3): set text(size: 11pt)
  show heading.where(level: 1): it => block(
    width: 100%,
    above: 2em,
    below: 1em,
    inset: (bottom: 6pt),
    stroke: (bottom: 0.6pt + tuw-line),
    it,
  )

  // ── Listen & Links ───────────────────────────────────────────────────
  set list(indent: 0.6em, body-indent: 0.7em, marker: (
    text(fill: tuw-primary)[•],
    text(fill: tuw-primary)[–],
  ))
  set enum(indent: 0.6em, body-indent: 0.7em, numbering: n => text(fill: tuw-primary)[#n.])
  show link: set text(fill: tuw-primary)
  show ref: set text(fill: tuw-primary)

  // ── Zitate ───────────────────────────────────────────────────────────
  show quote.where(block: true): it => block(
    width: 100%,
    inset: (left: 14pt, y: 4pt),
    stroke: (left: 2pt + tuw-line),
    text(style: "italic", fill: tuw-muted, it.body),
  )

  // ── Tabellen (Booktabs-Stil: nur horizontale Linien) ─────────────────
  set table(
    inset: (x: 9pt, y: 6pt),
    stroke: (x, y) => (
      top: if y == 0 { 0.9pt + tuw-primary } else if y == 1 { 0.6pt + tuw-primary } else { 0.4pt + tuw-line },
    ),
    fill: (x, y) => if y == 0 { tuw-tint } else if calc.even(y) { tuw-wash } else { none },
  )
  show table: set text(size: 10pt)
  show table.cell.where(y: 0): set text(weight: "semibold", fill: tuw-dark)
  show table: it => block(stroke: (bottom: 0.9pt + tuw-primary), it)

  // ── Abbildungen & Beschriftungen ─────────────────────────────────────
  show figure.where(kind: table): set figure.caption(position: top)
  show figure: set block(above: 1.4em, below: 1.4em)
  show figure.caption: set text(size: 9.5pt, fill: tuw-muted)
  show figure.caption: it => context {
    let num = if it.numbering != none { it.counter.display(it.numbering) }
    text(font: tuw-sans, weight: "semibold", fill: tuw-primary)[#it.supplement #num#it.separator]
    it.body
  }

  // ── Code ─────────────────────────────────────────────────────────────
  show raw: set text(font: tuw-mono, size: 9pt)
  show raw.where(block: true): it => block(
    fill: tuw-wash,
    stroke: 0.5pt + tuw-line,
    inset: 10pt,
    radius: 3pt,
    width: 100%,
    it,
  )
  show raw.where(block: false): it => box(
    fill: tuw-tint,
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
    it,
  )

  // ── Inhaltsverzeichnis (optional) ────────────────────────────────────
  show outline.entry.where(level: 1): set text(weight: "semibold")
  show outline.entry.where(level: 1): set block(above: 0.9em)

  // ═════════════════════════════════════════════════════════════════════
  //  Titelblock (erste Seite)
  // ═════════════════════════════════════════════════════════════════════
  {
    set par(justify: false)

    // Zeile 1: Lehrveranstaltung (Label) + optionales Logo
    grid(
      columns: (1fr, auto),
      align: (left + horizon, right + horizon),
      if subject != none {
        text(font: tuw-sans, size: 9pt, weight: "semibold", tracking: 0.14em, fill: tuw-primary, upper(subject))
      },
      if logo != none { logo },
    )

    // Titel & Untertitel
    v(1.2em)
    par(leading: 0.45em, text(font: tuw-sans, size: 26pt, weight: "bold", fill: tuw-dark)[#title])
    if subtitle != none {
      v(0.5em)
      text(font: tuw-sans, size: 13.5pt, fill: tuw-muted)[#subtitle]
    }

    // Metadaten-Leiste
    let meta = (
      ("Autor", author),
      ("Matrikelnr.", matrikel),
      ("Lehrende", lecturer),
      ("Semester", semester),
      ("Datum", date),
    ).filter(m => m.at(1) != none)

    if meta.len() > 0 {
      v(1.6em)
      block(
        width: 100%,
        inset: (y: 10pt),
        stroke: (top: 1pt + tuw-primary, bottom: 0.5pt + tuw-line),
        grid(
          columns: meta.map(m => if m.at(0) == "Autor" { 1.6fr } else { 1fr }),
          column-gutter: 14pt,
          ..meta.map(m => stack(
            spacing: 5pt,
            text(font: tuw-sans, size: 7.5pt, weight: "semibold", tracking: 0.1em, fill: tuw-muted, upper(m.at(0))),
            text(font: tuw-sans, size: 10pt, fill: tuw-ink)[#m.at(1)],
          )),
        ),
      )
    }

    if toc {
      v(1.2em)
      outline(title: "Inhaltsverzeichnis", depth: 2)
    }
    v(1.4em)
  }

  body
}

// ═══════════════════════════════════════════════════════════════════════
//  Hilfsblöcke
// ═══════════════════════════════════════════════════════════════════════

// Allgemeiner Hinweiskasten – Basis für info-box & warning-box
#let callout(title, body, accent: tuw-primary, fill: tuw-tint, title-color: tuw-primary) = block(
  width: 100%,
  above: 1.3em,
  below: 1.3em,
  fill: fill,
  stroke: (left: 2.5pt + accent),
  inset: (x: 14pt, y: 11pt),
  radius: (right: 3pt),
  {
    set par(justify: false)
    text(font: tuw-sans, size: 8.5pt, weight: "semibold", tracking: 0.1em, fill: title-color, upper(title))
    v(0.4em)
    body
  },
)

#let info-box(title: "Hinweis", body) = callout(title, body)

#let warning-box(title: "Achtung", body) = callout(
  title,
  body,
  accent: rgb("#C49A3A"),
  fill: rgb("#FAF5E8"),
  title-color: rgb("#8A6A1F"),
)

// Aufgaben-Kopf mit optionaler Punkteangabe
#let task(nr, points: none, body) = {
  block(
    width: 100%,
    above: 2em,
    below: 1em,
    inset: (bottom: 6pt),
    stroke: (bottom: 0.6pt + tuw-line),
    sticky: true,
    grid(
      columns: (1fr, auto),
      align: (left + horizon, right + horizon),
      text(font: tuw-sans, size: 13pt, weight: "semibold", fill: tuw-primary)[Aufgabe #nr],
      if points != none {
        box(
          fill: tuw-tint,
          inset: (x: 8pt, y: 3.5pt),
          radius: 10pt,
          text(font: tuw-sans, size: 8.5pt, weight: "semibold", fill: tuw-primary)[#points P.],
        )
      },
    ),
  )
  body
}
