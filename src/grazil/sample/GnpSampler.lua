---
-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--

-- imports
local Sampler = require "grazil.sample.Sampler"


---
-- This class samples the Erdős–Rényi model G(n,p). That is the space of graphs with n
-- vertices in which each edge is present with probability p.
--
local GnpSampler = {}
GnpSampler.__index = GnpSampler
setmetatable(GnpSampler, Sampler)

---
-- Constructor
--
function GnpSampler.new(g, seed)
   self = Sampler.new(g, seed)

   return setmetatable(self, GnpSampler)
end

---
-- Sample a graph with n vertices in which each directed edge is present with probability p.
-- This will _override_ the stored graph g.
-- The vertices of the generated graph will be returned.
--
function GnpSampler:sample(n, p)
   self.g = Digraph.new()
   return self:addSample(n, p)
end

---
-- Adds n vertices to the stored graph g and connects them randomly.
-- Each directed edge will be present with probability p.
--
-- This method assumes that the vertices in g are named by {1,...,|V|}, or at least, that no vertex
-- has a name of {|V|+1,...|V|+n}.
--
-- The set of added vertices will be returned.
--
function GnpSampler:addSample(n, p)

   -- add n vertices
   local vertices = {}
   for i = 1,n do
      local v = Vertex.new{ name = tostring(#self.g.vertices+1) }
      self.g:add{ v }
      table.insert(vertices, v)
   end

   -- connect them with probability p
   for _,u in ipairs(vertices) do
      for _,v in ipairs(vertices) do
   	 if self.Random:nextRandomNumber() <= p then
   	    self.g:connect(u, v)
   	 end
      end
   end

   return vertices
end

-- done
return GnpSampler
