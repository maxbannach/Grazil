---
-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--

-- improts
local FileInterface = require "grazil.interface.file.FileInterface"
local Digraph = require 'grazil.model.Digraph'
local Vertex  = require 'grazil.model.Vertex'
local Arc     = require 'grazil.model.Arc'

---
-- Provide an interface to files storing graphs in the dimacs format, as used
-- in different DIMACS implementations challenges, as well as in the PACE challenge.
-- @see https://pacechallenge.wordpress.com/track-a-treewidth/ for a detailed description
--
local DimacsInterface = {}
DimacsInterface.__index = DimacsInterface

---
-- Constructor
--
function DimacsInterface.new(file)
   self = FileInterface.new(file)

   return setmetatable(self, DimacsInterface)
end

---
-- Write an directed graph into the managed file.
--
function DimacsInterface:storeDigraph(g)
   local sb = {}

   -- generate a string corresponding to dimacs
   table.insert(sb, "p grazil " .. #g.vertices .. " " .. #g.arcs)
   local phi = self:computeBijection(g)
   for _,arc in ipairs(g.arcs) do
      table.insert(sb, phi[arc.tail] .. " " .. phi[arc.head])
   end

   -- store it into the defined file
   local out = io.open(self.file, "w")
   out:write(table.concat(sb, "\n"))
   out:close()
end

---
-- Write an undirected graph into the managed file.
-- The argument is an grazil Digraph, which is interpetated as undirected graph, i.e.,
-- for each pair of vertices at most one edge is printed.
--
function DimacsInterface:storeGraph(g)
   local sb = {}

   -- generate a string corresponding to dimacs
   table.insert(sb, "p grazil " .. #g.vertices .. " " .. #g.arcs)
   local phi = self:computeBijection(g)
   for _,u in ipairs(g.vertices) do
      for _,v in ipairs(g.vertices) do
	 if phi[u] < phi[v] then
	    local arc = g:arc(u,v) or g:arc(v,u)
	    if arc then
	       table.insert(sb, phi[arc.tail] .. " " .. phi[arc.head])
	    end
	 end
      end
   end

   -- store it into the defined file
   local out = io.open(self.file, "w")
   out:write(table.concat(sb, "\n"))
   out:close()
end


---
-- Computes a bijection from the vertices of g
-- to {1, ..., |V|}.
--
-- Returns a table that stores at position v the index assigned to vertex v.
-- As second return value, the last used index is returned.
--
function DimacsInterface:computeBijection(g)
   local phi = {}
   local index = 1
   for _,v in ipairs(g.vertices) do
      phi[v] = index
      index = index + 1
   end
   return phi, index - 1
end

-- done
return DimacsInterface
