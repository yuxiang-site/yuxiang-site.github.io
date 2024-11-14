-- https://stackoverflow.com/questions/56873622/highlight-one-specific-author-when-generating-references-in-pandoc
local highlight_author_filter = {
    Para = function(el)
        if el.t == "Para" then
            for k, _ in ipairs(el.content) do
                -- print(el.content[k].text)
                -- Yuxiang Wei
                if el.content[k].t == "Str" and el.content[k].text == "Yuxiang" and el.content[k + 1].t == "Space" and
                    el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Wei") then
                    local _, e = el.content[k + 2].text:find("Wei")
                    local rest = el.content[k + 2].text:sub(e + 1)
                    el.content[k] = pandoc.Strong {pandoc.Str("Yuxiang Wei")}
                    el.content[k + 1] = pandoc.Str(rest)
                    table.remove(el.content, k + 2)
                end
                -- Wei, Yuxiang
                if el.content[k].t == "Str" and el.content[k].text == "Wei," and el.content[k + 1].t == "Space" and
                    el.content[k + 2].t == "Str" and el.content[k + 2].text:find("Yuxiang") then
                    local _, e = el.content[k + 2].text:find("Yuxiang")
                    local rest = el.content[k + 2].text:sub(e + 1)
                    el.content[k] = pandoc.Strong {pandoc.Str("Wei, Yuxiang")}
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
