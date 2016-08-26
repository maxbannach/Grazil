---
-- Copyright 2016 by Till Tantau
--
-- This file may be distributed and/or modified under the GNU Public License
--

---
-- The file interface provides methods to store and load grazil digraphs
-- from different graph formats.
--
local FileInterface = {}
FileInterface.__index = FileInterface

---
-- Constructor
--
function FileInterface.new(file)
   self = {}
   self.file = file
   return setmetatable(self, FileInterface)
end

-- done
return FileInterface
