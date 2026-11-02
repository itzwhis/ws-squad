-- Translation engine for ws-squad. Nothing to configure here:
-- the language is chosen with `Locales = 'xx'` at the top of shared/config.lua.

Lang = Lang or {}

local function getLocale()
    return Lang[Locales] or Lang.en or {}
end

-- Translate a key (falls back to English, then to the key itself)
function _L(key, ...)
    local s = getLocale()[key] or (Lang.en and Lang.en[key]) or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end

-- Full table for the NUI (selected language over English fallback)
function GetNuiLocale()
    local out = {}
    for k, v in pairs(Lang.en or {}) do out[k] = v end
    for k, v in pairs(getLocale()) do out[k] = v end
    return out
end
