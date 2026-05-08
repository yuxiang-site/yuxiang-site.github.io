-- Site-wide Pandoc Lua filter.
-- Currently handles publication-list tabs, BibTeX toggles, author
-- highlighting, arXiv source labels, author annotations, and author-list
-- truncation labels.

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function trim(text)
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed
end

local function parse_bibtex_entries(content)
    local entries = {}
    local i = 1
    local length = #content

    while i <= length do
        local start_at = content:find("@", i, true)
        if not start_at then
            break
        end

        local open_brace = content:find("{", start_at, true)
        local open_paren = content:find("%(", start_at)
        local open_pos = nil
        local close_char = nil

        if open_brace and open_paren then
            if open_brace < open_paren then
                open_pos = open_brace
                close_char = "}"
            else
                open_pos = open_paren
                close_char = ")"
            end
        elseif open_brace then
            open_pos = open_brace
            close_char = "}"
        elseif open_paren then
            open_pos = open_paren
            close_char = ")"
        else
            break
        end

        local key_start = content:find("%S", open_pos + 1)
        local comma_pos = key_start and content:find(",", key_start, true)
        if not key_start or not comma_pos then
            i = open_pos + 1
        else
            local key = trim(content:sub(key_start, comma_pos - 1))
            local depth = 1
            local j = open_pos + 1
            local in_quote = false
            local escaped = false

            while j <= length and depth > 0 do
                local char = content:sub(j, j)
                if escaped then
                    escaped = false
                elseif char == "\\" then
                    escaped = true
                elseif char == '"' then
                    in_quote = not in_quote
                elseif not in_quote then
                    if char == content:sub(open_pos, open_pos) then
                        depth = depth + 1
                    elseif char == close_char then
                        depth = depth - 1
                    end
                end
                j = j + 1
            end

            if depth == 0 and key ~= "" and not entries[key] then
                entries[key] = trim(content:sub(start_at, j - 1))
            end
            i = j
        end
    end

    return entries
end

local function normalize_bibtex_value(value)
    return trim(value:gsub("%s+", " "))
end

local function should_display_bibtex_field(name)
    local lower_name = name:lower()
    return lower_name ~= "addendum" and not lower_name:match("%+an$")
end

local function find_matching_close(text, open_pos)
    local open_char = text:sub(open_pos, open_pos)
    local close_char = open_char == "{" and "}" or ")"
    local depth = 1
    local in_quote = false
    local escaped = false
    local i = open_pos + 1

    while i <= #text and depth > 0 do
        local char = text:sub(i, i)
        if escaped then
            escaped = false
        elseif char == "\\" then
            escaped = true
        elseif char == '"' then
            in_quote = not in_quote
        elseif not in_quote then
            if char == open_char then
                depth = depth + 1
            elseif char == close_char then
                depth = depth - 1
            end
        end
        i = i + 1
    end

    if depth == 0 then
        return i - 1
    end
    return nil
end

local function parse_bibtex_fields(body, include_internal_fields)
    local fields = {}
    local i = 1
    local length = #body

    while i <= length do
        while i <= length and body:sub(i, i):match("[%s,]") do
            i = i + 1
        end

        if i > length then
            break
        end

        local name_start = i
        while i <= length and not body:sub(i, i):match("[%s=]") do
            i = i + 1
        end

        local name = trim(body:sub(name_start, i - 1))
        while i <= length and body:sub(i, i):match("%s") do
            i = i + 1
        end

        if name == "" or body:sub(i, i) ~= "=" then
            return nil
        end

        i = i + 1
        while i <= length and body:sub(i, i):match("%s") do
            i = i + 1
        end

        local value_start = i
        local depth = 0
        local in_quote = false
        local escaped = false

        while i <= length do
            local char = body:sub(i, i)
            if escaped then
                escaped = false
            elseif char == "\\" then
                escaped = true
            elseif char == '"' then
                in_quote = not in_quote
            elseif not in_quote then
                if char == "{" then
                    depth = depth + 1
                elseif char == "}" and depth > 0 then
                    depth = depth - 1
                elseif char == "," and depth == 0 then
                    break
                end
            end
            i = i + 1
        end

        if include_internal_fields or should_display_bibtex_field(name) then
            table.insert(fields, {
                name = name,
                value = normalize_bibtex_value(body:sub(value_start, i - 1))
            })
        end

        if body:sub(i, i) == "," then
            i = i + 1
        end
    end

    return fields
end

local function bibtex_entry_parts(entry)
    local type_start, type_end, entry_type = entry:find("^@%s*([%w%-]+)")
    if not entry_type then
        return nil
    end

    local open_pos = entry:find("[{(]", type_end + 1)
    if not open_pos then
        return nil
    end

    local close_pos = find_matching_close(entry, open_pos)
    if not close_pos then
        return nil
    end

    local key_start = entry:find("%S", open_pos + 1)
    local comma_pos = key_start and entry:find(",", key_start, true)
    if not key_start or not comma_pos or comma_pos > close_pos then
        return nil
    end

    return {
        entry_type = entry_type,
        key = trim(entry:sub(key_start, comma_pos - 1)),
        body = entry:sub(comma_pos + 1, close_pos - 1)
    }
end

local function format_bibtex_entry(entry)
    local parts = bibtex_entry_parts(entry)
    if not parts then
        return entry
    end

    local fields = parse_bibtex_fields(parts.body)
    if not fields or #fields == 0 then
        return entry
    end

    local max_name_length = 0
    for _, field in ipairs(fields) do
        if #field.name > max_name_length then
            max_name_length = #field.name
        end
    end

    local lines = { "@" .. parts.entry_type:lower() .. "{" .. parts.key .. "," }
    for i, field in ipairs(fields) do
        local padding = string.rep(" ", max_name_length - #field.name)
        local suffix = i < #fields and "," or ""
        table.insert(lines, "  " .. field.name .. padding .. " = " .. field.value .. suffix)
    end
    table.insert(lines, "}")

    return table.concat(lines, "\n")
end

local function escape_html(text)
    return text
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&#x27;")
end

local function escape_pre_text(text)
    return escape_html(text)
        :gsub("\r\n", "\n")
        :gsub("\r", "\n")
        :gsub("\n", "&#10;")
end

local annotation_symbols = {
    colead = "†",
    ["co-lead"] = "†",
    equal = "*",
    equalcontribution = "*",
    ["equal-contribution"] = "*"
}

local function canonical_annotation_role(role)
    local normalized = trim(role:lower()):gsub("%s+", ""):gsub("_", "-")
    return annotation_symbols[normalized] and normalized or role:lower()
end

local function annotation_symbol(role)
    return annotation_symbols[role] or "†"
end

local function unwrap_bibtex_value(value)
    local unwrapped = trim(value)
    if (unwrapped:sub(1, 1) == "{" and unwrapped:sub(-1) == "}") or
       (unwrapped:sub(1, 1) == '"' and unwrapped:sub(-1) == '"') then
        unwrapped = unwrapped:sub(2, -2)
    end
    return trim(unwrapped:gsub("[{}]", ""))
end

local function split_bibtex_authors(value)
    local authors = {}
    local text = unwrap_bibtex_value(value)
    local start_pos = 1
    local i = 1
    local depth = 0

    while i <= #text do
        local char = text:sub(i, i)
        if char == "{" then
            depth = depth + 1
        elseif char == "}" and depth > 0 then
            depth = depth - 1
        elseif depth == 0 and text:sub(i, i + 4) == " and " then
            table.insert(authors, trim(text:sub(start_pos, i - 1)))
            i = i + 5
            start_pos = i
        else
            i = i + 1
        end
    end

    local final_author = trim(text:sub(start_pos))
    if final_author ~= "" then
        table.insert(authors, final_author)
    end

    return authors
end

local function author_display_variants(author)
    local variants = {}
    local seen = {}

    local function add_variant(value)
        value = trim(value:gsub("%s+", " "))
        if value ~= "" and not seen[value] then
            seen[value] = true
            table.insert(variants, value)
        end
    end

    add_variant(author)

    local family, given = author:match("^([^,]+),%s*(.+)$")
    if family and given then
        add_variant(given .. " " .. family)
    else
        local parts = {}
        for part in author:gmatch("%S+") do
            table.insert(parts, part)
        end
        if #parts >= 2 then
            local family_name = table.remove(parts)
            add_variant(family_name .. ", " .. table.concat(parts, " "))
        end
    end

    return variants
end

local function parse_author_annotation_value(value)
    local annotations = {}
    for item in unwrap_bibtex_value(value):gmatch("[^;]+") do
        local index, roles = trim(item):match("^(%d+)%s*=%s*(.+)$")
        if index and roles then
            local parsed_roles = {}
            for role in roles:gmatch("[^,]+") do
                table.insert(parsed_roles, canonical_annotation_role(role))
            end
            annotations[tonumber(index)] = parsed_roles
        end
    end
    return annotations
end

local function fields_by_name(entry)
    local parts = bibtex_entry_parts(entry)
    if not parts then
        return {}
    end

    local fields = parse_bibtex_fields(parts.body, true) or {}
    local by_name = {}
    for _, field in ipairs(fields) do
        by_name[field.name:lower()] = field.value
    end
    return by_name
end

local function build_bibtex_author_entries(entries)
    local author_entries = {}
    for key, entry in pairs(entries) do
        local fields = fields_by_name(entry)
        if fields.author then
            local authors = {}
            for index, author in ipairs(split_bibtex_authors(fields.author)) do
                table.insert(authors, {
                    index = index,
                    name = author,
                    variants = author_display_variants(author)
                })
            end
            author_entries[key] = authors
        end
    end
    return author_entries
end

local function arxiv_source_text(fields)
    local archive_prefix = fields.archiveprefix and unwrap_bibtex_value(fields.archiveprefix)
    local eprint = fields.eprint and unwrap_bibtex_value(fields.eprint)
    if not archive_prefix or archive_prefix:lower() ~= "arxiv" or not eprint or eprint == "" then
        return nil
    end

    local primary_class = fields.primaryclass and unwrap_bibtex_value(fields.primaryclass)
    if primary_class and primary_class ~= "" then
        return "arXiv: " .. eprint .. " [" .. primary_class .. "]"
    end
    return "arXiv: " .. eprint
end

local function build_arxiv_source_entries(entries)
    local source_entries = {}
    for key, entry in pairs(entries) do
        local parts = bibtex_entry_parts(entry)
        if parts and parts.entry_type:lower() == "misc" then
            local source = arxiv_source_text(fields_by_name(entry))
            if source then
                source_entries[key] = source
            end
        end
    end
    return source_entries
end

local function build_author_annotation_entries(entries, author_entries)
    local annotation_entries = {}
    for key, entry in pairs(entries) do
        local fields = fields_by_name(entry)
        if fields.author and fields["author+an"] then
            local authors = author_entries[key] or {}
            local annotations = parse_author_annotation_value(fields["author+an"])
            local annotated_authors = {}

            for index, roles in pairs(annotations) do
                local author = authors[index] and authors[index].name
                if author then
                    table.insert(annotated_authors, {
                        index = index,
                        variants = author_display_variants(author),
                        roles = roles
                    })
                end
            end

            table.sort(annotated_authors, function(left, right)
                return left.index < right.index
            end)

            if #annotated_authors > 0 then
                annotation_entries[key] = {
                    authors = annotated_authors
                }
            end
        end
    end
    return annotation_entries
end

local bibtex_entries = parse_bibtex_entries(read_file("static/bib.bib") or "")
local bibtex_author_entries = build_bibtex_author_entries(bibtex_entries)
local arxiv_source_entries = build_arxiv_source_entries(bibtex_entries)
local author_annotation_entries = build_author_annotation_entries(bibtex_entries, bibtex_author_entries)
local main_publication_keys = {}

local function stringify_meta_value(value)
    if not value then
        return nil
    end

    local ok, result = pcall(pandoc.utils.stringify, value)
    if ok then
        return trim(result)
    end

    return trim(tostring(value))
end

local function meta_list_to_strings(value)
    local strings = {}
    if not value then
        return strings
    end

    if type(value) == "table" then
        for _, item in ipairs(value) do
            local text = stringify_meta_value(item)
            if text and text ~= "" then
                table.insert(strings, text)
            end
        end
    else
        local text = stringify_meta_value(value)
        if text and text ~= "" then
            table.insert(strings, text)
        end
    end

    return strings
end

local function publication_key(block)
    if block.t ~= "Div" then
        return nil
    end
    return block.identifier:match("^ref%-(.+)$")
end

local function build_key_set(keys)
    local key_set = {}
    for _, key in ipairs(keys) do
        key_set[key] = true
    end
    return key_set
end

local function add_class(block, class_name)
    if block.classes and not block.classes:includes(class_name) then
        block.classes:insert(class_name)
    end
end

local function publication_view_control(selected_entries, total_entries)
    return pandoc.RawBlock("html",
        '<div class="publication-view-control" role="group" aria-label="Publication list view">\n' ..
        '<button type="button" class="publication-view-button" data-publication-view="selected" aria-pressed="true">selected</button>\n' ..
        '<button type="button" class="publication-view-button" data-publication-view="full" aria-pressed="false">full list</button>\n' ..
        '</div>\n' ..
            '<script>\n' ..
            '(function () {\n' ..
            '  function initPublicationView() {\n' ..
            '  var refs = document.getElementById("refs");\n' ..
            '  if (!refs) return;\n' ..
            '  var buttons = document.querySelectorAll("[data-publication-view]");\n' ..
            '  function setPublicationView(view) {\n' ..
            '    refs.classList.toggle("publication-show-full", view === "full");\n' ..
        '    buttons.forEach(function (button) {\n' ..
        '      button.setAttribute("aria-pressed", button.getAttribute("data-publication-view") === view ? "true" : "false");\n' ..
        '    });\n' ..
        '  }\n' ..
        '  buttons.forEach(function (button) {\n' ..
        '    button.addEventListener("click", function () {\n' ..
            '      setPublicationView(button.getAttribute("data-publication-view"));\n' ..
            '    });\n' ..
            '  });\n' ..
            '  }\n' ..
            '  if (document.readyState === "loading") {\n' ..
            '    document.addEventListener("DOMContentLoaded", initPublicationView);\n' ..
            '  } else {\n' ..
            '    initPublicationView();\n' ..
            '  }\n' ..
            '}());\n' ..
            '</script>'
    )
end

local function split_publication_list(div)
    if #main_publication_keys == 0 then
        return div, nil
    end

    local selected_key_set = build_key_set(main_publication_keys)
    local total_entries = 0
    local selected_entries = 0
    for _, block in ipairs(div.content) do
        local key = publication_key(block)
        if key then
            total_entries = total_entries + 1
            if selected_key_set[key] then
                selected_entries = selected_entries + 1
                add_class(block, "publication-selected")
            else
                add_class(block, "publication-extra")
            end
        end
    end

    if selected_entries > 0 and selected_entries < total_entries then
        return div, publication_view_control(selected_entries, total_entries)
    end

    return div, nil
end

local function inline_text_for_matching(inline)
    if inline.t == "Str" then
        return inline.text
    elseif inline.t == "Space" then
        return " "
    elseif inline.t == "Strong" or inline.t == "Emph" or inline.t == "Span" then
        return pandoc.utils.stringify(inline)
    end
    return nil
end

local function match_name_at(inlines, start_index, name)
    local combined = ""

    for end_index = start_index, #inlines do
        local text = inline_text_for_matching(inlines[end_index])
        if not text then
            return nil
        end

        combined = combined .. text
        if combined == name then
            return end_index, ""
        end

        if combined:sub(1, #name) == name then
            local trailing = combined:sub(#name + 1)
            if trailing:match("^[,%.;:]$") then
                return end_index, trailing
            end
            return nil
        end

        if name:sub(1, #combined) ~= combined then
            return nil
        end
    end

    return nil
end

local function annotation_marker(role)
    return pandoc.Superscript { pandoc.Str(annotation_symbol(role)) }
end

local function insert_annotation_marker(inlines, end_index, trailing, role)
    if trailing ~= "" and inlines[end_index].t == "Str" then
        local text = inlines[end_index].text
        inlines[end_index].text = text:sub(1, #text - #trailing)
        table.insert(inlines, end_index + 1, annotation_marker(role))
        table.insert(inlines, end_index + 2, pandoc.Str(trailing))
        return end_index + 3
    end

    table.insert(inlines, end_index + 1, annotation_marker(role))
    return end_index + 2
end

local function stringify_inline_prefix(inlines, end_index)
    local text = {}
    for i = 1, end_index do
        local inline_text = inline_text_for_matching(inlines[i])
        if inline_text then
            table.insert(text, inline_text)
        end
    end
    return table.concat(text)
end

local function visible_author_count_before_et_al(inlines, et_index, author_entries)
    local prefix = stringify_inline_prefix(inlines, et_index - 1)
    local count = 0

    for _, author in ipairs(author_entries) do
        local found = false
        for _, variant in ipairs(author.variants) do
            if prefix:find(variant, 1, true) then
                found = true
                break
            end
        end

        if found then
            count = count + 1
        elseif count > 0 then
            break
        end
    end

    return count
end

local function additional_author_inlines(count)
    local noun = count == 1 and "author" or "authors"
    return {
        pandoc.Strong {
            pandoc.Emph {
                pandoc.Str("and"),
                pandoc.Space(),
                pandoc.Str(tostring(count)),
                pandoc.Space(),
                pandoc.Str("additional"),
                pandoc.Space(),
                pandoc.Str(noun)
            }
        }
    }
end

local function replace_et_al_in_inlines(inlines, author_entries)
    local i = 1
    while i <= #inlines - 2 do
        if inlines[i].t == "Str" and inlines[i].text == "et" and
           inlines[i + 1].t == "Space" and
           inlines[i + 2].t == "Str" and inlines[i + 2].text == "al." then
            local visible_count = visible_author_count_before_et_al(inlines, i, author_entries)
            local additional_count = #author_entries - visible_count

            if additional_count > 0 then
                local replacement = additional_author_inlines(additional_count)
                for _ = 1, 3 do
                    table.remove(inlines, i)
                end
                for j = #replacement, 1, -1 do
                    table.insert(inlines, i, replacement[j])
                end
                i = i + #replacement
            else
                i = i + 3
            end
        else
            local inline = inlines[i]
            if inline.content and type(inline.content) == "table" then
                replace_et_al_in_inlines(inline.content, author_entries)
            end
            i = i + 1
        end
    end
end

local function replace_et_al(entry)
    local key = publication_key(entry)
    local author_entries = key and bibtex_author_entries[key]
    if not author_entries or #author_entries == 0 then
        return entry
    end

    for _, block in ipairs(entry.content) do
        if block.content and type(block.content) == "table" then
            replace_et_al_in_inlines(block.content, author_entries)
        end
    end

    return entry
end

local function is_csl_block(inline)
    return inline.t == "Span" and inline.classes and inline.classes:includes("csl-block")
end

local function arxiv_source_inlines(source)
    local number, primary_class = source:match("^arXiv:%s*(%S+)%s*(%b[])$")
    local inlines = { pandoc.Str("arXiv:") }
    if number then
        table.insert(inlines, pandoc.Space())
        table.insert(inlines, pandoc.Str(number))
        table.insert(inlines, pandoc.Space())
        table.insert(inlines, pandoc.Str(primary_class))
    else
        table.insert(inlines, pandoc.Space())
        table.insert(inlines, pandoc.Str(source:gsub("^arXiv:%s*", "")))
    end
    return inlines
end

local function prepend_arxiv_source(csl_block, source)
    if pandoc.utils.stringify(csl_block):find(source, 1, true) then
        return
    end

    local prefix = { pandoc.Emph(arxiv_source_inlines(source)) }
    if #csl_block.content > 0 then
        table.insert(prefix, pandoc.Str("."))
        table.insert(prefix, pandoc.Space())
    end

    for i = #prefix, 1, -1 do
        table.insert(csl_block.content, 1, prefix[i])
    end
end

local function add_arxiv_source(entry)
    local key = publication_key(entry)
    local source = key and arxiv_source_entries[key]
    if not source then
        return entry
    end

    for _, block in ipairs(entry.content) do
        if block.content and type(block.content) == "table" then
            local last_csl_block = nil
            for _, inline in ipairs(block.content) do
                if is_csl_block(inline) then
                    last_csl_block = inline
                end
            end

            if last_csl_block then
                prepend_arxiv_source(last_csl_block, source)
                return entry
            end
        end
    end

    return entry
end

local function mark_author_annotations_in_inlines(inlines, annotation_entry)
    local marked_roles = {}
    local i = 1

    while i <= #inlines do
        local matched = false
        for _, author in ipairs(annotation_entry.authors) do
            for _, variant in ipairs(author.variants) do
                local end_index, trailing = match_name_at(inlines, i, variant)
                if end_index then
                    local role = author.roles[1]
                    i = insert_annotation_marker(inlines, end_index, trailing, role)
                    marked_roles[role] = true
                    matched = true
                    break
                end
            end
            if matched then
                break
            end
        end

        if not matched then
            local inline = inlines[i]
            if inline.content and type(inline.content) == "table" then
                local nested_roles = mark_author_annotations_in_inlines(inline.content, annotation_entry)
                for role, _ in pairs(nested_roles) do
                    marked_roles[role] = true
                end
            end
            i = i + 1
        end
    end

    return marked_roles
end

local function apply_author_annotations(entry)
    local key = publication_key(entry)
    local annotation_entry = key and author_annotation_entries[key]
    if not annotation_entry then
        return entry
    end

    for _, block in ipairs(entry.content) do
        if block.content and type(block.content) == "table" then
            mark_author_annotations_in_inlines(block.content, annotation_entry)
        end
    end

    return entry
end

local function append_bibtex_toggle(entry)
    if entry.t ~= "Div" then
        return entry
    end

    local key = entry.identifier:match("^ref%-(.+)$")
    local bibtex = key and bibtex_entries[key]
    if not bibtex then
        return entry
    end

    local formatted_bibtex = format_bibtex_entry(bibtex)

    table.insert(entry.content, pandoc.RawBlock("html",
        '<details class="bibtex-toggle">\n' ..
        '<summary aria-label="Show BibTeX for ' .. escape_html(key) .. '">BibTeX</summary>\n' ..
        '<pre class="bibtex-entry"><code>' .. escape_pre_text(formatted_bibtex) .. '</code></pre>\n' ..
        '</details>'
    ))

    return entry
end

local highlight_primary_author_filter = {
    Para = function(el)
        if el.t == "Para" then
            for k, _ in ipairs(el.content) do
                if el.content[k] and el.content[k].t == "Str" and el.content[k].text == "Yuxiang" and
                    el.content[k + 1] and el.content[k + 1].t == "Space" and
                    el.content[k + 2] and el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Wei")
                then
                    local _, e = el.content[k + 2].text:find("Wei")
                    local rest = el.content[k + 2].text:sub(e + 1)
                    el.content[k] = pandoc.Strong { pandoc.Str("Yuxiang Wei") }
                    el.content[k + 1] = pandoc.Str(rest)
                    table.remove(el.content, k + 2)
                end

                if el.content[k] and el.content[k].t == "Str" and el.content[k].text == "Wei," and
                    el.content[k + 1] and el.content[k + 1].t == "Space" and
                    el.content[k + 2] and el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Yuxiang")
                then
                    local _, e = el.content[k + 2].text:find("Yuxiang")
                    local rest = el.content[k + 2].text:sub(e + 1)
                    el.content[k] = pandoc.Strong { pandoc.Str("Wei, Yuxiang") }
                    el.content[k + 1] = pandoc.Str(rest)
                    table.remove(el.content, k + 2)
                end
            end
        end
        return el
    end
}

function Div(div)
    if 'refs' == div.identifier then
        div = pandoc.walk_block(div, highlight_primary_author_filter)
        for i, block in ipairs(div.content) do
            block = replace_et_al(block)
            block = apply_author_annotations(block)
            block = add_arxiv_source(block)
            div.content[i] = append_bibtex_toggle(block)
        end
        return div
    end
    return nil
end

function Pandoc(doc)
    main_publication_keys = meta_list_to_strings(doc.meta.main_publications or doc.meta.featured_publications)
    local i = 1
    while i <= #doc.blocks do
        local block = doc.blocks[i]
        if block.t == "Div" and block.identifier == "refs" then
            local refs, control = split_publication_list(block)
            doc.blocks[i] = refs
            if control then
                table.insert(doc.blocks, i, control)
                i = i + 1
            end
        end
        i = i + 1
    end
    return doc
end
