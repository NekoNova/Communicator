---------------------------------------------------------------------------------------------------
--                                            MessageQueue
--
--  This package represents a basic Queue for stroring Data.
--  Comes with Push, Pop and Size methods to handle the Queue and it's contents.
---------------------------------------------------------------------------------------------------
local MAJOR, MINOR = "Chua-MessageQueue", 1
local APkg = Apollo.GetPackage(MAJOR)

if APkg and (APkg.nVersion or 0) >= MINOR then
  return
end

local MessageQueue = APkg and APkg.tPackage or {}

---------------------------------------------------------------------------------------------------
-- Constructor
---------------------------------------------------------------------------------------------------
function MessageQueue:new()
  local o = {
    nFirst = 0,
    nLast = -1
  }
  
  setmetatable(o, self)
  
  self.__index = self
  
  return o
end

---------------------------------------------------------------------------------------------------
-- Queue Push and Pop
---------------------------------------------------------------------------------------------------
function MessageQueue:Push(value)
  local last = (self.nLast + 1)
  
  self.nLast = last
  self[last] = value
end

function MessageQueue:Pop()
  local first = self.nFirst
  
  if first > self.nLast then
    error("MessageQueue: Cannot pop from an empty queue!") 
  end
  
  local value = self[first]
  
  self[first] = nil
  self.nFirst = (first + 1)
  
  return value
end

function MessageQueue:GetSize()
  local length = self.nLast - self.nFirst + 1
  
  return length
end

---------------------------------------------------------------------------------------------------
-- Package Initialization
---------------------------------------------------------------------------------------------------
function MessageQueue:Initialize()
  Apollo.RegisterPackage(self, MAJOR, MINOR, {})
end

MessageQueue:Initialize()