describe("Helpers", function()
  local helpers

  before_each(function()
    helpers = require("src.core.helpers")
  end)

  it("clamp limits a value to a range", function()
    assert.equals(5, helpers.clamp(5, 0, 10))
    assert.equals(0, helpers.clamp(-1, 0, 10))
    assert.equals(10, helpers.clamp(15, 0, 10))
  end)

  it("center returns midpoint coordinates", function()
    local x, y = helpers.center(10, 20, 30, 40)
    assert.equals(25, x)
    assert.equals(40, y)
  end)

  it("sign returns -1, 0 or 1", function()
    assert.equals(1, helpers.sign(3))
    assert.equals(-1, helpers.sign(-0.5))
    assert.equals(0, helpers.sign(0))
  end)
end)
