
local Solver = require 'grazil.bindings.lingeling.Solver'
local Digraph = require 'grazil.model.Digraph'
local Vertex = require 'grazil.model.Vertex'


local g = Digraph.new ()

local shoreA = {}
local shoreB = {}

for i=1,5 do
  shoreA[i] = Vertex.new { name = "A" .. i }
  shoreB[i] = Vertex.new { name = "B" .. i }
end

g:add (shoreA)
g:add (shoreB)

g:connect (shoreA[1], shoreB[1])
g:connect (shoreA[1], shoreB[2])
g:connect (shoreA[2], shoreB[3])
g:connect (shoreA[3], shoreB[4])
g:connect (shoreA[3], shoreB[1])
g:connect (shoreA[3], shoreB[2])
g:connect (shoreA[4], shoreB[5])
g:connect (shoreA[5], shoreB[2])


print(g)

local s = Solver.new ()

do
  local vars = s.vars

  -- All nodes in shore A must be matched:
  for _,u in ipairs (shoreA) do
    local c = {}
    for _,v in ipairs (shoreB) do
      c[#c+1] = vars(u,v)
    end
    s:addClause (c)
  end

  -- No node in shore A may be matched twice:
  for _,u in ipairs (shoreA) do
    for i=1,#shoreB do
      for j=i+1,#shoreB do
	s:addClause { -vars(u,shoreB[i]), -vars(u,shoreB[j]) }
      end
    end
  end

  -- No node in shore B may be matched twice:
  for _,u in ipairs (shoreB) do
    for i=1,#shoreA do
      for j=i+1,#shoreA do
	s:addClause { -vars(shoreA[i],u), -vars(shoreA[j],u) }
      end
    end
  end

  -- Restrict solution to arcs:
  for _,u in ipairs(g.vertices) do
    for _,v in ipairs(g.vertices) do
      if not g:arc(u,v) then
	s:addClause { -vars(u,v) }
      end
    end
  end
end


local satisfiable = s:solve ()

if satisfiable then
  print ("There is a matching:")

  local sol = Digraph.new ()
  sol:add (g.vertices)

  for _,u in ipairs(g.vertices) do
    for _,v in ipairs(g.vertices) do
      if s:solution (s.vars(u,v)) then
	sol:connect (u,v)
      end
    end
  end

  print (sol)
  
else
  print ("There is no matching")
end
