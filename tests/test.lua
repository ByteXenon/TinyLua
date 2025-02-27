--[[
  The Tiny Lua Compiler Test Suite [TLCTS]
--]]

local tlc = require("the-tiny-lua-compiler")

-- TEST HARNESS SETUP --
local PASS = 0
local FAIL = 0

local currentGroup = ""

local function testRunner(name, func)
  local prevFail = FAIL
  local status, result = pcall(func)
  io.write(("%-40s"):format(name))

  if status and FAIL == prevFail then
    -- Print green text
    io.write("\27[32m[PASS]\27[0m\n")
    PASS = PASS + 1
    return
  end

  -- Print red text
  io.write("\27[31m[FAIL]\27[0m\n")
  FAIL = FAIL + 1
end

local function testGroup(name)
  currentGroup = name
  print("\n\27[1m=== " .. name .. " ===\27[0m")
end

-- COMPILER HELPER --
local function compileAndRun(code)
  local tokens = tlc.Tokenizer.new(code):tokenize()
  local ast = tlc.Parser.new(tokens):parse()
  local proto = tlc.CodeGenerator.new(ast):generate()
  local bytecode = tlc.Compiler.new(proto):compile()
  return loadstring(bytecode)()
end

-- TEST SUITE --
testGroup("Lexical Conventions")

testRunner("String delimiters", function()
  assert(compileAndRun([==[
    return "double" .. 'single' .. [[
      multi-line]] .. [=[nested]=]
  ]==]) == "doublesingle\n      multi-linenested")
end)

testRunner("String escape sequences", function()
  -- Numeric escapes
  assert(compileAndRun([[
    return "\9\99\101"
  ]]) == "\tce")

  -- Control characters
  assert(compileAndRun([[
    return "\a\b\f\n\r\t\v"
  ]]) == "\7\b\f\n\r\t\v")
end)

testRunner("Number formats", function()
  assert(compileAndRun("return 123 + 0xA2 + 0X1F + 0.5 + .25 + 1e2") == 416.75)
end)

testGroup("Expressions and Operators")

testRunner("Operator precedence", function()
  assert(compileAndRun("return 2 + 3 * 4 ^ 2 / 2") == 26)
end)

testRunner("Relational operators", function()
  assert(compileAndRun([[
    return (3 < 5) and (5 <= 5) and (7 > 3) and
           (7 >= 7) and (5 ~= 3) and (5 == 5)
  ]]) == true)
end)

testRunner("Logical operators", function()
  assert(compileAndRun([[
    return (true and false) or (true and 1 or 5) or (nil and 3)
  ]]) == 1)
end)

testGroup("Statements")

testRunner("Chained assignments", function()
  assert(compileAndRun([[
    local a, b, c = 1, 2, 3
    a, b = b, a
    c = a + b
    return c
  ]]) == 3)

  assert(compileAndRun([[
    local a, b = {}, {}
    a.x, b.x = 1, 2
    return a.x + b.x
  ]]) == 3)

  assert(compileAndRun([[
    local a = {}
    local b = a

    a.x, a = 1, {x = 4}

    return b.x + a.x
  ]]) == 5)
end)

testRunner("Multiple returns", function()
  local a, b = compileAndRun([[
    return 1, 2, 3
  ]])
  assert(a == 1 and b == 2)
end)

testGroup("Loop Constructs")

testRunner("Numeric for loops", function()
  -- Basic numeric for
  assert(compileAndRun([[
    local sum = 0
    for i = 1, 5 do sum = sum + i end
    return sum
  ]]) == 15)

  -- With step value
  assert(compileAndRun([[
    local sum = 0
    for i = 10, 1, -2 do sum = sum + i end
    return sum
  ]]) == 30)

  -- Floating point range
  assert(compileAndRun([[
    local sum = 0
    for i = 0.5, 2.5, 0.5 do sum = sum + i end
    return sum
  ]]) == 7.5)
end)

testRunner("Generic for loops", function()
  -- ipairs style
  assert(compileAndRun([[
    local sum = 0
    for _, v in ipairs({5, 4, 3}) do
      sum = sum + v
    end
    return sum
  ]]) == 12)

  -- pairs style
  assert(compileAndRun([[
    local t = {a=1, b=2}
    local sum = 0
    for k, v in pairs(t) do
      sum = sum + v
    end
    return sum
  ]]) == 3)

  -- Custom iterator
  assert(compileAndRun([[
    function triples(n)
      return function()
        n = n + 1
        return n <= 3 and n*3 or nil
      end
    end
    local sum = 0
    for v in triples(0) do sum = sum + v end
    return sum
  ]]) == 18)
end)

testRunner("Repeat-until loops", function()
  assert(compileAndRun([[
    local i = 5
    repeat i = i - 1 until i <= 0
    return i
  ]]) == 0)
end)

testRunner("Break statement", function()
  -- Numeric for loop
  assert(compileAndRun([[
    local sum = 0
    for i = 1, 10 do
      sum = sum + i
      if i == 5 then
        break
      end
    end
    return sum
  ]]) == 15)

  -- Generic for loop
  assert(compileAndRun([[
    local sum = 0
    for _, v in ipairs({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}) do
      sum = sum + v
      if v == 5 then
        break
      end
    end
    return sum
  ]]) == 15)

  -- While loop
  assert(compileAndRun([[
    local sum = 0
    while true do
      sum = sum + 1
      if sum == 5 then
        break
      end
    end
    return sum
  ]]) == 5)

  -- Repeat loop
  assert(compileAndRun([[
    local sum = 0
    repeat
      sum = sum + 1
      if sum == 5 then
        break
      end
    until false
    return sum
  ]]) == 5)
end)

testGroup("Variable Scoping")

testRunner("Basic lexical scoping", function()
  assert(compileAndRun([[
    local x = 10
    do
      local x = 20
      x = x + 5
    end
    return x
  ]]) == 10)
end)

testRunner("Function upvalue capture", function()
  assert(compileAndRun([[
    local function outer()
      local x = 5
      return function() return x end
    end
    local inner = outer()
    return inner()
  ]]) == 5)
end)

testRunner("Function upvalue modification", function()
  assert(compileAndRun([[
    local function outer()
      local x = 5
      return function() x = x + 1; return x end
    end
    local inner = outer()
    inner()
    return inner()
  ]]) == 7)
end)

testRunner("Nested function scoping", function()
  assert(compileAndRun([[
    local function outer()
      local x = 10
      local function inner()
        return x + 5
      end
      return inner()
    end
    return outer()
  ]]) == 15)
end)

testRunner("Multi-level closures", function()
  assert(compileAndRun([[
    local function level1()
      local a = 1
      return function()
        local b = 2
        return function()
          return a + b
        end
      end
    end
    return level1()()()
  ]]) == 3)
end)

testRunner("Repeated local declarations", function()
  assert(compileAndRun([[
    local x = 1
    local x = 2
    do
      local x = 3
    end
    return x
  ]]) == 2)
end)

testRunner("Deeply nested scopes", function()
  assert(compileAndRun([[
    local a = 1
    do
      local b = 2
      do
        local c = 3
        do
          return a + b + c
        end
      end
    end
  ]]) == 6)
end)

testGroup("Function Definitions")

testRunner("Function syntax variants", function()
  -- Empty parameter list
  assert(compileAndRun([[
    function f()
      return 42
    end
    return f()
  ]]) == 42)

  -- Varargs
  assert(compileAndRun([[
    function sum(...)
      local s = 0
      for _, n in ipairs{...} do
        s = s + n
      end
      return s
    end

    return sum(1, 2, 3)
  ]]) == 6)
end)

testGroup("Table Constructors")

testRunner("Array-style tables", function()
  assert(compileAndRun([[
    return {1, 2, 3, [4] = 4}[4]
  ]]) == 4)
end)

testRunner("Hash-style tables", function()
  assert(compileAndRun([[
    return {a = 1, ["b"] = 2, [3] = 3}.a
  ]]) == 1)
end)

testRunner("Nested tables", function()
  assert(compileAndRun([[
    return { {1}, {a = {b = 2}} }[2].a.b
  ]]) == 2)
end)

testGroup("Error Handling")

testRunner("Syntax error detection", function()
  local status = pcall(compileAndRun, "return 1 + + 2")
  assert(not status, "Should detect syntax error")
end)

testGroup("Comments")

testRunner("Single-line comments", function()
  assert(compileAndRun([[
    -- This is a comment
    return 42 -- This is another comment
  ]]) == 42)
end)

testRunner("Multi-line comments", function()
  assert(compileAndRun([==[
    --[[
      This is a multi-line comment
      It can span multiple lines
      FALSE ENDING] ]=]
    ]]
    return 42
  ]==]) == 42)

  assert(compileAndRun([===[
    --[=[
      This is a nested multi-line comment
      It can span multiple lines
      FALSE ENDING]] ]= ]==]
    ]=]
    return 42
  ]===]) == 42)
end)

testGroup("Miscellaneous")

testRunner("Parenthesis-less function calls", function()
  assert(compileAndRun([[
    local function f(x) return x end
    local value1 = #f"hello"
    local value2 = f{b = 10}.b
    return value1 + value2
  ]]) == 15)
end)

testGroup("Complex General Tests")

testRunner("Factorial function", function()
  assert(compileAndRun([[
    local function factorial(n)
      if n == 0 then
        return 1
      else
        return n * factorial(n - 1)
      end
    end

    return factorial(5)
  ]]) == 120)
end)

testRunner("Fibonacci sequence", function()
  assert(compileAndRun([[
    local function fib(n)
      if n <= 1 then
        return n
      else
        return fib(n - 1) + fib(n - 2)
      end
    end

    return fib(10)
  ]]) == 55)
end)

testRunner("Quicksort algorithm", function()
  assert(compileAndRun([[
    local function quicksort(t)
      if #t < 2 then return t end

      local pivot = t[1]
      local a, b, c = {}, {}, {}
      for _,v in ipairs(t) do
        if     v < pivot then a[#a + 1] = v
        elseif v > pivot then c[#c + 1] = v
        else                  b[#b + 1] = v
        end
      end

      a = quicksort(a)
      c = quicksort(c)
      for _, v in ipairs(b) do a[#a + 1] = v end
      for _, v in ipairs(c) do a[#a + 1] = v end
      return a
    end

    return table.concat(
      quicksort({5, 3, 8, 2, 9, 1, 6, 0, 7, 4}),
      ", "
    )
  ]]) == "0, 1, 2, 3, 4, 5, 6, 7, 8, 9")
end)

testRunner("Game of Life simulation", function()
  assert(compileAndRun([=[
    local function T2D(w, h)
      local t = {}
      for y = 1, h do
        t[y] = {}
        for x = 1, w do t[y][x] = 0 end
      end
      return t
    end

    local Life = {
      new = function(self, w, h)
        return setmetatable({ w = w, h = h, gen = 1, curr = T2D(w, h), next = T2D(w, h) }, { __index = self })
      end,
      set = function(self, coords)
        for i = 1, #coords, 2 do
          self.curr[coords[i + 1]][coords[i]] = 1
        end
      end,
      step = function(self)
        local curr, next = self.curr, self.next
        local ym1, y, yp1 = self.h - 1, self.h, 1
        for i = 1, self.h do
          local xm1, x, xp1 = self.w - 1, self.w, 1
          for j = 1, self.w do
            local sum = curr[ym1][xm1] + curr[ym1][x] + curr[ym1][xp1] +
                curr[y][xm1] + curr[y][xp1] +
                curr[yp1][xm1] + curr[yp1][x] + curr[yp1][xp1]
            next[y][x] = ((sum == 2) and curr[y][x]) or ((sum == 3) and 1) or 0
            xm1, x, xp1 = x, xp1, xp1 + 1
          end
          ym1, y, yp1 = y, yp1, yp1 + 1
        end
        self.curr, self.next, self.gen = self.next, self.curr, self.gen + 1
      end,
      evolve = function(self, times)
        times = times or 1
        for i = 1, times do self:step() end
      end,
      render = function(self)
        local output = {}
        for y = 1, self.h do
          for x = 1, self.w do
            table.insert(output, self.curr[y][x] == 0 and "□ " or "■ ")
          end
          table.insert(output, "\n")
        end
        return table.concat(output)
      end
    }

    local life = Life:new(5, 5)
    life:set({ 2, 1, 3, 2, 1, 3, 2, 3, 3, 3 })
    life:evolve(3)
    return life:render()
  ]=]) == "□ □ □ □ □ \n□ ■ □ □ □ \n□ □ ■ ■ □ \n□ ■ ■ □ □ \n□ □ □ □ □ \n")
end)

testRunner("Self-compilation", function()
  -- Might take a while to run

  local testCode = [[
    local code = io.open("the-tiny-lua-compiler.lua"):read("*a")
    local tlc  = compileAndRun(code)

    local code = "return 2 * 10 + (function() return 2 * 5 end)()"

    local tokens   = tlc.Tokenizer.new(code):tokenize()
    local ast      = tlc.Parser.new(tokens):parse()
    local proto    = tlc.CodeGenerator.new(ast):generate()
    local bytecode = tlc.Compiler.new(proto):compile()
    local result   = loadstring(bytecode)()

    return result
  ]]

  _G.compileAndRun = compileAndRun
  assert(compileAndRun(testCode) == 30)
  _G.compileAndRun = nil
end)


-- TEST SUMMARY --
print("\n\27[1mTest Results:\27[0m")
print(("Passed: \27[32m%d\27[0m"):format(PASS))
print(("Failed: \27[31m%d\27[0m"):format(FAIL))
print(("Total:  %d"):format(PASS + FAIL))

os.exit(FAIL == 0 and 0 or 1)
