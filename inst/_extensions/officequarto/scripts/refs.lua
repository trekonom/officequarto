-- refs.lua - Quarto notation (@fig-a, [@fig-a], [@fig-a; @tbl-b], [see @fig-a, p. 3]) for figures
-- and tables numbered by oq_numbering() (R/numbering-hook.R).
--
-- oq_numbering() removes the fig-/tbl- id Quarto would use, so Quarto's own crossref filter cannot
-- resolve those references. The hook leaves a bookmark named like the Quarto label around
-- "Figure 1" in every caption it builds; this filter finds those bookmarks and replaces the
-- matching citations with a REF field to them (what oq_ref() inserts by hand). It must run before
-- Quarto's crossref filter, which is the default position of filters contributed by an extension.
--
-- Two passes over the document:
--   1. collect the bookmark names found in raw openxml inlines (w:bookmarkStart w:name="...")
--   2. replace citations whose id is in that set. Citations Quarto owns (native figures/tables,
--      citations to literature, unknown ids) are left untouched, also inside a mixed citation
--      like [@fig-hook; @fig-native], so Quarto and officequarto.crossref.auto-number still handle them.
-- Without any hook bookmark in the document the filter does nothing.
local owned = {}

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

local function replace_cite(cite)
  local any_owned = false
  for _, c in ipairs(cite.citations) do
    if owned[c.id] then any_owned = true end
  end
  if not any_owned then return nil end

  local out = pandoc.List()
  local pending = pandoc.List()   -- consecutive citations Quarto should still resolve
  local function sep()
    if #out > 0 then out:insert(pandoc.Str('; ')) end
  end
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
  if next(owned) == nil then return nil end
  return doc:walk({ Cite = replace_cite })
end
