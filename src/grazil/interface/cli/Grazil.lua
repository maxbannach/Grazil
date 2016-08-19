-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--


Digraph = require 'grazil.model.Digraph'
Vertex  = require 'grazil.model.Vertex'
Arc     = require 'grazil.model.Arc'
CoreBuilder = require 'grazil.build.CoreBuilder'

ans = {}

while true do

  io.write("grazil " .. #ans+1 .. "> ")
  local line = io.read ()

  local fun
  local success 
  if line:match("^%s*%w*%s*=") then
    fun = load ("" .. line .. "")
    success = pcall(fun)
    __result = _G[line:match("^%s*(%w*)%s=")]
  else		  
    fun = load ("__result = (" .. line .. ")")
    success = pcall(fun)
  end

  if not success then
    print("Command failed: " .. line)
  else
    if __result == nil then
      ans[#ans+1] = "no result"
    else
      ans[#ans+1] = __result
      print("  ans[" .. #ans .. "] = " .. tostring(ans[#ans]))
    end
  end
  
end

