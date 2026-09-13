-- Pandoc Lua filter: turns the plain GitHub-flavored handbook Markdown into
-- styled print output. The Markdown stays clean for GitHub; all print
-- styling decisions live here and in preamble.tex.
--
-- Conventions recognized in the Markdown:
--   * A paragraph that is entirely bold is a cue line   -> hbcue box
--   * ...and if it is written in capitals it is a mantra -> hbmantra banner
--   * "## Every position, every game" section            -> hbpanel box
--   * "# <Role> — Position Card" chapters                -> one-page card grid
--   * Long bullet lists of very short items               -> set in columns
--   * Tables                                               -> ruled tables; empty cells make write-in forms
--   * Repository-only material (document index lists, links to the chat
--     transcript) is omitted from print.

local stringify = pandoc.utils.stringify

local function raw(s) return pandoc.RawBlock('latex', s) end

local function inlines(text)
  return pandoc.read(text, 'markdown').blocks[1].content
end

local function latex_escape(s)
  return (s:gsub('([%%&#_{}$])', '\\%1'))
end

-- A paragraph whose only content is one bold run.
local function sole_strong(para)
  local content = {}
  for _, el in ipairs(para.content) do
    if el.t ~= 'Space' and el.t ~= 'SoftBreak' then table.insert(content, el) end
  end
  if #content == 1 and content[1].t == 'Strong' then return content[1] end
  return nil
end

local function is_mantra(text)
  return text:match('%u') and text == text:upper() and #text > 6
end

-- External links keep their text and gain a footnote with the URL (print
-- readers cannot click). Cross-document links (foo.md, ../foo.md,
-- docs/positions/) become in-PDF anchors created by build.sh.
local function Link(el)
  local target = el.target
  if target:match('^https?://') then
    local text = stringify(el.content)
    if text ~= target and text ~= target:gsub('^https?://', '') then
      return { el, pandoc.Note({ pandoc.Plain({ pandoc.Link({ pandoc.Str(target) }, target) }) }) }
    end
    return el
  end
  if target:match('^%a+:') then return el end
  local base = target:match('([^/]+)%.md')
  if base then
    el.target = '#ch-' .. base
  elseif target:match('positions/?$') then
    el.target = '#part-positions'
  end
  return el
end

-- Tables print as full-width ruled tables. Tables with empty body cells are
-- write-in forms: vertical rules and tall rows. Relative column widths come
-- from the Markdown separator line when pandoc provides them.
local function cell_latex(cell)
  if #cell.contents == 0 then return '' end
  local tex = pandoc.write(pandoc.Pandoc(cell.contents), 'latex')
  tex = tex:gsub('%s+$', ''):gsub('\n\n+', ' \\newline ')
  return tex
end

local function Table(tbl)
  local rows, has_empty = {}, false
  local function collect(list, is_head)
    for _, row in ipairs(list) do
      local cells = {}
      for _, cell in ipairs(row.cells) do
        if not is_head and stringify(cell.contents) == '' then has_empty = true end
        table.insert(cells, cell_latex(cell))
      end
      table.insert(rows, { head = is_head, cells = cells })
    end
  end
  collect(tbl.head.rows, true)
  for _, body in ipairs(tbl.bodies) do collect(body.body, false) end

  local ncols = #tbl.colspecs
  local widths, total = {}, 0
  for i, spec in ipairs(tbl.colspecs) do
    local w = spec[2]
    widths[i] = type(w) == 'number' and w or nil
    total = total + (widths[i] or 0)
  end
  local cols = {}
  for i = 1, ncols do
    local factor = (total > 0 and widths[i]) and (widths[i] / total * ncols) or 1
    table.insert(cols, string.format('>{\\hsize=%.3f\\hsize\\raggedright\\arraybackslash}X', factor))
  end

  local env = has_empty and 'hbform' or 'hbtable'
  local sep = has_empty and '|' or ''
  local tex = { '\\begin{' .. env .. '}{' .. sep .. table.concat(cols, sep) .. sep .. '}' }
  for _, row in ipairs(rows) do
    local cells = {}
    for c, text in ipairs(row.cells) do
      if row.head then
        text = '\\hbtablehead{' .. text .. '}'
      elseif has_empty and c == 1 then
        text = '\\hbformstrut ' .. text
      end
      table.insert(cells, text)
    end
    local line = table.concat(cells, ' & ') .. ' \\\\ \\hline'
    if row.head then line = '\\rowcolor{hbtint}' .. line end
    table.insert(tex, line)
  end
  table.insert(tex, '\\end{' .. env .. '}')
  return raw(table.concat(tex, '\n'))
end

local function Para(el)
  local strong = sole_strong(el)
  if not strong then return nil end
  if stringify(strong):match('^These are principles, not restrictions') then
    local tex = pandoc.write(pandoc.Pandoc({ pandoc.Plain(strong.content) }), 'latex'):gsub('%s+$', '')
    return raw('\\hbfreedom{' .. tex .. '}')
  end
  local env = is_mantra(stringify(strong)) and 'hbmantra' or 'hbcue'
  return {
    raw('\\begin{' .. env .. '}'),
    pandoc.Plain(strong.content),
    raw('\\end{' .. env .. '}'),
  }
end

-- Short-item bullet lists read better in columns.
local function column_count(list)
  local n, longest = #list.content, 0
  if n < 6 then return 0 end
  for _, item in ipairs(list.content) do
    if #item ~= 1 or (item[1].t ~= 'Plain' and item[1].t ~= 'Para') then return 0 end
    longest = math.max(longest, utf8.len(stringify(item[1])) or 99)
  end
  if longest <= 22 and n >= 9 then return 3 end
  if longest <= 34 then return 2 end
  return 0
end

-- Repository-only material is omitted from print: list items that link to
-- the chat transcript, and sections made only of lists of links to other
-- Markdown documents (the README's document index; the PDF has a contents page).
local function links_local_doc(item)
  local first = item[1]
  if not first or (first.t ~= 'Plain' and first.t ~= 'Para') then return false end
  local inl = first.content[1]
  return inl ~= nil and inl.t == 'Link' and not inl.target:match('^%a+:')
    and (inl.target:match('%.md') ~= nil or inl.target:match('/$') ~= nil)
end

local function drop_transcript_items(list)
  local kept = {}
  for _, item in ipairs(list.content) do
    local first = item[1]
    local inl = first and first.content and first.content[1]
    if not (inl and inl.t == 'Link' and inl.target:match('chat%-transcript')) then
      table.insert(kept, item)
    end
  end
  if #kept == 0 then return {} end
  list.content = kept
  return list
end

-- Each document's title is its only H1 (build.sh tags it #ch-<name>). Any
-- other H1 would start a spurious chapter, so it is demoted: a fully bold one
-- becomes a paragraph (and so a cue or mantra), anything else becomes an H2.
local function demote_stray_h1(el)
  if el.level ~= 1 or el.identifier:match('^ch%-') then return nil end
  local strong = sole_strong(pandoc.Para(el.content))
  if strong then return pandoc.Para({ strong }) end
  el.level = 2
  return el
end

local function drop_index_sections(doc)
  local out, i, blocks = {}, 1, doc.blocks
  while i <= #blocks do
    local b = blocks[i]
    if b.t == 'Header' and b.level == 2 then
      local j, only_links = i + 1, true
      while j <= #blocks and not (blocks[j].t == 'Header' and blocks[j].level <= 2) do
        local s = blocks[j]
        if s.t ~= 'BulletList' then only_links = false
        else
          for _, item in ipairs(s.content) do
            if not links_local_doc(item) then only_links = false end
          end
        end
        j = j + 1
      end
      if only_links and j > i + 1 then
        i = j
      else
        table.insert(out, b)
        i = i + 1
      end
    else
      table.insert(out, b)
      i = i + 1
    end
  end
  doc.blocks = out
  return doc
end

---------------------------------------------------------------------------
-- Position cards
---------------------------------------------------------------------------

local CARD_SLOTS = {
  ['my purpose'] = 'purpose',
  ['primary purpose'] = 'purpose',
  ['purpose'] = 'purpose',
  ['pregame mindset'] = 'mindset',
  ['pre-game mindset'] = 'mindset',
  ['mindset'] = 'mindset',
  ['picture these moments'] = 'picture',
  ['when we have it'] = 'have',
  ['when we lose it'] = 'lose',
  ['when they have it'] = 'they',
  ['when we win it'] = 'win',
  ['important relationships'] = 'relations',
  ['players i connect with'] = 'relations',
  ['players i connect with most'] = 'relations',
  ["when you're unsure"] = 'unsure',
  ['when you’re unsure'] = 'unsure',
  ['when you are unsure'] = 'unsure',
  ['my cues'] = 'cues',
  ['cues'] = 'cues',
  -- legacy sections (still rendered if present)
  ['every position, every game'] = 'common',
  ['common traps'] = 'traps',
  ['common mistakes'] = 'traps',
  ['film question'] = 'film',
  ['film questions'] = 'film',
}

local function is_freedom_line(b)
  return b.t == 'RawBlock' and b.text:match('^\\hbfreedom') ~= nil
end

local function build_card(blocks)
  local slots, titles = { intro = {}, footer = {} }, {}
  local current = 'intro'
  for _, b in ipairs(blocks) do
    if is_freedom_line(b) then
      table.insert(slots.footer, b)
    elseif b.t == 'Header' and b.level == 2 then
      local title = stringify(b.content)
      local slot = CARD_SLOTS[title:lower()]
      if slot then
        current = slot
        slots[slot] = slots[slot] or {}
        titles[slot] = title
      else
        table.insert(slots[current], raw('\\hbcellsubhead{' .. latex_escape(title) .. '}'))
      end
    elseif b.t == 'Header' then
      table.insert(slots[current], raw('\\hbcellsubhead{' .. latex_escape(stringify(b.content)) .. '}'))
    else
      table.insert(slots[current], b)
    end
  end

  local out = {}
  local function add(list) for _, b in ipairs(list or {}) do table.insert(out, b) end end
  local function head(slot, default) return latex_escape(titles[slot] or default) end
  local function has(slot) return slots[slot] ~= nil end

  local function panel(slot, default, columns)
    table.insert(out, raw('\\begin{hbpanel}[top=3pt, bottom=3pt, before skip=0pt, after skip=0.5em]{' .. head(slot, default) .. '}'))
    for _, b in ipairs(slots[slot]) do
      if b.t == 'BulletList' and columns then
        table.insert(out, raw('\\begin{hblistcols}{2}\\fontsize{9.6}{11.5}\\selectfont'))
        table.insert(out, b)
        table.insert(out, raw('\\end{hblistcols}'))
      else
        table.insert(out, b)
      end
    end
    table.insert(out, raw('\\end{hbpanel}'))
  end

  -- A row of side-by-side cells: { {width, {{slot, default}, ...}}, ... }
  local function row(cells)
    local present = false
    for _, cell in ipairs(cells) do
      for _, part in ipairs(cell[2]) do if has(part[1]) then present = true end end
    end
    if not present then return end
    for i, cell in ipairs(cells) do
      local open = '\\begin{hbcell}{' .. cell[1] .. '}'
      table.insert(out, raw((i == 1 and '\\hbrowstart' or '\\end{hbcell}\\hfill') .. open))
      for j, part in ipairs(cell[2]) do
        local slot, default = part[1], part[2]
        if has(slot) or j == 1 then
          table.insert(out, raw('\\hbcellhead{' .. head(slot, default) .. '}'))
          add(slots[slot])
        end
      end
    end
    table.insert(out, raw('\\end{hbcell}\\hbrowend'))
  end

  add(slots.intro)
  if has('purpose') then
    table.insert(out, raw('\\begin{hbpurpose}{' .. head('purpose', 'My purpose') .. '}'))
    add(slots.purpose)
    table.insert(out, raw('\\end{hbpurpose}'))
  end
  if has('common') then panel('common', 'Every position, every game', true) end
  row({ { '0.575', { { 'mindset', 'Pregame mindset' } } }, { '0.385', { { 'unsure', "When you're unsure" } } } })
  if has('picture') then panel('picture', 'Picture these moments', true) end
  row({ { '0.475', { { 'have', 'When we have it' } } }, { '0.475', { { 'lose', 'When we lose it' } } } })
  row({ { '0.475', { { 'they', 'When they have it' } } }, { '0.475', { { 'win', 'When we win it' } } } })
  if has('traps') or has('film') then
    row({ { '0.3', { { 'relations', 'Important relationships' } } }, { '0.3', { { 'traps', 'Common traps' } } },
          { '0.3', { { 'cues', 'My cues' }, { 'film', 'Film question' } } } })
  else
    row({ { '0.6', { { 'relations', 'Important relationships' } } }, { '0.355', { { 'cues', 'My cues' } } } })
  end
  add(slots.footer)
  return out
end

---------------------------------------------------------------------------
-- Document pass
---------------------------------------------------------------------------

local function is_structural_raw(b)
  return b.t == 'RawBlock' and (b.text:match('\\hbpart') or b.text:match('\\hbsetlabel'))
end

local function Pandoc(doc)
  local blocks, out = doc.blocks, {}
  local card = nil        -- blocks collected for the current position card
  local in_panel = false

  local function emit(b) table.insert(out, b) end
  local function close_panel()
    if in_panel then emit(raw('\\end{hbpanel}')); in_panel = false end
  end
  local function flush_card()
    if card then
      for _, b in ipairs(build_card(card)) do emit(b) end
      emit(raw('\\clearpage\\hbnormaltitles'))
      card = nil
    end
  end

  -- Long chapters (12+ sections) get an "In this chapter" box after the title.
  local sections_after = {}
  do
    local current = nil
    for i, b in ipairs(blocks) do
      if b.t == 'Header' and b.level == 1 then
        current = i
        sections_after[i] = {}
      elseif current and b.t == 'Header' and b.level == 2 then
        table.insert(sections_after[current], b)
      end
    end
  end
  local function chapter_contents(sections)
    local tex = { '\\begin{hbchaptercontents}' }
    for _, h in ipairs(sections) do
      local text = stringify(h.content)
      local num, title = text:match('^(%d+)%.%s+(.*)$')
      table.insert(tex, string.format('\\hbtocitem{%s}{%s}{%s}',
        h.identifier, num or '', latex_escape(title or text)))
    end
    table.insert(tex, '\\end{hbchaptercontents}')
    return raw(table.concat(tex, '\n'))
  end

  for i, b in ipairs(blocks) do
    if (b.t == 'Header' and b.level == 1) or is_structural_raw(b) then
      close_panel()
      flush_card()
      if b.t == 'Header' then
        local name = stringify(b.content):match('^(.-)%s*[—–-]+%s*Position Card$')
        if name then
          -- "Center Back (#4 / #5)" -> name plus a styled number badge.
          local base, numbers = name:match('^(.-)%s*%((#[^)]+)%)$')
          if base then
            local shown = numbers:gsub('#', '\\#')
            b.content = inlines(base)
            table.insert(b.content, pandoc.RawInline('latex',
              '\\texorpdfstring{\\hbposnum{' .. shown .. '}}{ (' .. numbers:gsub('#', '') .. ')}'))
          else
            b.content = inlines(name)
          end
          emit(raw('\\hbcardtitles'))
          card = {}
        end
      end
      emit(b)
      if b.t == 'Header' and not card and sections_after[i] and #sections_after[i] >= 12 then
        emit(chapter_contents(sections_after[i]))
      end
    elseif card then
      table.insert(card, b)
    elseif b.t == 'Header' and b.level == 2 then
      close_panel()
      if stringify(b.content) == 'Every position, every game' then
        emit(raw('\\begin{hbpanel}{Every position, every game}'))
        in_panel = true
      else
        emit(b)
      end
    elseif b.t == 'BulletList' and not in_panel and column_count(b) > 0 then
      emit(raw('\\begin{hblistcols}{' .. column_count(b) .. '}'))
      emit(b)
      emit(raw('\\end{hblistcols}'))
    else
      emit(b)
    end
  end
  close_panel()
  flush_card()

  doc.blocks = out
  return doc
end

return {
  { BulletList = drop_transcript_items, Header = demote_stray_h1 },
  { Pandoc = drop_index_sections },
  { Link = Link, Table = Table },
  { Para = Para },
  { Pandoc = Pandoc },
}
