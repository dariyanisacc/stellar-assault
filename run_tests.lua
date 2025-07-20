#!/usr/bin/env lua

-- Test runner for SpaceDodger
-- This script runs all unit tests using the busted testing framework

-- Add test directories to package path
package.path = package.path .. ";./src/?.lua;./tests/?.lua;./tests/unit/?.lua;./tests/integration/?.lua;./tests/mocks/?.lua"

-- Check if busted is installed
local ok, busted = pcall(require, "busted")
if not ok then
    print("Error: busted testing framework not found!")
    print("Please install busted using: luarocks install busted")
    os.exit(1)
end

-- Configure test runner
local runner = require("busted.runner")

-- Set up test configuration
local options = {
    -- Test file patterns
    pattern = ".*_test%.lua$",
    
    -- Root directory for tests
    ROOT = {"tests"},
    
    -- Output format
    output = "utfTerminal",
    
    -- Enable verbose output
    verbose = true,
    
    -- Enable code coverage (requires luacov)
    coverage = false,
    
    -- Suppress game output during tests
    suppressPrint = false,
}

-- Run tests
local status = runner(options)

-- Exit with appropriate status code
os.exit(status)