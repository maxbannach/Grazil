---
-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--

-- imports
local random = math.random

---
-- A class capsuling random generators such that the same (or different) random number 
-- sequences can be generated from different objects.
--
-- In detail, this class will reseed whenever a random number is used. The seed sued by the class changes, depending on a previous used
-- random number.
--
-- Using the class will change the (global) math.randomseed seed, but will, however, track all information's
-- for one specific seed. I.e, if math.randomseed changes while using this class, the original random sequence
-- will still be generated.
--
local Random = {}
Random.__index = Random

---
-- Constructor
--
function Random.new(seed)
   local self = {}
   self.seed = seed or os.time()
   
   return setmetatable(self, Random)
end

---
-- Generate the next random number of the sequence.
-- Works like @see math.random
--
function Random:nextRandomNumber(lower, upper)

   -- restart seed and "pop" a few random numbers
   math.randomseed(self.seed)
   for i = 1,3 do
      random()
   end
   self.seed = random()  * math.pow(2,31)

   -- generate the random number to use
   if lower then
      if upper then return random(lower, upper) end
      return random(lower)
   end
   return random()
end
   
-- done
return Random
