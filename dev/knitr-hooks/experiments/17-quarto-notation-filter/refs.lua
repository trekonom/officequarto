-- Spike: turn Quarto citations (@fig-a, [@fig-a], [@fig-a; @tbl-b]) into REF fields for items whose
-- caption bookmark was emitted by oq_numbering(). Two passes over the document:
--   1. collect the bookmark names found in raw openxml inlines (w:bookmarkStart w:name="...")
--   2. replace Cite nodes whose citations are all in that set.
local owned = {}
local log = {}

local function ref_field(id)
  local xml = '<w:hyperlink w:anchor="' .. id .. '">'
    .. '<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>'
    .. '<w:r><w:instrText xml:space="preserve"> REF ' .. id .. ' \\h </w:instrText></w:r>'
    .. '<w:r><w:fldChar w:fldCharType="end" w:dirty="true"/></w:r></w:hyperlink>'
  return pandoc.RawInline('openxml', xml)
end

local function collect(el)
  if el.format == 'openxml' then
    local name = el.text:match('<w:bookmarkStart[^>]-w:name="([^"]+)"')
    if name then owned[name] = true end
  end
end

-- Citations owned by the hook become REF fields; the others stay a (smaller) Cite for Quarto's own
-- crossref filter. A pure-owned or pure-foreign citation list keeps its old behaviour.
local function replace_cite(cite)
  local any_owned = false
  for _, c in ipairs(cite.citations) do
    if owned[c.id] then any_owned = true end
  end
  if not any_owned then return nil end

  local out = pandoc.List()
  local pending = pandoc.List()
  local function sep() if #out > 0 then out:insert(pandoc.Str('; ')) end end
  local function flush()
    if #pending == 0 then return end
    sep()
    local content = pandoc.List()
    for i, c in ipairs(pending) do
      if i > 1 then content:insert(pandoc.Str('; ')) end
      content:insert(pandoc.Str('@' .. c.id))
    end
    out:insert(pandoc.Cite(content, pending))
    pending = pandoc.List()
  end
  for _, c in ipairs(cite.citations) do
    if owned[c.id] then
      flush()
      sep()
      out:extend(c.prefix)
      if #c.prefix > 0 then out:insert(pandoc.Space()) end
      out:insert(ref_field(c.id))
      if #c.suffix > 0 then out:extend(c.suffix) end
    else
      pending:insert(c)
    end
  end
  flush()
  return out
end

function Pandoc(doc)
  if not FORMAT:match('docx') then return nil end
  doc:walk({ RawInline = collect })
  local names = {}
  for k in pairs(owned) do names[#names + 1] = k end
  table.sort(names)
  io.stderr:write('[refs.lua] hook-owned bookmarks: ' .. table.concat(names, ', ') .. '\n')
  return doc:walk({ Cite = replace_cite })
end
