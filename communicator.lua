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
local Queue = {}

require "Window"
require "ICCommLib"
require "ICComm"

local JSON = Apollo.GetPackage("Lib:dkJSON-2.5").tPackage

function Communicator:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
		
    -- initialize variables here
	
    return o
end

function Communicator:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"Lib:dkJSON-2.5",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

---------------------------------------------------------------------------------------------------
-- Local Functions
---------------------------------------------------------------------------------------------------

-- Splits the given string and returns the values.
--
-- str: The string to break up
-- sep: The delimiter, separating the values.
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
-- Queue Module Initialization
---------------------------------------------------------------------------------------------------
function Queue:new()
	local o = {first = 0, last = -1}
	setmetatable(o, self)
	self.__index = self
	return o
end

---------------------------------------------------------------------------------------------------
-- Queue Push and Pop
---------------------------------------------------------------------------------------------------

function Queue:Push (value)
	local last = self.last + 1
	self.last = last
	self[last] = value
end
    
function Queue:Pop()
	local first = self.first
	if first > self.last then error("queue is empty") end
	local value = self[first]
	self[first] = nil        -- to allow garbage collection
	self.first = first + 1
	return value
end

function Queue:GetSize()
	local length = self.last - self.first + 1
	return length
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
  self:SetType(Message.Type_Request)
  self:SetOrigin(Communicator:GetOriginName())
  
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
	Print(tostring(strOrigin))
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
		version = self:GetProtocolVersion(),--
		command = self:GetCommand(),--
		type = self:GetType(),--
		tPayload = self:GetPayload(),
		sequence = self:GetSequence(),--
		origin = self:GetOrigin(),--
		destination = self:GetDestination(),--
	}
	--local xmlMessage = XmlDoc:CreateFromTable(message)
	--Print(xmlMessage)
	--return xmlMessage
	return JSON.encode(message, { indent = false })
	
end

function Message:Deserialize(strPacket)
  if(strPacket == nil) then return end
  local message = JSON.decode(strPacket)

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
  self.tOutGoingRequests = {}
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
  Apollo.RegisterTimerHandler("Communicator_Queue", "ProcessMessageQueue", self)
  Apollo.RegisterTimerHandler("Communicator_QueueShutdown", "OnTimerQueueShutdown", self)
  Apollo.RegisterTimerHandler("Communicator_Setup", "OnTimerSetup", self)
  Apollo.RegisterTimerHandler("Communicator_TraitQueue", "ProcessTraitQueue", self)
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

function Communicator:OnRestore(eLevel, tData)
	if (tData ~= nil and eLevel == GameLib.CodeEnumAddonSaveLevel.Character) then
		local tLocal = tData.localData
		self.tLocalTraits = tLocal or {}
	elseif (tData ~= nil and eLevel == GameLib.CodeEnumAddonSaveLevel.Realm) then
		self.tCachedPlayerData = tData.cachedData or {}	
	end
end

function Communicator:OnTimerSetup()
  if(GameLib.GetPlayerUnit() == nil) then
    Apollo.CreateTimer("Communicator_Setup", 1, false)
    return
  end
  
  -- Configure the Channel according new ICCommLib standards
  self.chnCommunicator = ICCommLib.JoinChannel("Communicator", ICCommLib.CodeEnumICCommChannelType.Global)
  self.chnCommunicator:SetJoinResultFunction("OnSyncChannelJoined", self)
  self.chnCommunicator:IsReady()
  self.chnCommunicator:SetReceivedMessageFunction("OnSyncMessageReceived", self)
end

-- Constructs a new Message structure, that is a reply on the provided Message.
-- The tPayload is set as the payload of the response.
--
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

-- Returns the name of the origin, namely our player character.
-- The function checks if the Player is defined and returns the
-- name of the Player.
-- If the Player cannot be loaded, the current value or nil is returned.
function Communicator:GetOriginName()
  local myUnit = GameLib.GetPlayerUnit()
  
  if (myUnit ~= nil) then
    self.strPlayerName = myUnit:GetName()
  end
  
  return self.strPlayerName
end

-- Sets the debug level for Communicator, controlling the
-- output level of the Library.
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

-- Writes the provided log message into the chat, using a controlled structure.
-- The provided level is used to check whether we're supposed to actually write the 
-- log message.
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

-- Returns the provided trait of the specified target.
-- If the target is not yet stored in the Cache, we fetch it and return it
-- when it becomes avaialble.
-- If the call fails, nil is returned instead.
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

-- This function is called on a regular basis and processes the messages currently stored in
-- the TraitQueue.
function Communicator:ProcessTraitQueue()
  -- Loop over every message in the Queue.
  for strTarget, aRequests in pairs(self.tPendingPlayerTraitRequests) do
    self:Log(Communicator.Debug_Comm, "Sending: " .. table.getn(aRequests) .. " queued trait requests to " .. strTarget)
    
    local mMessage = Message:new()
    
    -- Construct the message using the information in the Queue.
    mMessage:SetDestination(strTarget)
    mMessage:SetCommand("get")
    mMessage:SetPayload(aRequests)
    
    -- Send the message to the target, and clear it from the Queue.
    self:SendMessage(mMessage)
    self.tPendingPlayerTraitRequests[strTarget] = nil
  end
end

-- Fetches the provided trait from the specified target.
-- The information is read from the local cache, but when the cache does not contain any
-- information, a request is made to the target to provide the information.
function Communicator:FetchTrait(strTarget, strTraitName)
  -- If no target is provided, or we're fetching our own traits, then check
  -- the localTraits cache for the information and return it when avaialble.
  if (strTarget == nil or strTarget == self:GetOriginName()) then
    local tTrait = self.tLocalTraits[strTraitName] or {}
    self:Log(Communicator.Debug_Access, string.format("Fetching own %s: (%d) %s", strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    return tTrait.data, tTrait.revision
  else
    -- Check the local cached player data for the information
    local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
    local tTrait = tPlayerTraits[strTraitName] or {}
    local nTTL = Communicator.TTL_Trait
    
    self:Log(Communicator.Debug_Access, string.format("Fetching %s's %s: (%d) %s", strTarget, strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    
    -- Check if the TTL is set correctly, and do so if not.    
    if((tTrait.revision or 0) == 0) then nTTL = 10 end
    
    -- If the trait could not be found, or it has exceeded it's TTL, then
    -- prepare to request the information again from the target.
    -- We do this by setting the query in the request queue and fire a timer to
    -- process it in the background.
    if(tTrait == nil or (os.time() - (tTrait.time or 0)) > nTTL) then
      tTrait.time = os.time()
      tPlayerTraits[strTraitName] = tTrait
      self.tCachedPlayerData[strTarget] = tPlayerTraits
      
      local tPendingPlayerQuery = self.tPendingPlayerTraitRequests[strTarget] or {}
      local tRequest = { trait = strTraitName, revision = tTrait.revision or 0 }
      
	  self:Log(Communicator.Debug_Access, string.format("Building up query to retrieve %s's %s:", strTarget, strTraitName))
      table.insert(tPendingPlayerQuery, tRequest)
      self.tPendingPlayerTraitRequests[strTarget] = tPendingPlayerQuery
      Apollo.CreateTimer("Communicator_TraitQueue", 1, false)
    end
    
    return tTrait.data, tTrait.revision
  end
end

-- Caches the provided trait, with it's value and revision in the cache, using the name of
-- the target as identifier.
function Communicator:CacheTrait(strTarget, strTrait, data, nRevision)
  if(strTarget == nil or strTarget == self:GetOriginName()) then
    self.tLocalTraits[strTrait] = { data = data, revision = nRevision }
    self:Log(Communicator.Debug_Access, string.format("Caching own %s: (%d) %s", strTrait, nRevision or 0, tostring(data)))
    Event_FireGenericEvent("Communicator_TraitChanged", { player = self:GetOriginName(), trait = strTrait, data = data, revision = nRevision })
  else
    local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
    
    if(nRevision ~= 0 and tPlayerTraits.revision == nRevision) then
      tPlayerTraits.time = os.time()
      return
    end
    
    if(data == nil) then return end
    
    tPlayerTraits[strTrait] = { data = data, revision = nRevision, time = os.time() }
    self.tCachedPlayerData[strTarget] = tPlayerTraits
    self:Log(Communicator.Debug_Access, string.format("Caching %s's %s: (%d) %s", strTarget, strTrait, nRevision or 0, tostring(data)))
    Event_FireGenericEvent("Communicator_TraitChanged", { player = strTarget, trait = strTrait, data = data, revision = nRevision })
  end
end  

function Communicator:SetLocalTrait(strTrait, data)
  local value, revision = self:FetchTrait(nil, strTrait)
  
  if(value == data) then return end
  if(strTrait == "state" or strTrait == "rpflag") then revision = 0 else revision = (revision or 0) + 1 end
  self:CacheTrait(nil, strTrait, data, revision)
end

function Communicator:GetLocalTrait(strTrait)
  return self:FetchTrait(nil, strTrait)
end

function Communicator:QueryVersion(strTarget)
  if(strTarget == nil or strTarget == self:GetOriginName()) then
    local aProtocols = {}
    
    for strAddonProtocol, _ in pairs(self.tApiProtocolHandlers) do
      table.insert(aProtocols, strAddonProtocol)
    end
    
    return Communicator.Version, aProtocols
  end
  
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  local tVersionInfo = tPlayerTraits["__rpVersion"] or {}
  local nLastTime = self:TimeSinceLastAddonProtocolCommand(strTarget, nil, "version")
  
  if(nLastTime < Communicator.TTL_Version) then
    return tVersionInfo.version, tVersionInfo.addons
  end
  
  self:MarkAddonProtocolCommand(strTarget, nil, "version")
  self:Log(Communicator.Debug_Access, string.format("Fetching %s's version", strTarget))
  
  if(tVersionInfo.version == nil or (os.time() - (tVersionInfo.time or 0) > Communicator.TTL_Version)) then
    local mMessage = Message:new()
    
    mMessage:SetDestination(strTarget)
    mMessage:SetType(Message.Type_Request)
    mMessage:SetCommand("version")
    mMessage:SetPayload({""})
    self:SendMessage(mMessage)
  end
  
  return tVersionInfo.version, tVersionInfo.addons
end

function Communicator:StoreVersion(strTarget, strVersion, aProtocols)
  if(strTarget == nil or strVersion == nil) then return end
  
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  tPlayerTraits["__rpVersion"] = { version = strVersion, protocols = aProtocols, time = os.time() }
  self.tCachedPlayerData[strTarget] = tPlayerTraits
  
  self:Log(Communicator.Debug_Access, string.format("Storing %s's version: %s", strTarget, strVersion))
  Event_FireGenericEvent("Communicator_VersionUpdated", { player = strTarget, version = strVersion, protocols = aProtocols })
end

function Communicator:GetAllTraits(strTarget)
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  self:Log(Communicator.Debug_Access, string.format("Fetching %s's full trait set (version: %s)", strTarget, Communicator.Version))
  
  if(self:TimeSinceLastAddonProtocolCommand(strTarget, nil, "getall") > Communicator.TTL_GetAll) then
    local mMessage = Message:new()
    
    mMessage:SetDestination(strTarget)
    mMessage:SetType(Message.Type_Request)
    mMessage:SetCommand("getall")
    
    self:SendMessage(mMessage)
    self:MarkAddonProtocolCommand(strTarget, nil, "getall")
  end
  
  local tResult = {}
  
  for key, data in pairs(tPlayerTraits) do
    if(key:sub(1,2) ~= "__") then
      tResult[key] = data.data
    end
  end
  
  return tResult
end

function Communicator:StoreAllTraits(strTarget, tPlayerTraits)
  self:Log(Communicator.Debug_Access, string.format("Storing new trait cache for %s", strTarget))
  self.tCachedPlayerData[strTarget] = tPlayerTraits
  
  local tResult = {}
  
  for key, data in pairs(tPlayerTraits) do
    if(key:sub(1,2) ~= "__") then
      tResult[key] = data.data
    end
  end
  
  Event_FireGenericEvent("Communicator_PlayerUpdated", { player = strTarget, traits = tResult })
end

function Communicator:TimeSinceLastAddonProtocolCommand(strTarget, strAddonProtocol, strCommand)
  local strCommandId = string.format("%s:%s:%s", strTarget, strAddonProtocol or "base", strCommand)
  local nLastTime = self.tFloodPrevent[strCommandId] or 0
  
  return (os.time() - nLastTime)
end

function Communicator:MarkAddonProtocolCommand(strTarget, strAddonProtocol, strCommand)
  local strCommandId = string.format("%s:%s:%s", strTarget, strAddonProtocol or "base", strCommand)
  self.tFloodPrevent[strCommandId] = os.time()
end
  
function Communicator:OnSyncMessageReceived(channel, strMessage, idMessage)
  local mMessage = Message:new()
  mMessage:Deserialize(strMessage)
  
  if(tonumber(mMessage:GetProtocolVersion() or 0) > Message.ProtocolVersion) then
    Print("Communicator: Warning :: Received packet for unrecognized version " .. mMessage:GetProtocolVersion())
    return
  end
  
  if(mMessage:GetDestination() == self:GetOriginName()) then
    self:ProcessMessage(mMessage)
  end
end

-- Processes the provided message, parsing the contents and taking the required
-- action based on the data stored inside.
function Communicator:ProcessMessage(mMessage)
  self:Log(Communicator.Debug_Comm, "Processing Message")
  -- Check if we're dealing with an error message.
  if(mMessage:GetType() == Message.Type_Error) then
    local tData = self.tOutGoingRequests[mMessage:GetSequence()] or {}
    
    if(tData.handler) then
      tData.handler(mMessage)
      self.tOutGoingRequests[mMessage:GetSequence()] = nil
      return
    end
  end
  
  -- If no AddonProtocol has been defined for the message, then look at the data
  -- that is beeing provided and try to parse it.
  if(mMessage:GetAddonProtocol() == nil) then
    local eType = mMessage:GetType()
    local tPayload = mMessage:GetPayload() or {}
  
    -- This is something for Communicator itself.
    if(eType == Message.Type_Request) then
      if(mMessage:GetCommand() == "get") then
        local aReplies = {}
        
        for _, tTrait in ipairs(tPayload) do
          local data, revision = self:FetchTrait(nil, tTrait.trait or "")
          
          if(data ~= nil) then
            local tResponse = { trait = tTrait.trait, revision = revision }
            
            if(tPayload.revision == 0 or revision ~= tPayload.revision) then
              tResponse.data = data
            end
            
            table.insert(aReplies, tResponse)
          else
            table.insert(aReplies, { trait = tTrait.trait, revision = 0 })
          end
        end
        
        local mReply = self:Reply(mMessage, aReplies)
        self:SendMessage(mReply)
      elseif(mMessage:GetCommand() == "version") then
        local aProtocols = {}
        
        for strAddonProtocol, _ in pairs(self.tApiProtocolHandlers) do
          table.insert(aProtocols, strAddonProtocol)
        end
        
        local mReply = self:Reply(mMessage, { version = Communicator.Version, protocols = aProtocols })
        self:SendMessage(mReply)
      elseif(mMessage:GetCommand() == "getall") then
        local mReply = self:Reply(mMessage, self.tLocalTraits)
        self:SendMessage(mReply)
      else
        local mReply = self:Reply(mMessage, { error = self.Error_UnimplementedCommand })
        mReply:SetType(Message.Type_Error)
        self:SendMessage(mReply)
      end
    elseif(eType == Message.Type_Reply) then
      if(mMessage:GetCommand() == "get") then
        for _, tTrait in ipairs(tPayload) do
          self:CacheTrait(mMessage:GetOrigin(), tTrait.trait, tTrait.data, tTrait.revision)
        end
      elseif(mMessage:GetCommand() == "version") then
        self:StoreVersion(mMessage:GetOrigin(), tPayload.version, tPayload.protocols)
      elseif(mMessage:GetCommand() == "getall") then
        self:StoreAllTraits(mMessage:GetOrigin(), tPayload)
      end
    elseif(eType == Message.Type_Error) then
      if(mMessage:GetCommand() == "getall") then
        Event_FireGenericEvent("Communicator_PlayerUpdated", { player = mMessage:GetOrigin(), unsupported = true })
      end
    end
  else
    local aAddon = self.tApiProtocolHandlers[mMessage:GetAddonProtocol()]
    
    if(aAddon ~= nil or table.getn(aAddon) == 0) then
      for _, fHandler in ipairs(aAddon) do
        fHandler(mMessage)
      end
    elseif(mMessage:GetType() == Message.Type_Request) then
      local mError = self:Reply(mMessage, { type = Communicator.Error_UnimplementedProtocol })
      mError:SetType(Message.Type_Error)
      self:SendMessage(mError)
    end
  end
    
  if(mMessage:GetType() == Message.Type_Reply or mMessage:GetType() == Message.Type_Error) then
    self.tOutGoingRequests[mMessage:GetSequence()] = nil
  end
end

function Communicator:SendMessage(mMessage, fCallback)
  if(mMessage:GetDestination() == self:GetOriginName()) then
    return
  end
  
  if(mMessage:GetType() ~= Message.Type_Error and mMessage:GetType() ~= Message.Type_Reply) then
    self.nSequenceCounter = tonumber(self.nSequenceCounter or 0) + 1
    mMessage:SetSequence(self.nSequenceCounter)
  end
  
  self.tOutGoingRequests[mMessage:GetSequence()] = { message = mMessage, handler = fCallback, time = os.time() }
  self.qPendingMessages:Push(mMessage)
  if(not self.bQueueProcessRunning) then
    self.bQueueProcessRunning = true
    Apollo.CreateTimer("Communicator_Queue", 0.5, true)
  end
end

function Communicator:ChannelForPlayer()
  local channel = self.chnCommunicator
  
  if(channel == nil) then
    channel = ICCommLib.JoinChannel("Communicator", ICCommLib.CodeEnumICCommChannelType.Global)
    channel:SetJoinResultFunction("OnSyncChannelJoined", self)
    channel:IsReady()
    channel:SetReceivedMessageFunction("OnSyncMessageReceived", self)
    self.chnCommunicator = channel
  end
  
  return channel
end
    
function Communicator:OnTimerQueueShutdown()
  Apollo.StopTimer("Communicator_Queue")
  self.bQueueProcessRunning = false
end

function Communicator:ProcessMessageQueue()
  if(self.qPendingMessages:GetSize() == 0) then
    Apollo.CreateTimer("Communicator_QueueShutDown", 0.1, false)
    return
  end
  
  local mMessage = self.qPendingMessages:Pop()
  local channel = self:ChannelForPlayer()
  
  if(channel.SendPrivateMessage ~= nil) then
    channel:SendPrivateMessage(mMessage:GetDestination(), mMessage:Serialize())
  else
    channel:SendMessage(mMessage:Serialize())
  end
  
  if(not self.bTimeoutRunning) then
    self.bTimeoutRunning = true
    Apollo.CreateTimer("Communicator_Timeout", 15, true)
  end
end
    
function Communicator:OnTimerTimeoutShutdown()
  Apollo.StopTimer("Communicator_Timeout")
  self.bTimeoutRunning = false
end

function Communicator:OnTimerTimeout()
  local nNow = os.time()
  local nOutgoingCount = 0
  
  for nSequence, tData in pairs(self.tOutGoingRequests) do
    if(nNow - tData.time > Communicator.TTL_Packet) then
      local mError = self:Reply(tData.message, { error = Communicator.Error_RequestTimedOut, destination = tData.message:GetDestination(), localError = true })
      mError:SetType(Message.Type_Error)
      self:ProcessMessage(mError)
      self.tOutGoingRequests[nSequence] = nil
    else
      nOutgoingCount = nOutgoingCount + 1
    end
  end
  
  for strCommandId, nLastTime in pairs(self.tFloodPrevent) do
    if((nNow - nLastTime) > Communicator.TTL_Flood) then
      self.tFloodPrevent[strCommandId] = nil
    end
  end
  
  for strPlayerName, tChannelRecord in pairs(self.tCachedPlayerChannels) do
    if((nNow - tChannelRecord.time or 0) > Communicator.TTL_Channel) then
      self.tCachedPlayerChannels[strPlayerName] = nil
    end
  end
  
  if(nOutgoingCount == 0) then
    Apollo.CreateTimer("Communicator_TimeoutShutdown", 0.1, false)
  end
end

function Communicator:OnTimerCleanupCache()
  local nNow = os.time()
  
  for strPlayerName, tRecord in pairs(self.tCachedPlayerData) do
    for strParam, tTrait in pairs(tRecord) do
      if(nNow - tTrait.time > Communicator.TTL_CacheDie) then
        tRecord[strParam] = nil
      end
    end
    
    local nCount = 0
    
    for strParam, tTrait in pairs(tRecord) do
      nCount = nCount + 1
    end
    
    if(nCount == 0) then
      self.tCachedPlayerData[strPlayerName] = nil
    end
    
    -- Can't the above loop + if-statement not be shortened into:
    --
    -- if(#tRecord == 0) then
    --  self.tCachedPlayerData[strPlayerName] = nil
    -- end
  end
end

function Communicator:Stats()
  local nLocalTraits = 0
  local nPlayers = 0
  local nCachedTraits = 0
  
  for strTrait, tRecord in pairs(self.tLocalTraits) do
    nLocalTraits = nLocalTraits + 1
  end
  
  for strPlayer, tRecord in pairs(self.tCachedPlayerData) do
    nPlayers = nPlayers + 1
    
    for strParam, tValue in pairs(tRecord) do
      nCachedTraits = nCachedTraits + 1
    end
  end
  
  return nLocalTraits, nCachedTraits, nPlayers
end

function Communicator:GetCachedPlayerList()
  local tCachedPlayers = {}
 
  for strPlayerName, _ in pairs(self.tCachedPlayerData) do
    table.insert(tCachedPlayers, strPlayerName)
  end
  
  return tCachedPlayers
end

function Communicator:ClearCachedPlayerList()
  for strPlayerName, _ in pairs(self.tCachedPlayerData) do
    if(strPlayerName ~= self:GetOriginName()) then
      self.tCachedPlayerData[strPlayerName] = nil
    end
  end
end

function Communicator:CacheAsTable()
  return { locaData = self.tLocalTraits, cachedData = self.tCachedPlayerData }
end

function Communicator:LoadFromTable(tData)
  self.tLocalTraits = tData.localData or {}
  self.tCachedPlayerData = tData.cachedData or {}
  self:CleanupCache()
end

function Communicator:RegisterAddonProtocolHandler(strAddonProtocol, fHandler)
  local aHandlers = self.tApiProtocolHandlers[strAddonProtocol] or {}
  table.insert(aHandlers, fHandler)
  self.tApiProtocolHandlers[strAddonProtocol] = aHandlers
end

local CommunicatorInst = Communicator:new()
CommunicatorInst:Init()