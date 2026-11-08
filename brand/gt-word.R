# Word output of gt tables, fixed for Microsoft Word.
#
# gt writes Word tables without a column grid (<w:tblGrid>) and with an
# automatic width, and Quarto puts a captioned table inside a one-cell table.
# Word then squeezes every column to a few characters.
# Known issues: rstudio/gt#1907, quarto-dev/quarto-cli#12022.
#
# This method replaces gt's own for Word only. Each column gets a width from
# its longest label or value, the table is centred, the hairlines gt leaves
# between columns are removed, and the text takes the fonts of the reference
# document instead of Calibri. HTML and PDF go through gt unchanged.
knit_print.gt_tbl <- function(x, ...) {
  if (!identical(knitr::pandoc_to(), "docx")) {
    return(getFromNamespace("knit_print.gt_tbl", "gt")(x, ...))
  }
  xml <- gt::as_word(x)

  # Column widths in twentieths of a point: about 110 per character at 10 pt,
  # plus the cell padding, within the text width of brand/nso-reference.docx
  columns <- names(x[["_data"]])
  labels <- vapply(x[["_boxhead"]]$column_label, as.character, "")
  chars <- vapply(seq_along(columns), function(i) {
    cells <- gt::extract_cells(x, columns = columns[i], output = "plain")
    max(nchar(c(labels[i], cells)))
  }, 1)
  twips <- round(chars * 110 + 240)
  twips <- round(twips * min(1, 9400 / sum(twips)))
  grid <- paste0("<w:tblGrid>",
                 paste0('<w:gridCol w:w="', twips, '"/>', collapse = ""),
                 "</w:tblGrid>")

  # Table properties in the order the Word schema requires, then the grid
  props <- paste0(
    sprintf('<w:tblPr><w:tblW w:type="dxa" w:w="%d"/><w:jc w:val="center"/>', sum(twips)),
    '<w:tblBorders><w:top w:val="nil"/><w:start w:val="nil"/><w:bottom w:val="nil"/>',
    '<w:end w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>',
    '<w:tblLayout w:type="fixed"/><w:tblCellMar>',
    '<w:top w:w="0" w:type="dxa"/><w:start w:w="60" w:type="dxa"/>',
    '<w:bottom w:w="0" w:type="dxa"/><w:end w:w="60" w:type="dxa"/>',
    '</w:tblCellMar><w:tblLook w:val="0000"/></w:tblPr>')
  xml <- sub("<w:tblPr>.*?</w:tblPr>", paste0(props, grid), xml, perl = TRUE)

  # Borders gt writes without a width: none between columns, thin between rows
  xml <- gsub('<w:(start|end) w:val="single" w:space="0" w:color="\\w+"></w:\\1>',
              "", xml, perl = TRUE)
  xml <- gsub('<w:(top|bottom) w:val="single" w:space="0"',
              '<w:\\1 w:val="single" w:sz="4" w:space="0"', xml, perl = TRUE)
  xml <- gsub('<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>', "", xml, fixed = TRUE)

  # Quarto puts the table in a cell, and a Word cell must end with a paragraph
  end <- '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr></w:p>'
  knitr::asis_output(paste("```{=openxml}", xml, end, "```\n\n", sep = "\n"))
}
registerS3method("knit_print", "gt_tbl", knit_print.gt_tbl,
                 envir = asNamespace("knitr"))
