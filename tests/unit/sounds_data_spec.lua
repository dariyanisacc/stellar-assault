-- Optional: only run when explicit. Default in CI is to skip.
local REQUIRE_SFX = os.getenv("REQUIRE_SFX") == "1"

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

if REQUIRE_SFX then
  describe("data/sounds.json integrity", function()
    it("references existing .ogg files", function()
      local raw = read_file("data/sounds.json")
      local tbl = json.decode(raw)
      assert.is_table(tbl)
      for key, path in pairs(tbl) do
        assert.is_string(path)
        -- Use io.open to check existence; avoid external 'lfs' dependency
        local f = io.open(path, "rb")
        assert.is_truthy(f, ("sound '%s' missing file: %s"):format(key, path))
        if f then f:close() end
        assert.truthy(path:match("%.ogg$"), ("sound '%s' is not .ogg: %s"):format(key, path))
      end
    end)
  end)
else
  describe("sounds data check (optional)", function()
    it("skipped unless REQUIRE_SFX=1", function()
      pending("Set REQUIRE_SFX=1 to verify assets/sfx paths exist")
    end)
  end)
end
