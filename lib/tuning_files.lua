local TuningFiles = {}
local Scala = require("passthrough/lib/tuning_scala")
local Tuning = require("passthrough/lib/tuning")

TuningFiles.get_dir = function()
    return _path.data .. "passthrough/tunings/"
end

TuningFiles.scan = function()
    local dir = TuningFiles.get_dir()
    os.execute("mkdir -p " .. dir)
    local files = {}
    local handle = io.popen('find "' .. dir .. '" -maxdepth 1 -name "*.scl" -type f 2>/dev/null | sort')
    if handle then
        for path in handle:lines() do
            local name = path:match("([^/]+)%.scl$")
            if name then table.insert(files, {name = name, path = path}) end
        end
        handle:close()
    end
    return files
end

TuningFiles.load = function(path)
    local parsed = Scala.parse(path)
    if not parsed or #parsed.ratios == 0 then return nil end
    return Tuning.new(parsed.ratios)
end

return TuningFiles
