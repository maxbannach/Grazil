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
-- In detail, this class keeps track of the random numbers used from the given seed and will than generate
-- the next number of the sequence.
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

   -- pop 3 random numbers, for better random numbers on all operating systems
   self.currentNumber = 3
   
   return setmetatable(self, Random)
end

---
-- Generate the next random number of the sequence.
-- Works like @see math.random
--
function Random:nextRandomNumber(lower, upper)

   -- restart seed and "pop" used random numbers
   math.randomseed(self.seed)
   for i = 1,self.currentNumber do
      random()
   end
   self.currentNumber = self.currentNumber + 1

   -- generate the random number to use
   if lower then
      if upper then return random(lower, upper) end
      return random(lower)
   end
   return random()
end

---
-- Sets the index of the next random number that should be generated in the sequence.
-- The constructor sets this value to 4 and index should not be smaller then 4; and it can not be smaller then 1.
--
function Random:setNextNumber(index)
   assert( index >= 1, "The index of the sequence must be at least 1.")
   self.currentNumber = index-1
end

---
-- Reset the random sequence, i.e. @see nextRandomNumber() will generate the same
-- number as directly after the initialization.
--
function Random:reset()
   self.currentNumber = 3
end
   
-- done
return Random
