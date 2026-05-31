local Scala = {}

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function parse_pitch(str)
    str = trim(str:match("^([^!]*)") or str)
    str = trim(str)
    if str:find("/") then
        local num, den = str:match("^(%d+)/(%d+)")
        if num and den then return tonumber(num) / tonumber(den) end
    elseif str:find("%.") then
        local cents = tonumber(str)
        if cents then return 2 ^ (cents / 1200) end
    else
        local n = tonumber(str)
        if n then return n end
    end
    return nil
end

Scala.parse = function(filename)
    local f = io.open(filename, "r")
    if not f then return nil end
    local line_num = 0
    local description, count, ratios = "", 0, {}
    for line in f:lines() do
        line = trim(line)
        if not line:match("^!") and line ~= "" then
            line_num = line_num + 1
            if line_num == 1 then
                description = line
            elseif line_num == 2 then
                count = tonumber(line) or 0
            else
                local r = parse_pitch(line)
                if r then table.insert(ratios, r) end
            end
        end
    end
    f:close()
    return {description = description, count = count, ratios = ratios}
end

return Scala
