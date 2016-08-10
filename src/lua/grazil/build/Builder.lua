-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License


local Builder = {}
Builder.__index = Builder


-- Imports

local Digraph = require 'grazil.model.Digraph'



function Builder.new (g)

  return setmetatable({ g = g or Digraph.new() }, Builder)
  
end





return Builder
