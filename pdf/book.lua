-- Assemble chapter files, keep identifiers unique and resolve book cross-references.
-- Add printed chapter numbers without changing Markdown titles or link identifiers.
local function normal_path(path)
  local pieces = {}
  for part in path:gmatch('[^/]+') do
    if part == '..' then
      table.remove(pieces)
    elseif part ~= '.' then
      table.insert(pieces, part)
    end
  end
  return table.concat(pieces, '/')
end

local function directory(path)
  return path:match('^(.*)/[^/]+$') or '.'
end

local function title_prefix(path)
  local name = path:match('[^/]+$') or path
  local chapter_number = name:match('^en_(%d%d)_') or name:match('^(%d%d)_')
  if chapter_number and tonumber(chapter_number) > 0 then
    return tostring(tonumber(chapter_number)) .. '. '
  end
  local appendix_number = name:match('^fr_annex(%d+)') or name:match('^en_annex(%d+)')
  if appendix_number then
    local label = name:match('^en_') and 'Appendix ' or 'Annexe '
    return label .. tostring(tonumber(appendix_number)) .. '. '
  end
end

function Pandoc(doc)
  local chapters, identifiers, first_ids = {}, {}, {}
  for index, filename in ipairs(PANDOC_STATE.input_files) do
    local file = assert(io.open(filename, 'r'), 'Cannot open chapter: ' .. filename)
    local content = file:read('*a')
    file:close()
    local chapter = pandoc.read(content, 'markdown')
    local canonical = normal_path(filename)
    local prefix = string.format('book-%02d-', index)
    identifiers[canonical] = {}
    chapter = chapter:walk({
      Header = function(header)
        local old_id = header.identifier
        header.identifier = prefix .. old_id
        identifiers[canonical][old_id] = header.identifier
        if header.level == 1 and not first_ids[canonical] then
          first_ids[canonical] = header.identifier
          local prefix_text = title_prefix(filename)
          if prefix_text then
            header.content:insert(1, pandoc.Str(prefix_text))
          end
        end
        return header
      end
    })
    table.insert(chapters, {path = canonical, document = chapter})
  end

  local blocks = pandoc.List()
  for _, entry in ipairs(chapters) do
    local french_philosophy = entry.path:match('/philosophie_de_jedi%.md$')
    local english_philosophy = entry.path:match('/en_philosophy_of_jedi%.md$')
    local chapter = entry.document:walk({
      Header = function(header)
        if FORMAT:match('latex') and header.level == 2 then
          local title = pandoc.utils.stringify(header.content)
          if (french_philosophy and title == 'Une mécanique reproductible')
            or (english_philosophy and title == 'Reproducible rules') then
            return {pandoc.RawBlock('latex', '\\clearpage'), header}
          end
        end
      end,
      Inlines = function(inlines)
        if FORMAT:match('latex') and french_philosophy then
          for index = 2, #inlines do
            if inlines[index].t == 'Str' and inlines[index].text == ':'
              and inlines[index - 1].t == 'Space' then
              inlines[index - 1] = pandoc.Str(utf8.char(160))
            end
          end
          return inlines
        end
      end,
      Link = function(link)
        local target = link.target
        if target:match('^%a[%w+.-]*:') then return link end
        local filename, anchor = target:match('^([^#]*)#?(.*)$')
        local canonical
        if filename == '' then
          canonical = entry.path
        else
          canonical = normal_path(directory(entry.path) .. '/' .. filename)
        end
        if identifiers[canonical] then
          local destination = anchor ~= '' and identifiers[canonical][anchor] or first_ids[canonical]
          assert(destination, 'Unknown book anchor: ' .. entry.path .. ' -> ' .. target)
          link.target = '#' .. destination
        end
        return link
      end,
      CodeBlock = function(code)
        if FORMAT:match('latex') then
          assert(not code.text:find('\\end{Verbatim}', 1, true), 'Verbatim terminator in code block')
          return pandoc.RawBlock('latex', '\\begin{Verbatim}[fontsize=\\small,breaklines=true,breakanywhere=true,breakindent=10pt,breaksymbolleft={}]\n' .. code.text .. '\n\\end{Verbatim}')
        end
      end
    })
    if FORMAT:match('latex') then
      blocks:insert(pandoc.RawBlock('latex', '\\clearpage'))
    end
    blocks:extend(chapter.blocks)
  end
  return pandoc.Pandoc(blocks, doc.meta)
end
