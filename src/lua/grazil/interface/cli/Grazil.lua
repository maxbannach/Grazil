-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--


Digraph = require 'grazil.model.Digraph'
Vertex  = require 'grazil.model.Vertex'
Arc     = require 'grazil.model.Arc'


while true do

  local line = io.read ()

  local fun = load (line)

  if not pcall(fun) then
     print("Unknown command: " .. line)
  end
  
end

