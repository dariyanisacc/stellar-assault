-- Minimal JSON library for save data
local json = {}

function json.encode(tbl)
    local function serialize(obj, level)
        level = level or 0
        local t = type(obj)
        
        if t == "table" then
            local result = {}
            local is_array = #obj > 0
            
            if is_array then
                -- Array
                for i, v in ipairs(obj) do
                    table.insert(result, serialize(v, level + 1))
                end
                return "[" .. table.concat(result, ",") .. "]"
            else
                -- Object
                for k, v in pairs(obj) do
                    local key = '"' .. tostring(k) .. '"'
                    local value = serialize(v, level + 1)
                    table.insert(result, key .. ":" .. value)
                end
                return "{" .. table.concat(result, ",") .. "}"
            end
        elseif t == "string" then
            return '"' .. obj:gsub('"', '\\"') .. '"'
        elseif t == "number" or t == "boolean" then
            return tostring(obj)
        elseif t == "nil" then
            return "null"
        else
            error("Cannot serialize type: " .. t)
        end
    end
    
    return serialize(tbl)
end

function json.decode(str)
    local index = 1
    
    local function parseValue()
        -- Skip whitespace
        while index <= #str and str:sub(index, index):match("%s") do
            index = index + 1
        end
        
        if index > #str then
            return nil
        end
        
        local char = str:sub(index, index)
        
        if char == '"' then
            -- Parse string
            index = index + 1
            local start = index
            while index <= #str and str:sub(index, index) ~= '"' do
                if str:sub(index, index) == '\\' then
                    index = index + 1
                end
                index = index + 1
            end
            local value = str:sub(start, index - 1):gsub('\\"', '"')
            index = index + 1
            return value
            
        elseif char == '{' then
            -- Parse object
            index = index + 1
            local obj = {}
            
            while index <= #str do
                -- Skip whitespace
                while index <= #str and str:sub(index, index):match("%s") do
                    index = index + 1
                end
                
                if str:sub(index, index) == '}' then
                    index = index + 1
                    return obj
                end
                
                -- Parse key
                local key = parseValue()
                
                -- Skip colon
                while index <= #str and str:sub(index, index) ~= ':' do
                    index = index + 1
                end
                index = index + 1
                
                -- Parse value
                local value = parseValue()
                obj[key] = value
                
                -- Skip comma if present
                while index <= #str and str:sub(index, index):match("[%s,]") do
                    index = index + 1
                end
            end
            
            return obj
            
        elseif char == '[' then
            -- Parse array
            index = index + 1
            local arr = {}
            
            while index <= #str do
                -- Skip whitespace
                while index <= #str and str:sub(index, index):match("%s") do
                    index = index + 1
                end
                
                if str:sub(index, index) == ']' then
                    index = index + 1
                    return arr
                end
                
                -- Parse value
                local value = parseValue()
                table.insert(arr, value)
                
                -- Skip comma if present
                while index <= #str and str:sub(index, index):match("[%s,]") do
                    index = index + 1
                end
            end
            
            return arr
            
        elseif char:match("[%d%-]") then
            -- Parse number
            local start = index
            while index <= #str and str:sub(index, index):match("[%d%.%-]") do
                index = index + 1
            end
            return tonumber(str:sub(start, index - 1))
            
        elseif str:sub(index, index + 3) == "true" then
            index = index + 4
            return true
            
        elseif str:sub(index, index + 4) == "false" then
            index = index + 5
            return false
            
        elseif str:sub(index, index + 3) == "null" then
            index = index + 4
            return nil
        end
    end
    
    return parseValue()
end

return json