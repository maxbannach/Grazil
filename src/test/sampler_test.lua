
-- imports
local KTreeSampler = require "grazil.sample.KTreeSampler"
local PartialKTreeSampler = require "grazil.sample.PartialKTreeSampler"
local DimacsInterface = require "grazil.interface.file.DimacsInterface"


-- sample a graph
print("Starting Sampler Test")
local sampler = KTreeSampler.new()
local partialSampler = PartialKTreeSampler.new()

print("sampeling a k-tree")
sampler:sample(4,25)
local g = sampler.g

print("sampeling a partial k-tree")
partialSampler:sample(4,25,0.5)
local g2= partialSampler.g

-- export graph as dimacs
local df = DimacsInterface.new("test.gr")
df:storeGraph(g2)


