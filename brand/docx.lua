-- Word only: what _brand.yml and the inline styles cannot reach in Word.
-- Styles come from brand/nso-reference.docx. Runs after Quarto (post-render).

-- The big number of a key figure: Key Figure Number style
-- (Word ignores the inline style used by HTML)
function Span(el)
  local style = el.attributes["style"]
  if style and style:find("font%-size") then
    el.attributes["custom-style"] = "Key Figure Number"
    return el
  end
end

-- Key figures: Quarto puts each in a one-cell table. Its paragraphs get the
-- Key Figure style, a stone box with a burgundy bar as in the PDF; the last
-- block, the caption, stays out. Left-aligned, as in the PDF.
function Table(tbl)
  local cell = tbl.bodies[1] and tbl.bodies[1].body[1] and tbl.bodies[1].body[1].cells[1]
  local kf = cell and cell.contents[1]
  if not (kf and kf.t == "Div" and kf.identifier:match("^kf%-")) or #kf.content < 2 then
    return nil
  end
  local body = pandoc.List({ table.unpack(kf.content, 1, #kf.content - 1) })
  kf.content = { pandoc.Div(body, { ["custom-style"] = "Key Figure" }),
                 kf.content[#kf.content] }
  tbl.colspecs[1][1] = pandoc.AlignDefault
  return tbl
end
