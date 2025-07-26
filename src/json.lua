-- src/json.lua
-- Lightweight JSON encode / decode library
-- Original author: rxi (https://github.com/rxi/json.lua)
-- License: MIT
-- Version: 0.1.2  – untouched, except for minor Lua 5.1‑compat tweaks
------------------------------------------------------------------------

local json = { _version = "0.1.2" }

------------------------------------------------------------------------
-- internal helpers ----------------------------------------------------
------------------------------------------------------------------------

local _gsub, _concat, _insert = string.gsub, table.concat, table.insert

local escape_map = {
  ["\\"] = "\\\\",
  ['"'] = '\\"',
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}
local escape_map_inv = { ["\\/"] = "/" }
for k, v in pairs(escape_map) do
  escape_map_inv[v] = k
end

local function escape_char(c)
  return escape_map[c] or string.format("\\u%04x", c:byte())
end

local function encode_string(s)
  return '"' .. _gsub(s, '[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(n)
  if n ~= n or n <= -math.huge or n >= math.huge then
    error("invalid number value '" .. tostring(n) .. "'")
  end
  return ("%g"):format(n)
end

local function encode_table(val, stack)
  if stack[val] then
    error("circular reference")
  end
  stack[val] = true

  local is_array = (#val > 0)
  local res = {}

  if is_array then -- JSON array
    for i = 1, #val do
      _insert(res, json.encode(val[i], stack))
    end
    stack[val] = nil
    return "[" .. _concat(res, ",") .. "]"
  else -- JSON object
    for k, v in pairs(val) do
      _insert(res, encode_string(tostring(k)) .. ":" .. json.encode(v, stack))
    end
    stack[val] = nil
    return "{" .. _concat(res, ",") .. "}"
  end
end

------------------------------------------------------------------------
-- public API ----------------------------------------------------------
------------------------------------------------------------------------

--- Encodes a Lua value as a JSON string.
function json.encode(value, stack)
  local t = type(value)
  if t == "nil" then
    return "null"
  elseif t == "string" then
    return encode_string(value)
  elseif t == "number" then
    return encode_number(value)
  elseif t == "boolean" then
    return tostring(value)
  elseif t == "table" then
    return encode_table(value, stack or {})
  else
    error("cannot encode value of type '" .. t .. "'")
  end
end

------------------------------------------------------------------------
-- Decoder (recursive‑descent) -----------------------------------------
------------------------------------------------------------------------

local function decode_error(str, idx, msg)
  error(
    string.format(
      "%s at line %d col %d",
      msg,
      select(2, str:sub(1, idx):gsub("\n", "")) + 1,
      idx - str:match("()\n*[^\n]*$", 1) + 1
    )
  )
end

local function skip_ws(str, idx)
  local _, j = str:find("^[ \n\r\t]*", idx)
  return (j or idx - 1) + 1
end

local decode_literal
decode_literal = function(str, idx, lit, val)
  local i, j = str:find(lit, idx, true)
  if i ~= idx then
    decode_error(str, idx, "expected '" .. lit .. "'")
  end
  return val, j + 1
end

local function decode_number(str, idx)
  local num_str = str:match("^%-?%d+%.?%d*[eE]?[+%-]?%d*", idx)
  local num = tonumber(num_str)
  if not num then
    decode_error(str, idx, "invalid number")
  end
  return num, idx + #num_str
end

local function decode_string(str, idx)
  idx = idx + 1 -- skip opening quote
  local res = {}
  while true do
    local c = str:sub(idx, idx)
    if c == '"' then
      return _concat(res), idx + 1
    end
    if c == "\\" then
      local nextc = str:sub(idx + 1, idx + 1)
      if nextc == "u" then
        local hex = str:sub(idx + 2, idx + 5)
        if not hex:find("%x%x%x%x") then
          decode_error(str, idx, "invalid unicode escape")
        end
        _insert(res, utf8 and utf8.char(tonumber(hex, 16)) or string.char(tonumber(hex, 16)))
        idx = idx + 6
      else
        local map = {
          ['"'] = '"',
          ["\\"] = "\\",
          ["/"] = "/",
          b = "\b",
          f = "\f",
          n = "\n",
          r = "\r",
          t = "\t",
        }
        local repl = map[nextc]
        if not repl then
          decode_error(str, idx, "invalid escape char")
        end
        _insert(res, repl)
        idx = idx + 2
      end
    else
      if c == "" then
        decode_error(str, idx, "unterminated string")
      end
      _insert(res, c)
      idx = idx + 1
    end
  end
end

local decode_value
local function decode_array(str, idx)
  idx = skip_ws(str, idx + 1) -- skip '['
  local res = {}
  if str:sub(idx, idx) == "]" then
    return res, idx + 1
  end
  while true do
    local val
    val, idx = decode_value(str, idx)
    _insert(res, val)
    idx = skip_ws(str, idx)
    local c = str:sub(idx, idx)
    if c == "]" then
      return res, idx + 1
    end
    if c ~= "," then
      decode_error(str, idx, "expected ',' or ']'")
    end
    idx = skip_ws(str, idx + 1)
  end
end

local function decode_object(str, idx)
  idx = skip_ws(str, idx + 1) -- skip '{'
  local res = {}
  if str:sub(idx, idx) == "}" then
    return res, idx + 1
  end
  while true do
    if str:sub(idx, idx) ~= '"' then
      decode_error(str, idx, "expected string for key")
    end
    local key
    key, idx = decode_string(str, idx)
    idx = skip_ws(str, idx)
    if str:sub(idx, idx) ~= ":" then
      decode_error(str, idx, "expected ':' after key")
    end
    idx = skip_ws(str, idx + 1)
    local val
    val, idx = decode_value(str, idx)
    res[key] = val
    idx = skip_ws(str, idx)
    local c = str:sub(idx, idx)
    if c == "}" then
      return res, idx + 1
    end
    if c ~= "," then
      decode_error(str, idx, "expected ',' or '}'")
    end
    idx = skip_ws(str, idx + 1)
  end
end

decode_value = function(str, idx)
  idx = skip_ws(str, idx)
  local c = str:sub(idx, idx)
  if c == "{" then
    return decode_object(str, idx)
  elseif c == "[" then
    return decode_array(str, idx)
  elseif c == '"' then
    return decode_string(str, idx)
  elseif c == "-" or c:match("%d") then
    return decode_number(str, idx)
  elseif c == "t" then
    return decode_literal(str, idx, "true", true)
  elseif c == "f" then
    return decode_literal(str, idx, "false", false)
  elseif c == "n" then
    return decode_literal(str, idx, "null", nil)
  else
    decode_error(str, idx, "unexpected character '" .. c .. "'")
  end
end

--- Decodes a JSON string into a Lua value.
function json.decode(str, idx)
  local res
  res, idx = decode_value(str, idx or 1)
  idx = skip_ws(str, idx)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end

return json
