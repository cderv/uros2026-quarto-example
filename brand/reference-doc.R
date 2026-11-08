# Word reference document of the Northbridge Statistical Office.
#
# _brand.yml styles the HTML and the Typst PDF, but it does not reach Word:
# Word takes its styles from a reference document. This script builds one from
# _brand.yml, starting from Pandoc's default reference.docx:
#   - theme fonts and colours: Source Sans 3 for text, Source Serif 4 for headings;
#   - styles: title block, headings, captions, links, tables;
#   - A4 page, the logo in the first-page header, page numbers in the footer.
#
# Run from example/ after changing _brand.yml or this file (just reference-doc):
#   Rscript brand/reference-doc.R
# It writes brand/nso-reference.docx and brand/nso-logo.png (Word needs a PNG).
library(brand.yml)
library(xml2)

brand <- read_brand_yml("_brand.yml")
hex <- function(name) toupper(sub("#", "", brand_color_pluck(brand, name)))
burgundy <- hex("primary")
gold <- hex("gold")
slate <- hex("secondary")
ink <- hex("foreground")
stone <- hex("light")
body_font <- brand$typography$base$family
heading_font <- brand$typography$headings$family
mono_font <- brand$typography$monospace$family

out <- file.path("brand", "nso-reference.docx")
logo_png <- file.path("brand", "nso-logo.png")

# Logo -------------------------------------------------------------------------
# The SVG logo, drawn by Chrome with the brand fonts from ./fonts (downloaded
# by the bulletin's setup chunk), at three times its size for sharpness
logo_svg <- brand$logo$images$full$path
font_face <- function(family, weight) {
  file <- normalizePath(file.path("fonts", paste0(family, "-", weight, ".ttf")))
  sprintf("@font-face {font-family: '%s'; font-weight: %d; src: url('file://%s');}",
          family, weight, file)
}
page <- tempfile(fileext = ".html")
writeLines(c(
  "<html><head><style>",
  font_face(heading_font, 700), font_face(body_font, 600),
  "body {margin: 0;} svg {display: block;}",
  # The SVG names its fonts without quotes, which CSS reads as invalid
  sprintf("text[font-family^='Source Serif'] {font-family: '%s';}", heading_font),
  sprintf("text[font-family^='Source Sans'] {font-family: '%s';}", body_font),
  "</style></head><body>",
  readLines(logo_svg),
  "</body></html>"), page)
if (.Platform$OS.type == "unix" && Sys.info()[["user"]] == "root") {
  chromote::set_chrome_args(c(chromote::default_chrome_args(), "--no-sandbox"))
}
webshot2::webshot(page, logo_png, selector = "svg", zoom = 3, expand = 0, delay = 0.5)

# Default reference document -----------------------------------------------------
dir <- tempfile("reference-")
dir.create(dir)
default <- file.path(dir, "default.docx")
quarto <- Sys.getenv("QUARTO_PATH", Sys.which("quarto"))
system2(quarto, c("pandoc", "-o", shQuote(default),
                  "--print-default-data-file", "reference.docx"))
src <- file.path(dir, "docx")
unzip(default, exdir = src)
part <- function(...) file.path(src, ...)

w_ns <- "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
ns <- c(w = w_ns,
        a = "http://schemas.openxmlformats.org/drawingml/2006/main")
# An XML fragment in the w: namespace
fragment <- function(x) {
  read_xml(sub("^<w:(\\w+)", sprintf('<w:\\1 xmlns:w="%s"', w_ns), x))
}

# Theme: fonts and accent colour -------------------------------------------------
theme <- read_xml(part("word", "theme", "theme1.xml"))
xml_set_attr(xml_find_first(theme, "//a:majorFont/a:latin", ns), "typeface", heading_font)
xml_set_attr(xml_find_first(theme, "//a:minorFont/a:latin", ns), "typeface", body_font)
xml_set_attr(xml_find_first(theme, "//a:accent1/a:srgbClr", ns), "val", burgundy)
xml_set_attr(xml_find_first(theme, "//a:hlink/a:srgbClr", ns), "val", burgundy)
write_xml(theme, part("word", "theme", "theme1.xml"))

# Styles -------------------------------------------------------------------------
styles <- read_xml(part("word", "styles.xml"))
style_node <- function(id) {
  xml_find_first(styles, sprintf("//w:style[@w:styleId='%s']", id), ns)
}
# Replace the paragraph (pPr) and run (rPr) properties of a style
set_style <- function(id, ppr = "", rpr = "") {
  node <- style_node(id)
  xml_remove(xml_find_all(node, "w:pPr | w:rPr", ns))
  if (nzchar(ppr)) xml_add_child(node, fragment(paste0("<w:pPr>", ppr, "</w:pPr>")))
  if (nzchar(rpr)) xml_add_child(node, fragment(paste0("<w:rPr>", rpr, "</w:rPr>")))
}
fonts <- function(family) {
  sprintf('<w:rFonts w:ascii="%1$s" w:hAnsi="%1$s" w:eastAsia="%1$s" w:cs="%1$s"/>', family)
}
colour <- function(x) sprintf('<w:color w:val="%s"/>', x)
size <- function(pt) sprintf('<w:sz w:val="%1$d"/><w:szCs w:val="%1$d"/>', as.integer(pt * 2))
spacing <- function(before = 0, after = 0, line = NULL) {
  sprintf('<w:spacing w:before="%d" w:after="%d"%s/>', before, after,
          if (is.null(line)) "" else sprintf(' w:line="%d" w:lineRule="auto"', line))
}
rule <- function(side, colour, eighths = 12, space = 4) {
  sprintf('<w:pBdr><w:%s w:val="single" w:sz="%d" w:space="%d" w:color="%s"/></w:pBdr>',
          side, eighths, space, colour)
}

# Text: Source Sans 3, 11 pt, line height 1.15
defaults <- xml_find_first(styles, "//w:docDefaults/w:rPrDefault/w:rPr", ns)
xml_remove(xml_find_all(defaults, "w:rFonts | w:sz | w:szCs", ns))
xml_add_child(defaults, fragment(fonts(body_font)), .where = 0)
xml_add_child(defaults, fragment(sub("<w:szCs.*", "", size(11))), .where = 1)
xml_add_child(defaults, fragment(sub(".*(<w:szCs)", "\\1", size(11))), .where = 2)
set_style("Normal", rpr = colour(ink))
set_style("BodyText", spacing(0, 140, 276))
set_style("FirstParagraph", spacing(0, 140, 276))
set_style("Compact", spacing(0, 40))

# Title block, left-aligned, as in the HTML and the PDF. Subtitle, author and
# date are based on Title: they go back to the text font, not bold
plain <- paste0(fonts(body_font), '<w:b w:val="0"/>')
set_style("Title", paste0(spacing(240, 60), '<w:jc w:val="left"/>'),
          paste0(fonts(heading_font), "<w:b/>", colour(burgundy), size(26)))
set_style("Subtitle", paste0(spacing(0, 120), '<w:jc w:val="left"/>'),
          paste0(plain, colour(slate), size(14)))
set_style("Author", paste0('<w:keepNext/>', spacing(0, 0), '<w:jc w:val="left"/>'),
          paste0(plain, colour(slate), size(10)))
set_style("Date", paste0(rule("bottom", gold, 12, 8), spacing(0, 360), '<w:jc w:val="left"/>'),
          paste0(plain, colour(slate), size(10)))

# Headings: Source Serif 4, burgundy
heading <- function(level, pt, before, after) {
  set_style(paste0("Heading", level),
            paste0("<w:keepNext/><w:keepLines/>", spacing(before, after),
                   sprintf('<w:outlineLvl w:val="%d"/>', level - 1)),
            paste0(fonts(heading_font), "<w:b/>", colour(burgundy), size(pt)))
}
heading(1, 20, 480, 160)
heading(2, 16, 360, 120)
heading(3, 13, 280, 80)
heading(4, 11.5, 240, 60)

# Captions read as headlines, as in the PDF. No "keep with next": Quarto puts
# the caption and its figure in one table cell, and Word would then keep the
# whole table with the paragraph after it
for (id in c("Caption", "ImageCaption", "TableCaption")) {
  set_style(id, spacing(160, 100),
            paste0(fonts(heading_font), "<w:b/>", colour(burgundy), size(11.5)))
}

# Links and cross-references: burgundy, not underlined
set_style("Hyperlink", rpr = colour(burgundy))
set_style("VerbatimChar", rpr = paste0(fonts(mono_font), size(10)))
set_style("BlockText", paste0(rule("left", burgundy, 24, 8), spacing(100, 100)),
          colour(ink))

# Tables made by Pandoc: a burgundy rule under the header row
first_row <- xml_find_first(style_node("Table"), "w:tblStylePr[@w:type='firstRow']//w:bottom", ns)
xml_set_attrs(first_row, c("w:val" = "single", "w:sz" = "8", "w:space" = "0",
                           "w:color" = burgundy))

# Key figure (set by brand/docx.lua): a stone box with a burgundy bar, and its
# big number
xml_add_child(styles, fragment(paste0(
  '<w:style w:type="paragraph" w:customStyle="1" w:styleId="KeyFigure">',
  '<w:name w:val="Key Figure"/><w:basedOn w:val="BodyText"/><w:pPr>',
  sprintf('<w:pBdr><w:top w:val="single" w:sz="4" w:space="8" w:color="%1$s"/>', stone),
  sprintf('<w:left w:val="single" w:sz="36" w:space="10" w:color="%s"/>', burgundy),
  sprintf('<w:bottom w:val="single" w:sz="4" w:space="8" w:color="%1$s"/>', stone),
  sprintf('<w:right w:val="single" w:sz="4" w:space="10" w:color="%1$s"/></w:pBdr>', stone),
  sprintf('<w:shd w:val="clear" w:color="auto" w:fill="%s"/>', stone),
  spacing(0, 0, 276), '<w:ind w:left="240" w:right="240"/><w:jc w:val="left"/>',
  "</w:pPr></w:style>")))

xml_add_child(styles, fragment(paste0(
  '<w:style w:type="character" w:customStyle="1" w:styleId="KeyFigureNumber">',
  '<w:name w:val="Key Figure Number"/><w:basedOn w:val="DefaultParagraphFont"/>',
  "<w:rPr>", "<w:b/>", colour(burgundy), size(28), "</w:rPr></w:style>")))
write_xml(styles, part("word", "styles.xml"))

# Header and footer --------------------------------------------------------------
# First page: the logo over a burgundy rule. Other pages: the institute's name.
# Every page: the page number on the right.
page_width <- 11906   # A4, in twentieths of a point
margin <- 1134        # 2 cm
text_width <- page_width - 2 * margin
logo_dim <- dim(png::readPNG(logo_png))
logo_cm <- c(h = 1.1, w = 1.1 * logo_dim[2] / logo_dim[1])
emu <- function(cm) round(cm * 360000)

wrap_part <- function(tag, body) {
  paste0('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n',
         sprintf('<w:%s xmlns:w="%s" ', tag, w_ns),
         'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ',
         'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" ',
         'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" ',
         'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
         body, sprintf("</w:%s>", tag))
}
logo_run <- paste0(
  "<w:r><w:drawing><wp:inline>",
  sprintf('<wp:extent cx="%d" cy="%d"/>', emu(logo_cm[["w"]]), emu(logo_cm[["h"]])),
  sprintf('<wp:docPr id="1" name="Logo" descr="%s"/>', brand$logo$images$full$alt),
  '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">',
  '<pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="nso-logo.png"/><pic:cNvPicPr/></pic:nvPicPr>',
  '<pic:blipFill><a:blip r:embed="rIdLogo"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>',
  '<pic:spPr><a:xfrm><a:off x="0" y="0"/>',
  sprintf('<a:ext cx="%d" cy="%d"/>', emu(logo_cm[["w"]]), emu(logo_cm[["h"]])),
  '</a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>',
  "</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>")
small <- function(text, colour_hex = slate, caps = FALSE) {
  sprintf('<w:r><w:rPr>%s%s%s%s</w:rPr><w:t xml:space="preserve">%s</w:t></w:r>',
          if (caps) "<w:caps/>" else "", colour(colour_hex),
          if (caps) '<w:spacing w:val="20"/>' else "", size(8.5), text)
}
header_first <- wrap_part("hdr", paste0(
  "<w:p><w:pPr>", rule("bottom", burgundy, 12, 6), spacing(0, 0), "</w:pPr>",
  logo_run, "</w:p>"))
header_other <- wrap_part("hdr", paste0(
  "<w:p><w:pPr>", rule("bottom", slate, 4, 4), spacing(0, 0), "</w:pPr>",
  small(brand$meta$name$full, caps = TRUE), "</w:p>"))
footer <- wrap_part("ftr", paste0(
  "<w:p><w:pPr>",
  sprintf('<w:tabs><w:tab w:val="right" w:pos="%d"/></w:tabs>', text_width),
  spacing(0, 0), "</w:pPr>", small(brand$meta$name$full), "<w:r><w:tab/></w:r>",
  '<w:fldSimple w:instr="PAGE">', small("1"), "</w:fldSimple></w:p>"))
writeLines(header_first, part("word", "header1.xml"))
writeLines(header_other, part("word", "header2.xml"))
# One footer part per reference: Word and LibreOffice expect them distinct
writeLines(footer, part("word", "footer1.xml"))
writeLines(footer, part("word", "footer2.xml"))
dir.create(part("word", "media"), showWarnings = FALSE)
invisible(file.copy(logo_png, part("word", "media", "nso-logo.png")))
writeLines(paste0(
  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n',
  '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  '<Relationship Id="rIdLogo" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/nso-logo.png"/>',
  "</Relationships>"), part("word", "_rels", "header1.xml.rels"))

# Declare the new parts
rels <- read_xml(part("word", "_rels", "document.xml.rels"))
rel_type <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
for (r in list(c("rIdHeaderFirst", "header", "header1.xml"),
               c("rIdHeaderOther", "header", "header2.xml"),
               c("rIdFooterFirst", "footer", "footer1.xml"),
               c("rIdFooterOther", "footer", "footer2.xml"))) {
  xml_add_child(rels, "Relationship", Id = r[1], Type = paste0(rel_type, r[2]), Target = r[3])
}
write_xml(rels, part("word", "_rels", "document.xml.rels"))

types <- read_xml(part("[Content_Types].xml"))
ct <- "application/vnd.openxmlformats-officedocument.wordprocessingml."
if (is.na(xml_find_first(types, "//*[@Extension='png']"))) {
  xml_add_child(types, "Default", Extension = "png", ContentType = "image/png", .where = 0)
}
xml_add_child(types, "Override", PartName = "/word/header1.xml", ContentType = paste0(ct, "header+xml"))
xml_add_child(types, "Override", PartName = "/word/header2.xml", ContentType = paste0(ct, "header+xml"))
xml_add_child(types, "Override", PartName = "/word/footer1.xml", ContentType = paste0(ct, "footer+xml"))
xml_add_child(types, "Override", PartName = "/word/footer2.xml", ContentType = paste0(ct, "footer+xml"))
write_xml(types, part("[Content_Types].xml"))

# Page: A4, 2 cm margins, a different first page; Pandoc copies this section
document <- read_xml(part("word", "document.xml"))
sect <- xml_find_first(document, "//w:body/w:sectPr", ns)
xml_remove(xml_children(sect))
for (x in c(
  '<w:headerReference w:type="default" r:id="rIdHeaderOther"/>',
  '<w:headerReference w:type="first" r:id="rIdHeaderFirst"/>',
  '<w:footerReference w:type="default" r:id="rIdFooterOther"/>',
  '<w:footerReference w:type="first" r:id="rIdFooterFirst"/>',
  '<w:footnotePr><w:numRestart w:val="eachSect"/></w:footnotePr>',
  sprintf('<w:pgSz w:w="%d" w:h="16838"/>', page_width),
  sprintf('<w:pgMar w:top="%1$d" w:right="%1$d" w:bottom="%1$d" w:left="%1$d" w:header="567" w:footer="567" w:gutter="0"/>', margin),
  "<w:titlePg/>")) {
  xml_add_child(sect, read_xml(sub(
    "^<w:(\\w+)",
    sprintf('<w:\\1 xmlns:w="%s" xmlns:r="%s"', w_ns,
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships"), x)))
}
write_xml(document, part("word", "document.xml"))

# Zip, with [Content_Types].xml first as Word expects
files <- list.files(src, recursive = TRUE, all.files = TRUE)
files <- c("[Content_Types].xml", setdiff(files, "[Content_Types].xml"))
unlink(out)
zip::zip(file.path(normalizePath(dirname(out)), basename(out)), files, root = src)
message("Wrote ", out, " and ", logo_png)
