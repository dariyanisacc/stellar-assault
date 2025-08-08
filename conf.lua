function love.conf(t)
  -- Stable save directory identity so logs and saves have a known path
  -- macOS: ~/Library/Application Support/LOVE/stellar-assault
  -- Linux: ~/.local/share/love/stellar-assault
  -- Windows: %APPDATA%/LOVE/stellar-assault
  t.identity = "stellar-assault"
  t.console = true         -- Windows: always show a console
  t.gammacorrect = true
end
