---------------------------------------------------------------------------------------------------
--                                            Message
--
--  This package represents a single message that can be send to players.
--  They are being wrapped in a single class to hide the entire functionality of settings various
--  attributes that are being used to determine version, sequence and serialization of data.
---------------------------------------------------------------------------------------------------
local MAJOR, MINOR = "Chua-Message", 1
local APkg = Apollo.GetPackage(MAJOR)

if APkg and (APkg.nVersion or 0) >= MINOR then
  return
end

local Message = APkg and APkg.tPackage or {}
local JSON = Apollo.GetPackage("Lib:dkJSON-2.5").tPackage

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------
Message.CodeEnumMessageType = {
  Request = 1,
  Reply = 2,
  Error = 3,
  Broadcast = 4
}
Message.ProtocolVersion = 1

---------------------------------------------------------------------------------------------------
-- Constructor
---------------------------------------------------------------------------------------------------
function Message:new()
  local o = {}
  
  setmetatable(o, self)
  
  self.__index = self
  
  self:SetProtocolVersion(Message.ProtocolVersion)
  self:SetType(Message.CodeEnumMessageType.Request)
  self:SetOrigin(GameLib:GetPlayerUnit():GetName())
  
  return o
end

---------------------------------------------------------------------------------------------------
-- Getters & Setters
---------------------------------------------------------------------------------------------------
function Message:GetSequence()
  return self.nSequence
end

function Message:SetSequence(nSequence)
  if(type(nSequence) ~= "number") then
    error("Message: Attempt to set non-number sequence: "..tostring(nSequence))
  end
  
  self.nSequence = nSequence
end

function Message:GetCommand()
  return self.strCommand
end

function Message:SetCommand(strCommand)
  if(type(strCommand) ~= "string") then
    error("Message: Attempt to set non-string command: "..tostring(strCommand))
  end
  
  self.strCommand = strCommand
end

function Message:GetType()
  return self.eMessageType
end

function Message:SetType(eMessageType)
  if(type(eMessageType) ~= "number") then
    error("Message: Attempt to set unknown message type: "..tostring(eMessageType))
  end
  
  if(eMessageType < Message.CodeEnumType.Request or eMessageType > Message.CodeEnumType.Error) then
    error("Message: Attempt to set unknown message type: "..tostring(eMessageType))
  end
  
  self.eMessageType = eMessageType
end

function Message:GetAddonProtocol()
  return self.strAddon
end

function Message:SetAddonProtocol(strAddon)
  if(type(strAddon) ~= "string" and type(strAddon) ~= "nil") then
    error("Message: Attempt to set non-string addon: "..tostring(strAddon))
  end
  
  self.strAddon = strAddon
end

function Message:GetOrigin()
  return self.strOrigin
end

function Message:SetOrigin(strOrigin)
  if(type(strOrigin) ~= "string") then
    Print(tostring(strOrigin))
    error("Message: Attempt to set non-string origin: "..tostring(strOrigin))
  end
  
  self.strOrigin = strOrigin
end

function Message:GetDestination()
  return self.strDestination
end

function Message:SetDestination(strDestination)
  if(type(strDestination) ~= "string") then
    error("Message: Attempt to set non-string destination: "..tostring(strDestination))
  end
  
  self.strDestination = strDestination
end

function Message:GetPayload()
  return self.tPayload
end

function Message:SetPayload(tPayload)
  if(type(tPayload) ~= "table") then
    error("Message: Attempt to set non-table payload: "..tostring(tPayload))
  end
  
  self.tPayload = tPayload
end

function Message:GetProtocolVersion()
  return self.nProtocolVersion
end

function Message:SetProtocolVersion(nProtocolVersion)
  if(type(nProtocolVersion) ~= "number") then
    error("Message: Attempt to set non-number protocol: "..tostring(nProtocolVersion))
  end
  
  self.nProtocolVersion = nProtocolVersion
end

---------------------------------------------------------------------------------------------------
-- Serialization & Deserialization
---------------------------------------------------------------------------------------------------

-- Serializes the message and it's internal data structures into a JSON representation that
-- can be broadcasted over the ICCommLib channels to another player.
function Message:Serialize()
  local message ={
    version = self:GetProtocolVersion(),--
    command = self:GetCommand(),--
    type = self:GetType(),--
    tPayload = self:GetPayload(),
    sequence = self:GetSequence(),--
    origin = self:GetOrigin(),--
    destination = self:GetDestination(),--
  }
  
  return JSON.encode(message, { indent = false })  
end

-- Deserializes the provided JSON string into a message structure.
-- Sets all internal properties to the values that are represented in the JSON string.
function Message:Deserialize(strPacket)
  if(strPacket == nil) then
    return
  end
  
  local message = JSON.decode(strPacket)

  self:SetProtocolVersion(message.version)
  self:SetCommand(message.command)
  self:SetType(message.type)
  self:SetPayload(message.tPayload)
  self:SetSequence(message.sequence)
  self:SetOrigin(message.origin)
  self:SetDestination(message.destination)  
end

---------------------------------------------------------------------------------------------------
-- Package Initialization
---------------------------------------------------------------------------------------------------
function Message:Initialize()
  Apollo.RegisterPackage(self, MAJOR, MINOR, { "Lib:dkJSON-2.5" })
end

Message:Initialize()