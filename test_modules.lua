-- Test module loading
print("Testing module loading...")

local success = true

-- Test loading each module
local modules = {
    {"src.constants", "Constants"},
    {"src.statemanager", "StateManager"},
    {"src.objectpool", "ObjectPool"},
}

for _, module in ipairs(modules) do
    local ok, result = pcall(require, module[1])
    if ok then
        print("✓ " .. module[2] .. " loaded successfully")
    else
        print("✗ " .. module[2] .. " failed to load: " .. tostring(result))
        success = false
    end
end

if success then
    print("\nAll modules loaded successfully!")
else
    print("\nSome modules failed to load.")
end