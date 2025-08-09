local lfs = require("lfs")

-- Simple JSON parser bundled with the project
local ok, json = pcall(require, "lunajson")
if not ok then ok, json = pcall(require, "src.lunajson") end
if not ok then json = require("src.json") end

local function read_file(path)
  local f = io.open(path, "rb")
  assert.is_truthy(f, "missing file: " .. tostring(path))
  local data = f:read("*a")
  f:close()
  return data
end

describe("data/sounds.json integrity", function()
  it("references existing .ogg files", function()
    local raw = read_file("data/sounds.json")
    local tbl = json.decode(raw)
    assert.is_table(tbl)
    for key, path in pairs(tbl) do
      assert.is_string(path)
      local attr = lfs.attributes(path)
      assert.is_truthy(attr, ("sound '%s' missing file: %s"):format(key, path))
      assert.equals("file", attr.mode, ("sound '%s' path not a file: %s"):format(key, path))
      assert.truthy(path:match("%.ogg$"), ("sound '%s' is not .ogg: %s"):format(key, path))
    end
  end)
end)

