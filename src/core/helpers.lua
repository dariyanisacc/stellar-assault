local Helpers = {}

function Helpers.clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  elseif value > max_value then
    return max_value
  end
  return value
end

function Helpers.center(x, y, w, h)
  return x + w / 2, y + h / 2
end

function Helpers.sign(n)
  if n > 0 then
    return 1
  elseif n < 0 then
    return -1
  else
    return 0
  end
end

return Helpers
