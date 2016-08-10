-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified 2. under the GNU Public License



local grazil = {}


-- Forward 
local tostring_table

---
-- Writes debug info on the output, separating the parameters
-- by spaces. The debug information will include a complete traceback
-- of the stack, allowing you to see ``where you are'' inside the Lua
-- program.
--
-- Note that this function resides directly in the |grazil| table. The
-- reason for this is that you can ``always use it'' since |grazil| is
-- always available in the global name space.
--
-- @param ... List of parameters to write to the output.

function grazil.debug(...)
  local stacktrace = debug.traceback("",2)
  print(" ")
  print("Debug called for: ")
  -- this is to even print out nil arguments in between
  local args = {...}
  for i = 1, #args do
    if i ~= 1 then print(", ") end
    print(tostring_table(args[i], "", 5))
  end
  print_nl('')
  for w in string.gmatch(stacktrace, "/.-:.-:.-%c") do
    print('by ', string.match(w,".*/(.*)"))
  end
end


-- Helper function

function tostring_table(t, prefix, depth)
  if type(t) ~= "table" or (getmetatable(t) and getmetatable(t).__tostring) or depth <= 0 then
    return type(t) == "string" and ('"' .. t .. '"') or tostring(t)
  else
    local r = "{\n"
    for k,v in pairs(t) do
      r = r .. prefix .. "  " .. tostring(k) .. "=" ..
        (v==t and "self" or tostring_table(v, prefix .. "  ", depth-1)) .. ",\n"
    end
    return r .. prefix .. "}"
  end
end



return grazil
