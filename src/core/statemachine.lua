local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine:new()
  local self = setmetatable({}, StateMachine)
  self.states = {}
  self.stack = {}
  self.current = nil
  self.currentName = nil
  return self
end

function StateMachine:register(name, state)
  self.states[name] = state
end

function StateMachine:switch(name, ...)
  while #self.stack > 0 do
    self:pop(...)
  end
  self:push(name, ...)
end

function StateMachine:push(name, ...)
  local state = self.states[name] or name
  if type(state) ~= "table" then
    error("State '" .. tostring(name) .. "' not found!")
  end
  if state.enter then
    state:enter(...)
  end
  table.insert(self.stack, { name = name, state = state })
  self.current = state
  self.currentName = name
end

function StateMachine:pop(...)
  local top = table.remove(self.stack)
  if not top then
    return
  end
  if top.state.leave then
    top.state:leave(...)
  end
  local newTop = self.stack[#self.stack]
  if newTop then
    self.current = newTop.state
    self.currentName = newTop.name
  else
    self.current = nil
    self.currentName = nil
  end
end

function StateMachine:update(dt)
  local current = self.current
  if current and current.update then
    current:update(dt)
  end
end

function StateMachine:draw()
  local current = self.current
  if current and current.draw then
    current:draw()
  end
end

function StateMachine:keypressed(key, scancode, isrepeat)
  local current = self.current
  if current and current.keypressed then
    current:keypressed(key, scancode, isrepeat)
  end
end

function StateMachine:keyreleased(key, scancode)
  local current = self.current
  if current and current.keyreleased then
    current:keyreleased(key, scancode)
  end
end

function StateMachine:mousepressed(x, y, button, istouch, presses)
  local current = self.current
  if current and current.mousepressed then
    current:mousepressed(x, y, button, istouch, presses)
  end
end

function StateMachine:gamepadpressed(joystick, button)
  local current = self.current
  if current and current.gamepadpressed then
    current:gamepadpressed(joystick, button)
  end
end

function StateMachine:gamepadreleased(joystick, button)
  local current = self.current
  if current and current.gamepadreleased then
    current:gamepadreleased(joystick, button)
  end
end

function StateMachine:resize(w, h)
  local current = self.current
  if current and current.resize then
    current:resize(w, h)
  end
end

return StateMachine
