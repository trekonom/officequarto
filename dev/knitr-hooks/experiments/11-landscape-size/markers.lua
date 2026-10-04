-- Prototype Lua filter: revive officedown's comment markers for docx.
-- <!---BLOCK_TOC--->  <!---BLOCK_PAGEBREAK--->
-- <!---BLOCK_LANDSCAPE_START--->  <!---BLOCK_LANDSCAPE_STOP--->
-- Optional size override (twips) for the landscape section: <!---BLOCK_LANDSCAPE_STOP {"w":15840,"h":12240}--->
local function ooxml(s) return pandoc.RawBlock('openxml', s) end

local toc = [[<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \o "1-3" \h \z \u </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>]]
local pagebreak = [[<w:p><w:r><w:br w:type="page"/></w:r></w:p>]]

local function sect(w, h, orient)
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
  local args = inner:match('%b{}')
  local w, h = 16838, 11906            -- A4 landscape default
  if args and args ~= '' then
    w = tonumber(args:match('"w"%s*:%s*(%d+)')) or w
    h = tonumber(args:match('"h"%s*:%s*(%d+)')) or h
  end
  if name == 'BLOCK_TOC' then return ooxml(toc)
  elseif name == 'BLOCK_PAGEBREAK' then return ooxml(pagebreak)
  elseif name == 'BLOCK_LANDSCAPE_START' then return ooxml(sect(11906, 16838))   -- ends the portrait section
  elseif name == 'BLOCK_LANDSCAPE_STOP' then return ooxml(sect(w, h, 'landscape')) -- ends the landscape section
  end
end
