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

  local line = io.read ()

  local fun = load ("ans[" .. #ans+1 .. "] = (" .. line .. ")")

  local x = pcall(fun)
  ans[#ans+1] = x

  if not x then
    print("Unknown command: " .. line)
  else
    print("ans[" .. #ans .. "] = " .. tostring(ans[#ans]))
  end
  
end

