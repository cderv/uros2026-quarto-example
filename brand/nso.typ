// House style of the Northbridge Statistical Office (Typst)

// Brand font everywhere, page numbers included (they sit outside the body)
#set text(font: "Source Sans 3")

// Figure and table captions read as headlines
#show figure.caption: set text(font: "Source Serif 4", weight: 600, size: 1.1em, fill: rgb("#7a1f3d"))
#show figure.caption: set align(left)

// Key figure: a stone box with a burgundy rule
#show figure.where(kind: "quarto-float-kf"): it => block(
  width: 100%, fill: rgb("#f6f3ee"), inset: 14pt, radius: 3pt,
  stroke: (left: 5pt + rgb("#7a1f3d")),
  align(left, it),
)

// Title block: the institute's logo, then title, subtitle, authors and date,
// left-aligned across the body and the margin. Quarto's article() still sets
// up the page; it only gets no title block to draw.
#let quarto-article = article
#let article(title: none, subtitle: none, authors: none, date: none, ..args, doc) = {
  // Quarto puts the _brand.yml logo in the page background; drop it
  set page(background: none)
  wideblock(side: "outer", {
    set text(font: "Source Sans 3")
    set par(leading: 0.5em, spacing: 0.6em)
    image("brand/nso-logo.svg", height: 1.1cm,
          alt: "Northbridge Statistical Office")
    line(length: 100%, stroke: 1.5pt + rgb("#7a1f3d"))
    v(0.1cm)
    text(font: "Source Serif 4", weight: 600, size: 2.1em, fill: rgb("#7a1f3d"), title)
    if subtitle != none {
      parbreak()
      text(size: 1.25em, fill: rgb("#5f6368"), subtitle)
    }
    parbreak()
    let who = if authors != none {
      authors.map(a => [#a.name, #a.affiliation]).join([; ])
    }
    text(size: 0.9em, fill: rgb("#5f6368"), (who, date).filter(x => x != none).join[ #sym.dot.c ])
    v(0.5cm)
  })
  quarto-article(..args, {
    set document(title: title)
    doc
  })
}
