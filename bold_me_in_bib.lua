-- https://stackoverflow.com/questions/56873622/highlight-one-specific-author-when-generating-references-in-pandoc
-- local highlight_author_filter = {
--     Para = function(el)
--         if el.t == "Para" then
--             for k, _ in ipairs(el.content) do
--                 -- print(el.content[k].text)
--                 -- Yuxiang Wei
--                 if el.content[k].t == "Str" and el.content[k].text == "Yuxiang" and el.content[k + 1].t == "Space" and
--                     el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Wei") then
--                     local _, e = el.content[k + 2].text:find("Wei")
--                     local rest = el.content[k + 2].text:sub(e + 1)
--                     el.content[k] = pandoc.Strong {pandoc.Str("Yuxiang Wei")}
--                     el.content[k + 1] = pandoc.Str(rest)
--                     table.remove(el.content, k + 2)
--                 end
--                 -- Wei, Yuxiang
--                 if el.content[k].t == "Str" and el.content[k].text == "Wei," and el.content[k + 1].t == "Space" and
--                     el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Yuxiang") then
--                     local _, e = el.content[k + 2].text:find("Yuxiang")
--                     local rest = el.content[k + 2].text:sub(e + 1)
--                     el.content[k] = pandoc.Strong {pandoc.Str("Wei, Yuxiang")}
--                     el.content[k + 1] = pandoc.Str(rest)
--                     table.remove(el.content, k + 2)
--                 end
--             end
--         end
--         return el
--     end
-- }

-- function Div(div)
--     if 'refs' == div.identifier then
--         return pandoc.walk_block(div, highlight_author_filter)
--     end
--     return nil
-- end


-- https://stackoverflow.com/questions/56873622/highlight-one-specific-author-when-generating-references-in-pandoc
local highlight_author_filter = {
    Para = function(el)
        if el.t == "Para" then
            for k, _ in ipairs(el.content) do
                -- ========= NEW: Yuxiang Wei -- Core contributor =========
                if el.content[k] and el.content[k].t == "Str" and el.content[k].text == "Yuxiang" and
                   el.content[k + 1] and el.content[k + 1].t == "Space" and
                   el.content[k + 2] and el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Wei") and
                   el.content[k + 3] and el.content[k + 3].t == "Space" and
                   el.content[k + 4] and el.content[k + 4].t == "Str" and (el.content[k + 4].text == "--" or el.content[k + 4].text == "–" or el.content[k + 4].text == "—" or el.content[k + 4].text == "-") and
                   el.content[k + 5] and el.content[k + 5].t == "Space" and
                   el.content[k + 6] and el.content[k + 6].t == "Str" and el.content[k + 6].text == "Core" and
                   el.content[k + 7] and el.content[k + 7].t == "Space" and
                   el.content[k + 8] and el.content[k + 8].t == "Str" and el.content[k + 8].text:find("contributor")
                then
                    -- handle "Wei" possibly glued to punctuation, and "contributor" possibly glued to punctuation
                    local _, e1 = el.content[k + 2].text:find("Wei")
                    local rest_after_wei = el.content[k + 2].text:sub(e1 + 1)

                    local _, e2 = el.content[k + 8].text:find("contributor")
                    local rest_after_contrib = el.content[k + 8].text:sub(e2 + 1)

                    local dash = el.content[k + 4].text
                    local phrase = "Yuxiang Wei " .. dash .. " Core contributor"

                    -- Replace k..k+8 with one Strong phrase; keep any trailing chars
                    el.content[k] = pandoc.Strong { pandoc.Str(phrase) }
                    el.content[k + 1] = pandoc.Str(rest_after_contrib)  -- may be empty
                    -- remove consumed tokens (from k+2 to k+8)
                    for _i = k + 2, k + 8 do
                        table.remove(el.content, k + 2)
                    end
                    -- if there was text after "Wei", keep it immediately after the bold phrase
                    if rest_after_wei ~= "" then
                        table.insert(el.content, k + 1, pandoc.Str(rest_after_wei))
                    end
                end

                -- ========= NEW: Wei, Yuxiang -- Core contributor =========
                if el.content[k] and el.content[k].t == "Str" and el.content[k].text == "Wei," and
                   el.content[k + 1] and el.content[k + 1].t == "Space" and
                   el.content[k + 2] and el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Yuxiang") and
                   el.content[k + 3] and el.content[k + 3].t == "Space" and
                   el.content[k + 4] and el.content[k + 4].t == "Str" and (el.content[k + 4].text == "--" or el.content[k + 4].text == "–" or el.content[k + 4].text == "—" or el.content[k + 4].text == "-") and
                   el.content[k + 5] and el.content[k + 5].t == "Space" and
                   el.content[k + 6] and el.content[k + 6].t == "Str" and el.content[k + 6].text == "Core" and
                   el.content[k + 7] and el.content[k + 7].t == "Space" and
                   el.content[k + 8] and el.content[k + 8].t == "Str" and el.content[k + 8].text:find("contributor")
                then
                    local _, e1 = el.content[k + 2].text:find("Yuxiang")
                    local rest_after_yuxiang = el.content[k + 2].text:sub(e1 + 1)

                    local _, e2 = el.content[k + 8].text:find("contributor")
                    local rest_after_contrib = el.content[k + 8].text:sub(e2 + 1)

                    local dash = el.content[k + 4].text
                    local phrase = "Wei, Yuxiang " .. dash .. " Core contributor"

                    el.content[k] = pandoc.Strong { pandoc.Str(phrase) }
                    el.content[k + 1] = pandoc.Str(rest_after_contrib)
                    for _i = k + 2, k + 8 do
                        table.remove(el.content, k + 2)
                    end
                    if rest_after_yuxiang ~= "" then
                        table.insert(el.content, k + 1, pandoc.Str(rest_after_yuxiang))
                    end
                end

                -- ========= ORIGINAL: Yuxiang Wei =========
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

                -- ========= ORIGINAL: Wei, Yuxiang =========
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
        return pandoc.walk_block(div, highlight_author_filter)
    end
    return nil
end
