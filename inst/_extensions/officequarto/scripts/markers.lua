-- markers.lua - officedown's comment markers for Quarto docx output.
-- Contributed by the officequarto extension (see _extension.yml); active for
-- every docx render of an `officequarto` project, no per-document setup.
--
--   <!---BLOCK_TOC--->                  table of contents (live TOC field, levels 1-3)
--   <!---BLOCK_PAGEBREAK--->            page break
--   <!---BLOCK_LANDSCAPE_START--->      end of the portrait section before it
--   <!---BLOCK_LANDSCAPE_STOP--->       end of the landscape section (A4 landscape)
--   <!---BLOCK_LANDSCAPE_STOP {"w":15840,"h":12240}--->   same, custom size in twips
--
-- Each marker must sit on its own line (Pandoc then parses it as an HTML
-- comment RawBlock). Unknown BLOCK_* names are left alone (they stay inert
-- HTML comments, which Pandoc drops for docx).
local function ooxml(s) return pandoc.RawBlock('openxml', s) end

local toc = '<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>'
  .. '<w:r><w:instrText xml:space="preserve"> TOC \\o "1-3" \\h \\z \\u </w:instrText></w:r>'
  .. '<w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>'
local pagebreak = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'

-- A section break is a paragraph whose pPr carries the sectPr describing the
-- section that ENDS there.
local function section_end(w, h, orient)
  return string.format(
    '<w:p><w:pPr><w:sectPr><w:pgSz w:w="%d" w:h="%d"%s/></w:sectPr></w:pPr></w:p>',
    w, h, orient and (' w:orient="' .. orient .. '"') or '')
end

function RawBlock(el)
  if el.format ~= 'html' or not FORMAT:match('docx') then return nil end
  local inner = el.text:match('^<!%-%-%-?(.-)%-%->%s*$')
  if not inner then return nil end
  local name = inner:match('^%s*(BLOCK_[A-Z_]+)')
  if not name then return nil end

  local w, h = 16838, 11906            -- A4 landscape
  local args = inner:match('%b{}')
  if args then
    w = tonumber(args:match('"w"%s*:%s*(%d+)')) or w
    h = tonumber(args:match('"h"%s*:%s*(%d+)')) or h
  end

  if name == 'BLOCK_TOC' then return ooxml(toc)
  elseif name == 'BLOCK_PAGEBREAK' then return ooxml(pagebreak)
  elseif name == 'BLOCK_LANDSCAPE_START' then return ooxml(section_end(11906, 16838))
  elseif name == 'BLOCK_LANDSCAPE_STOP' then return ooxml(section_end(w, h, 'landscape'))
  end
end
