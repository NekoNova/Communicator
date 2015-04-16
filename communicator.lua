---------------------------------------------------------------------------------------------------
--                                          Communicator
--
-- This library is a wrapper around the ICCommLib in WildStar, and provides an interface for
-- Roleplay Addons that can be used to transfer information between the both of them.
-- The Libary can also be used by different Addons if desired to transfer information, this just
-- requires some modifications to the transfer protocol.
---------------------------------------------------------------------------------------------------
local Communicator = {}
local Message = {}
require "ICCommLib"

local MAJOR, MINOR = "Communicator-1.0", 1
-- Get a reference to the package information if any
local APkg = Apollo.GetPackage(MAJOR)
-- If there was an older version loaded we need to see if this is newer
if APkg and (APkg.nVersion or 0) >= MINOR then
	return -- no upgrade needed
end

local JSON = Apollo.GetPackage("Lib:dkJSON-2.5").tPackage
---------------------------------------------------------------------------------------------------
-- Local Functions
---------------------------------------------------------------------------------------------------

-- Splits the given string and returns the values.
--
-- str: The string to break up
-- sep: The delimiter, seperating the values.
local function split(str, sep)
  if sep == nil then sep = "%s" end
  
  local result = {} ; i = 1
  local pattern = string.format("([^%s]+)%s", sep, sep)
  
  for match in str:gmatch(pattern) do
    result[i] = match
    i = i + 1
  end
  
  return unpack(result)
end

---------------------------------------------------------------------------------------------------
-- Message Constants
---------------------------------------------------------------------------------------------------
Message.Type_Request = 1
Message.Type_Reply = 2
Message.Type_Error = 3
Message.Type_Broadcast = 4

Message.ProtocolVersion = 1

---------------------------------------------------------------------------------------------------
-- Message Module Initialization
---------------------------------------------------------------------------------------------------
function Message:new()
  local o = {}
  
  setmetatable(o, self)
  self.__index = self
  
  self:SetProtocolVersion(Message.ProtocolVersion)
  self:SetMessageType(Message.Type_Request)
  self:SetOrigin(self:GetOriginName())
  
  return o
end

---------------------------------------------------------------------------------------------------
-- Message Setters and Getters
---------------------------------------------------------------------------------------------------
function Message:GetSequence()
  return self.nSequence
end

function Message:SetSequence(nSequence)
  if(type(nSequence) ~= "number") then
    error("Communicator: Attempt to set non-number sequence: " .. tostring(nSequence))
  end
  
  self.nSequence = nSequence
end

function Message:GetCommand()
  return self.strCommand
end

function Message:SetCommand(strCommand)
  if(type(strCommand) ~= "string") then
    error("Communicator: Attempt to set non-string command: " .. tostring(strCommand))
  end
  
  self.strCommand = strCommand
end

function Message:GetType()
  return self.eMessageType
end

function Message:SetType(eMessageType)
  if(type(eMessageType) ~= "number") then
    error("Communicator: Attempt to set non-number type: " .. tostring(eMessageType))
  end
  
  if(eMessageType < Message.Type_Request or eMessageType > Message.Type_Error) then
    error("Communicator: Attempt to set unknown message type: " .. tostring(eMessageType))
  end
  
  self.eMessageType = eMessageType
end

function Message:GetAddonProtocol()
  return self.strAddon
end

function Message:SetAddonProtocol(strAddon)
  if(type(strAddon) ~= "string" and type(strAddon) ~= "nil") then
    error("Communicator: Attempt to set non-string addon: " .. tostring(strAddon))
  end
  
  self.strAddon = strAddon
end

function Message:GetOrigin()
  return self.strOrigin
end

function Message:SetOrigin(strOrigin)
  if(type(strOrigin) ~= "string") then
    error("Communicator: Attempt to set non-string origin: " .. tostring(strOrigin))
  end
  
  self.strOrigin = strOrigin
end

function Message:GetDestination()
  return self.strDestination
end

function Message:SetDestination(strDestination)
  if(type(strDestination) ~= "string") then
    error("Communicator: Attempt to set non-string destination: " .. tostring(strDestination))
  end
  
  self.strDestination = strDestination
end

function Message:GetPayload()
  return self.tPayload
end

function Message:SetPayload(tPayload)
  if(type(tPayload) ~= "table") then
    error("Communicator: Attempt to set non-table payload: " .. tostring(tPayload))
  end
  
  self.tPayload = tPayload
end

function Message:GetProtocolVersion()
  return self.nProtocolVersion
end

function Message:SetProtocolVersion(nProtocolVersion)
  if(type(nProtocolVersion) ~= "number") then
    error("Communicator: Attempt to set non-number protocol: " .. tostring(nProtocolVersion))
  end
  
  self.nProtocolVersion = nProtocolVersion
end

---------------------------------------------------------------------------------------------------
-- Message serialization & deserialization
---------------------------------------------------------------------------------------------------

function Message:Serialize()
	local message ={
		version = self:GetProtocolVersion(),
		command = self:GetCommand(),
		type = self:GetType(),
		tPayload = self:GetPayload(),
		sequence = self:GetSequence(),
		origin = self:GetOrigin(),
		destination = self:GetDestination())
	}
	return JSON:encode(message)   
end

function Message:Deserialize(strPacket)
  if(strPacket == nil) then return end
  local message = JSON:decode(strPacket)

  -- Set out properties
  self:SetProtocolVersion(message.version)
  self:SetCommand(message.command)
  self:SetType(message.type)
  self:SetPayload(message.tPayload)
  self:SetSequence(message.sequence)
  self:SetOrigin(message.origin)
  self:SetDestination(message.destination)
  
end

---------------------------------------------------------------------------------------------------
-- Communicator Constants
---------------------------------------------------------------------------------------------------
Communicator.Error_UnimplementedProtocol = 1
Communicator.Error_UnimplementedCommand = 2
Communicator.Error_RequestTimedOut = 3

Communicator.Debug_Errors = 1
Communicator.Debug_Comm = 2
Communicator.Debug_Access = 3

Communicator.Version = "0.1"
Communicator.MaxLength = 250

Communicator.TTL_Trait = 120
Communicator.TTL_Version = 300
Communicator.TTL_Flood = 30
Communicator.TTL_Channel = 60
Communicator.TTL_Packet = 15
Communicator.TTL_GetAll = 120
Communicator.TTL_CacheDie = 604800

Communicator.Trait_Name = "fullname"
Communicator.Trait_NameAndTitle = "title"
Communicator.Trait_RPState = "rpstate"
Communicator.Trait_Description = "shortdesc"
Communicator.Trait_Biography = "bio"

---------------------------------------------------------------------------------------------------
-- Communicator Initialization
---------------------------------------------------------------------------------------------------
function Communicator:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

---------------------------------------------------------------------------------------------------
-- Communicator Methods
---------------------------------------------------------------------------------------------------
function Communicator:OnLoad()
  self.tApiProtocolHandlers = {}
  self.tLocalTraits = {}
  self.tOutgoingRequests = {}
  self.tFloodPrevent = {}
  self.tCachedPlayerData = {}
  self.tPendingPlayerTraitRequests = {}
  self.tCachedPlayerChannels = {}
  self.bTimeoutRunnin = false
  self.nSequenceCounter = 0
  self.nDebugLevel = 0
  self.qPendingMessages = Queue:new()
  self.kstrRPStateStrings = {
    "In-Character, Not Available for RP",
    "Available for RP",
    "In-Character, Available for RP",
    "In a Private Scene (Temporarily OOC)",
    "In a Private Scene",
    "In an Open Scene (Temporarily OOC)",
    "In an Open Scene" }
  self.strPlayerName = nil
  
  -- Register our timeout handlers for all timers.
  Apollo.RegisterTimerHandler("Communicator_Timeout", "OnTimerTimeout", self)
  Apollo.RegisterTimerHandler("Communicator_TimeoutShutdown", "OnTimerTimeoutShutdown", self)
  Apollo.RegisterTimerHandler("Communicator_Queue", "OnTimerQueue", self)
  Apollo.RegisterTimerHandler("Communicator_QueueShutdown", "OnTimerQueueShutdown", self)
  Apollo.RegisterTimerHandler("Communicator_Setup", "OnTimerSetup", self)
  Apollo.RegisterTimerHandler("Communicator_TraitQueue", "OnTimerTraitQueue", self)
  Apollo.RegisterTimerHandler("Communicator_CleanupCache", "OnTimerCleanupCache", self)
  
  -- Create the timers
  Apollo.CreateTimer("Communicator_Setup", 1, false)
  Apollo.CreateTimer("Communicator_CleanupCache", 60, true)
end

function Communicator:OnSave(eLevel)
  if (eLevel == GameLib.CodeEnumAddonSaveLevel.Character) then
    return { localData = self.tLocalTraits }
  elseif (eLevel == GameLib.CodeEnumAddonSaveLevel.Realm) then
    return { cachedData = self.tCachedPlayerData }
  else
    return nil
  end
end

function Communicator:OnRestore(eLevel, tDate)
  if (tData ~= nil and eLevel == GameLib.CodeEnumAddonSaveLevel.Character) then
    local tLocal = tData.localData
    local tCache = tData.cachedData
    
    self.tLocalTraits = tLocal or {}
    
    if (tCache ~= nil) then
      self.tCachedPlayerData = tData.cachedData or {}
    end
  elseif (tData ~= nil and eLevel == GameLib.CodeEnumAddonSaveLevel.Realm) then
    self.tCachedPlayerData = tData.cachedData or {}
  end
end

function Communicator:Initialize()
  if(GameLib.GetPlayerUnit() == nil) then
    Apollo.CreateTimer("Communicator_Setup", 1, false)
    return
  end
  
  -- Configure the Channel according new ICCommLib standards
  self.chnCommunicator = ICComLib.JoinChannel("Communicator", ICComLib.CodeEnumICCommChannelType.Global)
  self.chnCommunicator:SetJoinResultFunction("OnSyncChannelJoined", self)
  self.chnCommunicator:IsReady()
  self.chnCommunicator:SetReceivedMessageFunction("OnSyncMessageReceived", self)
end

function Communicator:Reply(mMessage, tPayload)
  local newMessage = Message:new()
  
  newMessage:SetProtocolVersion(mMessage:GetProtocolVersion())
  newMessage:SetSequence(mMessage:GetSequence())
  newMessage:SetAddonProtocol(mMessage:GetAddonProtocol())
  newMessage:SetType(mMessage:GetType())
  newMessage:SetPayload(tPayload)
  newMessage:SetDestination(mMessage:GetOrigin())
  newMessage:SetCommand(mMessage:GetCommand())
  newMessage:SetOrigin(mMessage:GetDestination())
  
  return newMessage
end

function Communicator:GetOriginName()
  local myUnit = GameLib.GetPlayerUnit()
  
  if (myUnit ~= nil) then
    self.strPlayerName = myUnit:GetName()
  end
  
  return self.strPlayerName
end

function Communicator:SetDebugLevel(nDebugLevel)
  self.nDebugLevel = nDebugLevel
end

function Communicator:ValueOfBit(p)
  return 2 ^ (p - 1)
end

function Communicator:HasBitFlag(x, p)
  local np = self:ValueOfBit(p)
  return x % (np + np) >= np
end

function Communicator:SetBitFlag(x, p, b)
  local np = self:ValueOfBit(p)
  
  if(b) then
    return self:HasBitFlag(x, p) and x or x + np
  else
    return self:HasBitFlag(x, p) and x - np or x
  end
end

function Communicator:Log(nLevel, strLog)
  if(nLevel > self.nDebugLevel) then return end
  Print("Communicator: " .. strLog)
end

function Communicator:FlagsToString(nState)
  return self.kstrRPStateStrings[nState] or "Not Available for RP"
end

function Communicator:EscapePattern(strPattern)
  return strPattern:gsub("(%W)", "%%%1")
end

function Communicator:TruncateString(strText, nLength)
  if(strText == nil) then return nil end
  if(strText:len() <= nlength) then return strText end
  
  local strResult = strText:sub(1, nLength)
  local nSpacePos = strResult:find(" ", -1)
  
  if (nSpacePos ~= nil) then
    strResult = strResult:sub(1, nSpacePos - 1) .. "..."
  end
  
  return strResult
end

function Communicator:GetTrait(strTarget, strTrait)
  local result = nil
  
  if(strTrait == Communicator.Trait_Name) then
    result = self:FetchTrait(strTarget, Communicator.Trait_Name) or strTarget
  elseif(strTrait == Communicator.Trait_NameAndTitle) then
    local name = self:FetchTrait(strTarget, Communicator.Trait_Name)
    result = self:FetchTrait(strTarget, Communicator.Trait_NameAndTitle)
    
    if (result == nil) then
      result = name
    else
      local nStart,nEnd = result:find("#name#")
      
      if (nStart ~= nil) then
        result = result:gsub("#name#", self:EscapePattern(name or strTarget))
      else
        result = result .. " " .. (name or strTarget)
      end
    end
  elseif(strTrait == Communicator.Trait_Description) then
    result = self:FetchTrait(strTarget, Communicator.Trait_Description)
   
    if(result ~= nil) then
      result = self:TruncateString(result, Communicator.MaxLength)
    end
  elseif(strTrait == Communicator.Trait_RPState) then
    local rpFlags = self:FetchTrait(strTarget, Communicator.Trait_RPState) or 0
    result = self:FlagsToString(rpFlags)
  elseif(strTrait == Communicator.Trait_Biography) then
    result = self:FetchTrait(strTarget, Communicator.Trait_Biography)
  else
    result = self:FetchTrait(strTarget, strTrait)
  end
  
  return result
end

function Communicator:SetRPFlag(flag, bSet)
  local nState, nRevision = self:GetLocalTrait("rpflag")
  nState = self:SetBitFlag(flag, bSet)
  self:SetLocalTrait("rpflag", nState)
end

function Communicator:ProcessTraitQueue()
  for strTarget, aRequests in pairs(self.tPendngPlayerTraitRequests) do
    self:Log(Communicator.Debug_Comm, "Sending: " .. table.getn(aRequests) .. " qeued trait requests to " .. strTarget)
    
    local mMessage = Message:new()
    
    mMessage:SetDestination(strTarget)
    mMessage:SetCommand("get")
    mMessage:SetPayload(aRequests)
    
    self:SendMessage(mMessage)
    self.tPendingPlayerTraitRequests[strTarget] = nil
  end
end

function Communicator:FetchTrait(strTarget, strTraitName)
  if (strTarget == nil or strTarget == self:GetOriginName()) then
    local tTrait = self.tLocalTraits[strTraitName] or {}
    self:Log(Communicator.Debug_Access, string.format("Fetching own %s: (%d) %s", strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    return tTrait.data, tTrait.revision
  else
    local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
    local tTrait = tPlayerTraits[strTraitName] or {}
    
    self:Log(Communicator.Debug_Access, string.format("Fetching %s's %s: (%d) %s", strTarget, strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    
    local nTTL = Communicator.TTL_Trait
    
    if((tTrait.revision or 0) == 0) then nTTL = 10 end
    if(tTrai == nil or (os.time() - (tTRait.time or 0)) > nTTL) then
      tTrait.time = os.time()
      tPlayerTraits[strTraitName] = tTrait
      self.tCachedPlayerData[strTarget] = tPlayerTraits
      
      local tPendingPlayerQuery = self.tPendingPlayerTraitRequests[strTarget] or {}
      local tRequest = { trait = strTraitName, revision = tTraitRevision or 0 }
      
      table.insert(tPendingPlayerQuery, tRequest)
      
      self.tPendingPlayerTraitRequests[strTarget] = tPendingPlayerQuery
      Apollo.CreateTimer("Communicator_TraitQueue", 1, false)
    end
    
    return tTrait.data, tTrait.revision
  end
end

Apollo.RegisterPackage(Communicator:new(), MAJOR, MINOR, {"Lib:dkJSON-2.5"})