---
-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--

-- imports
local Builder = require "grazil.build.Builder"
local Digraph = require "grazil.model.Digraph"
local Random = require "grazil.model.Random"

---
-- A sampler is a special kind of a builder: While a builder
-- provides specific function to modify a existing graph, the purpose of
-- a sampler is to sample a graph from probability distributions over graphs.
-- For instance, a sampler could sample the famous G(n,p) distribution. Such an operation
-- can be seen as adding a graph to an existing or empty graph in an nondeterministic fashion.
--
-- If a sampler samples multiple graphs successively, it will (depending on the probability distribution)
-- also generate different graphs. Different objects of the same sampler may also produce different
-- sample sequences. However, the whole nondeterminism of a sampler boils down to the <seed> value with which
-- the sampler is created.
--
local Sampler = {}
Sampler.__index = Sampler
setmetatable(Sampler, Builder)

---
-- Constructor
--
function Sampler.new(g, seed)
   local self = Builder.new(g or Digraph.new())
   self.seed = seed or os.time()
   self.Random = Random.new(seed)
   return setmetatable(self, Sampler)
end

-- done
return Sampler
