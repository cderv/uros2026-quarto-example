# Tourism in the EU: an example bulletin made with Quarto

Example for the talk **Reproducible Statistical Publications with Quarto** (uRos 2026, Paris,
19 November 2026). Slides: <https://cderv.github.io/uros2026-quarto-intro/>

One source file, `bulletin.qmd`, renders a monthly statistical bulletin to HTML, PDF and Word.
The data are real (Eurostat, `tour_occ_nim`: nights spent at tourist accommodation). The
publisher, the *Northbridge Statistical Office*, is fictional.

Rendered outputs: <https://cderv.github.io/uros2026-quarto-example/>

## What it shows

- **Every number computed.** The key figure, the sentences, the chart titles and the alt text are
  computed by R when the document renders. Nobody types 514.7.
- **One source, every format.** The `format:` list in `_quarto.yml` gives `bulletin.html`,
  `bulletin.pdf` (made with [Typst](https://typst.app), no LaTeX needed) and `bulletin.docx` in
  one `quarto render`.
- **Ready to publish.** Tables with gt, figure and table captions, cross-references
  (`@fig-trend` becomes "Figure 1"), and the institute's look (colours, logo, fonts) written once in
  `_brand.yml`.
- **Accessible PDF, checked.** `pdf-standard: [a-2b, ua-1]` asks for PDF/A (archive) and PDF/UA
  (tagged, for screen readers); with veraPDF installed, Quarto checks both at every render.

The fix from the talk: in `bulletin.qmd`, change `c_resid = "TOTAL"` to `"FOR"` (guests from
abroad only), render, and every output shows the other number. Change it back, render again.

## Render it

You need [Quarto](https://quarto.org/docs/get-started/) (tested with 1.12) and R 4.6.

The R packages are pinned in `rproj.toml` and `rproj.lock`, for
[rig](https://github.com/r-lib/rig)'s project libraries:

```bash
rig proj sync      # installs the packages into .rvenv/
quarto render      # writes _output/bulletin.html, .pdf and .docx
```

Without rig, install the packages listed under `[dependencies]` in `rproj.toml` with
`install.packages()`, then run `quarto render`.

Optional: `quarto install verapdf` to have the PDF checked against PDF/A and PDF/UA at each render.

On Linux, the map needs the system libraries of sf (GDAL, GEOS, PROJ, udunits).
The first render downloads the data from Eurostat and the fonts from Google Fonts.

## Files

| File | Role |
|------|------|
| `bulletin.qmd` | The bulletin: text and R code |
| `_quarto.yml` | Formats (HTML, Typst PDF, Word) and their options |
| `_brand.yml` | The institute's colours, logo and fonts, read by every format |
| `brand/` | Logo, extra HTML styling, Typst page layout |
| `rproj.toml`, `rproj.lock` | R packages (rig project) |

Data: Eurostat, reused under the [Eurostat copyright and licence policy](https://ec.europa.eu/eurostat/about-us/policies/copyright) (CC BY 4.0). Code: MIT, see `LICENSE`.
