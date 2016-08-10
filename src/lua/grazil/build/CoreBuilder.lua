-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License


local CoreBuilder = {}
CoreBuilder.__index = CoreBuilder

local Builder = require 'grazil.build.Builder'
local Vertex = require 'grazil.model.Vertex'


setmetatable (CoreBuilder, Builder)




function CoreBuilder.new (g)

  return setmetatable(Builder.new(g), CoreBuilder)
  
end


function CoreBuilder:add (vertices)
  self.g:add(vertices)
end


function CoreBuilder:addNVertices (n)
  for i=1,n do
    self.g:add{Vertex.new{}}
  end
end


function CoreBuilder:makeClique (vertices)
  for _,v in ipairs(vertices) do
    for _,u in ipairs(vertices) do
      if u ~= v then
	self.g:connect(type(u) == "number" and self.g.vertices[u] or u,type(v) == "number" and self.g.vertices[v] or v)
      end
    end
  end
end



return CoreBuilder
