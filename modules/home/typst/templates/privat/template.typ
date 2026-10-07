#let privat(
  title: "Notiz / Dokument",
  subtitle: none,
  author: none,
  date: datetime.today().display("[day].[month].[year]"),
  body,
) = {
  // Page layout
  set page(
    paper: "a4",
    margin: (x: 3cm, top: 3cm, bottom: 3cm),
    footer: context [
      #set text(8.5pt, fill: rgb("#94a3b8"))
      #grid(
        columns: (1fr, 1fr),
        align(left)[#title],
        align(right)[Seite #counter(page).display("1 / 1", both: true)]
      )
    ]
  )

  // Typography - Modern Sans-Serif
  set text(
    font: ("Liberation Sans", "DejaVu Sans"),
    size: 10.5pt,
    lang: "de"
  )
  set par(justify: false, leading: 0.8em)
  set heading(numbering: none)

  show heading: it => [
    #v(1em)
    #text(fill: rgb("#0f172a"))[#it]
    #v(0.4em)
  ]

  // Table styling - Minimalist zebra striping
  show table.cell.where(y: 0): set text(weight: "bold", fill: rgb("#0f172a"))
  set table(
    stroke: none,
    fill: (x, y) => if y == 0 { rgb("#f1f5f9") } else if calc.even(y) { rgb("#f8fafc") } else { none },
    inset: (x: 10pt, y: 8pt)
  )

  // Title section
  v(0.5em)
  text(2em, weight: 700, fill: rgb("#0f172a"))[#title]
  if subtitle != none [
    #v(0.3em)
    #text(1.2em, fill: rgb("#64748b"))[#subtitle]
  ]
  v(0.5em)
  text(9.5pt, fill: rgb("#64748b"))[#if author != none [#author #h(1em) · #h(1em)]#date]
  v(1.2em)
  line(length: 100%, stroke: 0.5pt + rgb("#e2e8f0"))
  v(1em)

  body
}

// Helper callout blocks
#let note(title: "Notiz", body) = block(
  fill: rgb("#f8fafc"),
  stroke: (left: 3pt + rgb("#64748b")),
  inset: (x: 12pt, y: 9pt),
  radius: (right: 4pt),
  width: 100%,
)[
  #text(weight: "bold", fill: rgb("#334155"))[#title] \
  #v(0.2em)
  #body
]
