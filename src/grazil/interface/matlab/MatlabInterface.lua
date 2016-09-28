-- imports
local Digraph = require 'grazil.model.Digraph'
local Vertex  = require 'grazil.model.Vertex'
local Arc     = require 'grazil.model.Arc'

local MatlabInterface = {}
MatlabInterface.__index = MatlabInterface

---
-- Constructor
--
function MatlabInterface.new()
   self = {}

   return setmetatable(self, MatlabInterface)
end

function MatlabInterface:toEdgeList(g)
   local edge_list = {}

   -- generate a string corresponding to dimacs
   local phi = self:computeBijection(g)
   for _,arc in ipairs(g.arcs) do
      table.insert(edge_list, phi[arc.tail])
      table.insert(edge_list, phi[arc.head])
   end

    return edge_list
end

---
-- Computes a bijection from the vertices of g
-- to {1, ..., |V|}.
--
-- Returns a table that stores at position v the index assigned to vertex v.
-- As second return value, the last used index is returned.
--
function MatlabInterface:computeBijection(g)
   local phi = {}
   local index = 1
   for _,v in ipairs(g.vertices) do
      phi[v] = index
      index = index + 1
   end
   return phi, index - 1
end

-- done
return MatlabInterface
