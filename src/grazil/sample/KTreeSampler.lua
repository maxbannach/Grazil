---
-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--

-- imports
local Sampler = require "grazil.sample.Sampler"

---
-- A k-tree is a maximal graph for a given tree width k.
-- This class samples randomly generated k-trees, that is, it provides
-- methods to produce graphs with a given amount of vertices and a certain tree width.
--
local KTreeSampler = {}
KTreeSampler.__index = KTreeSampler

---
-- Constructor
--
function KTreeSampler.new()
   self = Sampler.new(g, seed)

   return setmetatable(self, KTreeSampler)
end

---
-- Replaces the stored graph by a random G_k(t)-tree, that is, by
-- a k-tree width k+1+t vertices.
-- @see addSample for details about the sample process
--
function KTreeSampler:sample(k, t)
   self.g = Digraph.new()
   return self:addSample(k, t)
end

---
-- Add a randomly generated G_k(t)-tree to the stored graph.
-- The tree is generated as follows: it starts with a (k+1)-clique, then for t rounds
-- a new vertex is added and connected to a randomly seleceted k-clique of the current graph
-- (this adds a (k+1)-clique to the stored graph).
--
-- The result is a maximal graph with tree width k and k+1+t vertices.
--
-- This method assumes that the vertices in g are named by {1,...,|V|}, or at least, that no vertex
-- has a name of {|V|+1,...|V|+n}.
--
-- The set of added vertices will be returned.
--
function KTreeSampler:addSample(k, t)

   -- the generated vertices
   local vertices = {}
   
   -- the algorithm manages a list of (k+1)-cliques that are currenlty in
   -- the constrcuted part of the graph
   local cliques = {}

   -- generate the starting (k+1)-clique
   local c = {}
   for i = 1,k+1 do
      local v = Vertex.new{ name = tostring(#self.g.vertices+1) }
      table.insert(c, v)
      self.g:add{ v }
      table.insert(vertices, v)
   end
   self:connectSet(c)
   table.insert(cliques, c)

   -- add t addional vertices
   for i = 1,t do
      local v = Vertex.new{ name = tostring(#self.g.vertices+1) }
      self.g:add{ v }
      table.insert(vertices, v)
      
      -- randomly sample one of the old cliques
      local C = cliques[self.Random:nextRandomNumber(1,#cliques)]

      -- we do not connect to one of the vertices of the clique
      local forbidden = C[self.Random:nextRandomNumber(1, #C)]

      -- connect
      for _,u in pairs(C) do
      	 if u ~= forbidden then
      	    self.g:connect(v,u)
      	    self.g:connect(u,v)
      	 end
      end

      -- add the new generated clique to the list of cliques
      local newClique = {}
      table.insert(newClique, v)
      for _,u in ipairs(C) do
	 if u ~= forbidden then table.insert(newClique, u) end
      end
      table.insert(cliques, newClique)     
   end

   -- done
   return vertices
end

---
-- Pairwise connects the all vertices in the given set, i.e.,
-- forms the given set into a clique.
--
function KTreeSampler:connectSet(C)
   for _,v in ipairs(C) do
      for _,w in ipairs(C) do
	 if v ~= w then self.g:connect(v, w) end
      end
   end
end

-- done
return KTreeSampler
