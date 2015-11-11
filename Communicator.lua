---------------------------------------------------------------------------------------------------
--                                          Communicator
--
-- This library is a wrapper around the ICCommLib in WildStar, and provides an interface for
-- Roleplay Addons that can be used to transfer information between the both of them.
-- The Libary can also be used by different Addons if desired to transfer information, this just
-- requires some modifications to the transfer protocol.
---------------------------------------------------------------------------------------------------
require "ICCommLib"
require "ICComm"

---------------------------------------------------------------------------------------------------
-- Package Configuration
---------------------------------------------------------------------------------------------------
local MAJOR, MINOR = "Communicator", 1
local APkg = Apollo.GetPackage(MAJOR)

if APkg and (APkg.nVersion or 0) >= MINOR then
  return
end

--local Communicator = APkg and APkg.tPackage or {}
local Communicator = {}
local Message = Apollo.GetPackage("Chua-Message").tPackage
local Queue = Apollo.GetPackage("Chua-MessageQueue").tPackage

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------
Communicator.CodeEnumError = {
  UnimplementedProtocol = 1,
  UnimplementedCommand = 2,
  RequestTimedOut = 3
}
Communicator.CodeEnumDebugLevel = {
  Debug = 1,
  Comm = 2,
  Access = 3,
}
Communicator.CodeEnumTTL = {
  Trait = 120,
  Version = 300,
  Flood = 30,
  Channel = 60,
  Packet = 15,
  GetAll = 120,
  CacheDie = 604800
}
Communicator.CodeEnumTrait = {
  Name = "full_name",
  NameAndTitle = "title",
  RPFlag = "rp_flag",
  RPState = "rp_state",
  Description = "description",
  Biography = "bio",
  All = "getall"
}

---------------------------------------------------------------------------------------------------
-- Constructor
---------------------------------------------------------------------------------------------------
function Communicator:new(o)
  o = o or {}
  
  setmetatable(o, self)
  
  self.__index = self 
  
  -- Initialize our internal state
  o.tApiProtocolHandlers = {}
  o.tLocalTraits = {}
  o.tOutGoingRequests = {}
  o.tFloodPrevent = {}
  o.tCachedPlayerData = {}
  o.tPendingPlayerTraitRequests = {}
  o.tCachedPlayerChannels = {}
  o.bTimeoutRunning = false
  o.nSequenceCounter = 0
  o.nDebugLevel = 0
  o.qPendingMessages = Queue:new()
  o.kstrRPStateStrings = {
    "In-Character, Not Available for RP",
    "Available for RP",
    "In-Character, Available for RP",
    "In a Private Scene (Temporarily OOC)",
    "In a Private Scene",
    "In an Open Scene (Temporarily OOC)",
    "In an Open Scene" 
  }
  o.strPlayerName = nil
  
  return o
end

---------------------------------------------------------------------------------------------------
--                                        Public API
--                                        
--  The functions below are part of the public API of Communicator.
--  You can safely call these functions without disrupting the internal workings of the Addon
--
--  Refer to the README.md for actual explanation of each function and it's functionality.
---------------------------------------------------------------------------------------------------
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

function Communicator:Setup(strAddon)
  self:Internal_SetupEventHandlers()
  self:Internal_SetupChannel(strAddon)
  self:Internal_SetupTimers()
end

function Communicator:ChannelForPlayer()
  if self.strAddon == nil then
    error("No Addon has been registered with Communicator")
  end
  
  if self.chnChannel == nil then
    self:Internal_SetupChannel(self.strAddon)
  end
  
  return self.chnChannel
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
    if strPlayerName ~= self:GetOriginName() then
      self.tCachedPlayerData[strPlayerName] = nil
    end
  end
end

function Communicator:GetOriginName()
  local unitPlayer = GameLib.GetPlayerUnit()
  
  if unitPlayer ~= nil then
    self.strPlayerName = unitPlayer:GetName()
  end
  
  return self.strPlayerName
end

function Communicator:SetDebugLevel(eLevel)
  self.nDebugLevel = eLevel
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
  if nLevel > self.nDebugLevel then
    return 
  end
  
  Print("Communicator: " .. strLog)
end

function Communicator:FlagsToString(nState)
  return self.kstrRPStateStrings[nState] or "Not Available for RP"
end

function Communicator:EscapePattern(strPattern)
  return strPattern:gsub("(%W)", "%%%1")
end

function Communicator:TruncateString(strText, nLength)
  if(strText == nil) then
    return nil
  end
  
  if strText:len() <= nLength then
    return strText 
  end
  
  local strResult = strText:sub(1, nLength)
  local nSpacePos = strResult:find(" ", -1)
  
  if nSpacePos ~= nil then
    strResult = strResult:sub(1, nSpacePos - 1) .. "..."
  end
  
  return strResult
end

function Communicator:GetTrait(strTarget, strTrait)
  local strResult = nil
  
  if(strTrait == Communicator.CodeEnumTrait.Name) then
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Name) or strTarget
  elseif(strTrait == Communicator.CodeEnumTrait.NameAndTitle) then
    local strName = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Name)
    
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.NameAndTitle)
    
    if(strResult == nil) then
      strResult = strName
    else
      local nStart,nEnd = strResult:find("#name#")
      
      if(nStart ~= nil) then
        strResult = strResult:gsub("#name#", self:EscapePattern(strName or strTarget))
      else
        strResult = strResult.." "..(strName or strTarget)
      end
    end
  elseif(strTrait == Communicator.CodeEnumTrait.Description) then
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Description)
   
    if strResult ~= nil then
      strResult = self:TruncateString(strResult, Communicator.MaxLength)
    end
  elseif(strTrait == Communicator.CodeEnumTrait.RPState) then
    local rpFlags = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.RPState) or 0
    
    strResult = self:FlagsToString(rpFlags)
  elseif(strTrait == Communicator.CodeEnumTrait.Biography) then
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Biography)
  else
    strResult = self:FetchTrait(strTarget, strTrait)
  end
  
  return strResult
end

function Communicator:SetRPFlag(flag, bSet)
  local nState, nRevision = self:GetLocalTrait(Communicator.CodeEnumTrait.RPFlag)
  nState = self:SetBitFlag(flag, bSet)
  self:SetLocalTrait(Communicator.CodeEnumTrait.RPFlag, nState)
end

function Communicator:FetchTrait(strTarget, strTraitName)
  if(strTarget == nil or strTarget == self:GetOriginName()) then
    local tTrait = self.tLocalTraits[strTraitName] or {}
    
    self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Fetching own %s: (%d) %s", strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    
    return tTrait.data, tTrait.revision
  else
    local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
    local tTrait = tPlayerTraits[strTraitName] or {}
    local nTTL = Communicator.CodeEnumTTL.Trait
    
    self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Fetching %s's %s: (%d) %s", strTarget, strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    
    -- Check if the TTL is set correctly, and do so if not.    
    if ((tTrait.revision or 0) == 0) then
      nTTL = 10 
    end
    
    if(tTrait == nil or (os.time() - (tTrait.time or 0)) > nTTL) then
      tTrait.time = os.time()
      tPlayerTraits[strTraitName] = tTrait
      self.tCachedPlayerData[strTarget] = tPlayerTraits
      
      local tPendingPlayerQuery = self.tPendingPlayerTraitRequests[strTarget] or {}
      local tRequest = { trait = strTraitName, revision = tTrait.revision or 0 }
      
      self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Building up query to retrieve %s's %s:", strTarget, strTraitName))
      
      table.insert(tPendingPlayerQuery, tRequest)
      
      self.tPendingPlayerTraitRequests[strTarget] = tPendingPlayerQuery
      
      Apollo.CreateTimer("Communicator_TraitQueue", 1, false)
    end
    
    return tTrait.data, tTrait.revision
  end
end

function Communicator:GetTrait(strTarget, strTrait)
  local strResult = nil
  
  if(strTrait == Communicator.CodeEnumTrait.Name) then
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Name) or strTarget
  elseif(strTrait == Communicator.CodeEnumTrait.NameAndTitle) then
    local strName = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Name)
    
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.NameAndTitle)
    
    if(strResult == nil) then
      strResult = strName
    else
      local nStart,nEnd = strResult:find("#name#")
      
      if(nStart ~= nil) then
        strResult = strResult:gsub("#name#", self:EscapePattern(strName or strTarget))
      else
        strResult = strResult.." "..(strName or strTarget)
      end
    end
  elseif(strTrait == Communicator.CodeEnumTrait.Description) then
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Description)
   
    if strResult ~= nil then
      strResult = self:TruncateString(strResult, Communicator.MaxLength)
    end
  elseif(strTrait == Communicator.CodeEnumTrait.RPState) then
    local rpFlags = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.RPState) or 0
    
    strResult = self:FlagsToString(rpFlags)
  elseif(strTrait == Communicator.CodeEnumTrait.Biography) then
    strResult = self:FetchTrait(strTarget, Communicator.CodeEnumTrait.Biography)
  else
    strResult = self:FetchTrait(strTarget, strTrait)
  end
  
  return strResult
end

function Communicator:SetRPFlag(flag, bSet)
  local nState, nRevision = self:GetLocalTrait(Communicator.CodeEnumTrait.RPFlag)
  nState = self:SetBitFlag(flag, bSet)
  self:SetLocalTrait(Communicator.CodeEnumTrait.RPFlag, nState)
end

function Communicator:OnTimerTraitQueue()
  -- Loop over every message in the Queue.
  for strTarget, aRequests in pairs(self.tPendingPlayerTraitRequests) do
    self:Log(Communicator.CodeEnumDebugLevel.Comm, "Sending: " .. table.getn(aRequests) .. " queued trait requests to " .. strTarget)
    
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

function Communicator:FetchTrait(strTarget, strTraitName)
  -- If no target is provided, or we're fetching our own traits, then check
  -- the localTraits cache for the information and return it when avaialble.
  if(strTarget == nil or strTarget == self:GetOriginName()) then
    local tTrait = self.tLocalTraits[strTraitName] or {}
    
    self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Fetching own %s: (%d) %s", strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    
    return tTrait.data, tTrait.revision
  else
    -- Check the local cached player data for the information
    local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
    local tTrait = tPlayerTraits[strTraitName] or {}
    local nTTL = Communicator.CodeEnumTTL.Trait
    
    self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Fetching %s's %s: (%d) %s", strTarget, strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    
    -- Check if the TTL is set correctly, and do so if not.    
    if ((tTrait.revision or 0) == 0) then
      nTTL = 10 
    end
    
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
      
      self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Building up query to retrieve %s's %s:", strTarget, strTraitName))
      
      table.insert(tPendingPlayerQuery, tRequest)
      
      self.tPendingPlayerTraitRequests[strTarget] = tPendingPlayerQuery
      
      Apollo.CreateTimer("Communicator_TraitQueue", 1, false)
    end
    
    return tTrait.data, tTrait.revision
  end
end

function Communicator:CacheTrait(strTarget, strTrait, data, nRevision)
  if strTarget == nil or strTarget == self:GetOriginName() then
    self:Internal_CacheLocalTrait(strTrait, data, nRevision)
  else
    self:Internal_CachePlayerTrait(strTarget, strTrait, data, nRevision)
  end
end  

function Communicator:SetLocalTrait(strTrait, data)
  local value, revision = self:FetchTrait(nil, strTrait)
  
  if value == data then
    return
  end
  
  if strTrait == Communicator.CodeEnumTrait.RPState or strTrait == Communicator.CodeEnumTrait.RPFlag then
    revision = 0 
  else
    revision = (revision or 0) + 1 
  end
  
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
  
  if nLastTime < Communicator.CodeEnumTTL.Version then
    return tVersionInfo.version, tVersionInfo.addons
  end
  
  self:MarkAddonProtocolCommand(strTarget, nil, "version")
  
  if tVersionInfo.version == nil or (os.time() - (tVersionInfo.time or 0) > Communicator.CodeEnumTTL.Version) then
    local mMessage = Message:new()
    
    mMessage:SetDestination(strTarget)
    mMessage:SetType(Message.CodeEnumType.Request)
    mMessage:SetCommand("version")
    mMessage:SetPayload({""})
    
    self:SendMessage(mMessage)
  end
  
  return tVersionInfo.version, tVersionInfo.addons
end

function Communicator:StoreVersion(strTarget, strVersion, aProtocols)
  if strTarget == nil or strVersion == nil then
    return 
  end
  
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  tPlayerTraits["__rpVersion"] = { version = strVersion, protocols = aProtocols, time = os.time() }
  self.tCachedPlayerData[strTarget] = tPlayerTraits
  
  self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Storing %s's version: %s", strTarget, strVersion))
  Event_FireGenericEvent("Communicator_VersionUpdated", { player = strTarget, version = strVersion, protocols = aProtocols })
end

function Communicator:GetAllTraits(strTarget)
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Fetching %s's full trait set (version: %s)", strTarget, Communicator.Version))
  
  if(self:TimeSinceLastAddonProtocolCommand(strTarget, nil, Communicator.CodeEnumTrait.All) > Communicator.CodeEnumTTL.GetAll) then
    local mMessage = Message:new()
    
    mMessage:SetDestination(strTarget)
    mMessage:SetType(Message.CodeEnumType.Request)
    mMessage:SetCommand(Communicator.CodeEnumTrait.All)
    
    self:SendMessage(mMessage)
    self:MarkAddonProtocolCommand(strTarget, nil, Communicator.CodeEnumTrait.All)
  end
  
  local tResult = {}
  
  for key, data in pairs(tPlayerTraits) do
    if key:sub(1,2) ~= "__" then
      tResult[key] = data.data
    end
  end
  
  return tResult
end

function Communicator:StoreAllTraits(strTarget, tPlayerTraits)
  self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Storing new trait cache for %s", strTarget))
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
---------------------------------------------------------------------------------------------------
--                                    Private API
--                                    
--  The functions below are part of the private API of Communicator.
--  They should not be called directly by any Addon or Script as they can potentially disrupt the
--  behaviour and internal workings of Communicator.
---------------------------------------------------------------------------------------------------
function Communicator:Internal_ProcessMessage(mMessage)
  if(mMessage:GetType() == Message.CodeEnumType.Error) then    
    local tData = self.tOutGoingRequests[mMessage:GetSequence()] or {}
    
    if tData.handler then
      tData.handler(mMessage)
      self.tOutGoingRequests[mMessage:GetSequence()] = nil
      return
    end
  end
  
  if(mMessage:GetAddonProtocol() == nil) then    
    local eType = mMessage:GetType()
    local tPayload = mMessage:GetPayload() or {}
  
    if(eType == Message.CodeEnumType.Request) then
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
        
        local mReply = self:Internal_Reply(mMessage, aReplies)
        
        self:Internal_SendMessage(mReply)
      elseif(mMessage:GetCommand() == "version") then              
        local aProtocols = {}
        
        for strAddonProtocol, _ in pairs(self.tApiProtocolHandlers) do
          table.insert(aProtocols, strAddonProtocol)
        end
        
        local mReply = self:Internal_Reply(mMessage, { version = Communicator.Version, protocols = aProtocols })
        
        self:Internal_SendMessage(mReply)
      elseif(mMessage:GetCommand() == Communicator.CodeEnumTrait.All) then        
        local mReply = self:Internal_Reply(mMessage, self.tLocalTraits)
        
        self:Internal_SendMessage(mReply)
      else        
        local mReply = self:Internal_Reply(mMessage, { error = self.CodeEnumError.UnimplementedCommand })
        
        mReply:SetType(Message.CodeEnumType.Error)
        
        self:Internal_SendMessage(mReply)
      end
    elseif(eType == Message.CodeEnumType.Reply) then
      if(mMessage:GetCommand() == "get") then
        for _, tTrait in ipairs(tPayload) do
          self:CacheTrait(mMessage:GetOrigin(), tTrait.trait, tTrait.data, tTrait.revision)
        end
      elseif(mMessage:GetCommand() == "version") then
        self:StoreVersion(mMessage:GetOrigin(), tPayload.version, tPayload.protocols)
      elseif(mMessage:GetCommand() == Communicator.CodeEnumTrait.All) then
        self:StoreAllTraits(mMessage:GetOrigin(), tPayload)
      end
    elseif(eType == Message.CodeEnumType.Error) then
      if(mMessage:GetCommand() == Communicator.CodeEnumTrait.All) then
        Event_FireGenericEvent("Communicator_PlayerUpdated", { player = mMessage:GetOrigin(), unsupported = true })
      end
    end
  else    
    local aAddon = self.tApiProtocolHandlers[mMessage:GetAddonProtocol()]
    
    if aAddon ~= nil or table.getn(aAddon) == 0 then
      for _, fHandler in ipairs(aAddon) do
        fHandler(mMessage)
      end
    elseif mMessage:GetType() == Message.CodeEnumType.Request then
      local mError = self:Internal_Reply(mMessage, { type = Communicator.CodeEnumError.UnimplementedProtocol })
      
      mError:SetType(Message.CodeEnumType.Error)
      
      self:Internal_SendMessage(mError)
    end
  end
    
  if mMessage:GetType() == Message.CodeEnumType.Reply or mMessage:GetType() == Message.CodeEnumType.Error then
    self.tOutGoingRequests[mMessage:GetSequence()] = nil
  end
end

function Communicator:Internal_SendMessage(mMessage, fCallback)
  if mMessage:GetDestination() == self:GetOriginName() then
    return
  end
  
  if mMessage:GetType() ~= Message.CodeEnumType.Error and mMessage:GetType() ~= Message.CodeEnumType.Reply then
    self.nSequenceCounter = tonumber(self.nSequenceCounter or 0) + 1
    mMessage:SetSequence(self.nSequenceCounter)
  end
  
  self.tOutGoingRequests[mMessage:GetSequence()] = { message = mMessage, handler = fCallback, time = os.time() }
  self.qPendingMessages:Push(mMessage)
  
  if not self.bQueueProcessRunning then
    self.bQueueProcessRunning = true
    Apollo.CreateTimer("Communicator_Queue", 0.5, true)
  end
end

function Communicator:Internal_CacheLocalTrait(strTrait, tData, nRevision)
  if strTrait == nil then return end
  
  self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Caching own %s: (%d) %s", strTrait, nRevision or 0, tostring(tData)))
  
  self.tLocalTraits[strTrait] = {
    data = tData,
    revision = nRevision
  }
  
  Event_FireGenericEvent("Communicator_TraitChanged", { player = self:GetOriginName(), trait = strTrait, data = data, revision = nRevision })  
end

function Communicator:Internal_CachePlayerTrait(strTarget, strTrait, tData, nRevision)
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  
  if(nRevision ~= 0 and tPlayerTraits.revision == nRevision) then
    tPlayerTraits.time = os.time()
    return
  end
  
  if(tData == nil) then return end
  
  self.tCachedPlayerData[strTarget] = {
    data = tData,
    revision = nRevision,
    time = os.time()
  }
  
  self:Log(Communicator.CodeEnumDebugLevel.Access, string.format("Caching %s's %s: (%d) %s", strTarget, strTrait, nRevision or 0, tostring(tData)))
  Event_FireGenericEvent("Communicator_TraitChanged", { player = strTarget, trait = strTrait, data = tData, revision = nRevision })
end

function Communicator:CacheAsTable()
  return { localData = self.tLocalTraits, cachedData = self.tCachedPlayerData }
end

function Communicator:LoadFromTable(tData)
  self.tLocalTraits = tData.localData or {}
  self.tCachedPlayerData = tData.cachedData or {}
  self:OnTimerCleanupCache()
end

function Communicator:RegisterAddonProtocolHandler(strAddonProtocol, fHandler)
  local aHandlers = self.tApiProtocolHandlers[strAddonProtocol] or {}
  table.insert(aHandlers, fHandler)
  self.tApiProtocolHandlers[strAddonProtocol] = aHandlers
end

function Communicator:Internal_SetupTimers()
  Apollo.RegisterTimerHandler("Communicator_Timeout", "OnTimerTimeout", self)
  Apollo.RegisterTimerHandler("Communicator_TimeoutShutdown", "OnTimerTimeoutShutdown", self)
  Apollo.RegisterTimerHandler("Communicator_Queue", "OnTimerProcessMessageQueue", self)
  Apollo.RegisterTimerHandler("Communicator_QueueShutdown", "OnTimerQueueShutdown", self)
  Apollo.RegisterTimerHandler("Communicator_Setup", "OnTimerSetup", self)
  Apollo.RegisterTimerHandler("Communicator_TraitQueue", "OnTimerTraitQueue", self)
  Apollo.RegisterTimerHandler("Communicator_CleanupCache", "OnTimerCleanupCache", self)
  Apollo.RegisterTimerHandler("Communicator_ChannelTimer", "OnChannelTimer", self)
  
  Apollo.CreateTimer("Communicator_Setup", 1, false)
  Apollo.CreateTimer("Communicator_CleanupCache", 60, true)
end

function Communicator:Internal_SetupEventHandlers()
  Apollo.RegisterEventHandler("JoinResultEvent", "OnJoinResultEvent", self)
  Apollo.RegisterEventHandler("SendMessageResultEvent", "OnSendMessageResultEvent", self)
  Apollo.RegisterEventHandler("ThrottledEvent", "OnThrottledEvent", self)
end

function Communicator:Internal_SetupChannel(strAddon)
  self.strAddon = strAddon
  local addon = Apollo.GetAddon(strAddon)
  
  if addon == nil then
    error(string.format("Communicator failed to load the addon called %s", self.strAddon))
  end
  
  addon.chnCommunicator = ICCommLib.JoinChannel("Communicator", ICCommLib.CodeEnumICCommChannelType.Global)
  addon.chnCommunicator:SetJoinResultFunction("Internal_OnChannelJoined", self)
  
  if addon.chnCommunicator:IsReady() then
    self:Log(Communicator.CodeEnumDebugLevel.Comm, "ICCommLib Channel successfully created")
    addon.chnCommunicator:SetReceivedMessageFunction("Internal_OnChannelMessageReceived", self)
    self.chnChannel = addon.chnCommunicator
  else
    self:Log(Communicator.CodeEnumDebugLevel.Comm, "ICCommLib Channel not ready, trying again in 3 seconds")
    Apollo.CreateTimer("Communicator_ChannelTimer", 3, true)
  end  
end

function Communicator:Internal_Reply(mMessage, tPayload)
  local mReply = Message:new()
  
  mReply:SetProtocolVersion(mMessage:GetProtocolVersion())
  mReply:SetSequence(mMessage:GetSequence())
  mReply:SetAddonProtocol(mMessage:GetAddonProtocol())
  mReply:SetType(mMessage:GetType())
  mReply:SetPayload(tPayload)
  mReply:SetDestination(mMessage:GetOrigin())
  mReply:SetCommand(mMessage:GetCommand())
  mReply:SetOrigin(mMessage:GetDestination())
  
  return mReply
end

---------------------------------------------------------------------------------------------------
-- Timer Callbacks
---------------------------------------------------------------------------------------------------
function Communicator:OnChannelTimer()
  Apollo.StopTimer("Communicator_ChannelTimer")
  self:Internal_SetupChannel()
end

function Communicator:OnTimerQueueShutdown()
  Apollo.StopTimer("Communicator_Queue")  -- Stop the timer that processes the MessageQueue
  
  self.bQueueProcessRunning = false
  
  self:Log(Communicator.CodeEnumDebugLevel.Debug, "MessageQueue is empty. Stopping Processing")
end

function Communicator:OnTimerProcessMessageQueue()
  if self.qPendingMessages:GetSize() == 0 then
    self:Log(Communicator.CodeEnumDebugLevel.Debug, "OnTimerProcessMessageQueue: MessageQueue is empty, shutting down")
    
    Apollo.CreateTimer("Communicator_QueueShutdown", 0.1, false)
    
    return
  end
  
  local mMessage = self.qPendingMessages:Pop()
  local channel = self:ChannelForPlayer()
  
  if channel.SendPrivateMessage ~= nil then
    channel:SendPrivateMessage(mMessage:GetDestination(), mMessage:Serialize())
  else
    channel:SendMessage(mMessage:Serialize())
  end
  
  if not self.bTimeoutRunning then
    self.bTimeoutRunnin = true
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
    if (nNow - tData.time) > Communicator.CodeEnumTTL.Packet then
      local tPayload = {
        error = Communicator.CodeEnumError.RequestTimedOut, 
        destination = tData.message:GetDestination(),
        localError = true 
      }
      local mError = self:Internal_Reply(tData.message, tPayload)
      
      mError:SetType(Message.CodeEnumType.Error)
      
      self:Internal_ProcessMessage(mError)
      self.tOutGoingRequests[nSequence] = nil
    else
      nOutgoingCount = nOutgoingCount + 1
    end
  end
  
  for strCommandId, nLastTime in pairs(self.tFloodPrevent) do
    if (nNow - nLastTime) > Communicator.CodeEnumTTL.Flood then
      self.tFloodPrevent[strCommandId] = nil
    end
  end
  
  for strPlayerName, tChannelRecord in pairs(self.tCachedPlayerChannels) do
    if (nNow - tChannelRecord.time or 0) > Communicator.CodeEnumTTL.Channel then
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
      if(nNow - tTrait.time > Communicator.CodeEnumTTL.CacheDie) then
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
  end
end

function Communicator:OnTimerTraitQueue()
  -- Loop over every message in the Queue.
  for strTarget, aRequests in pairs(self.tPendingPlayerTraitRequests) do
    self:Log(Communicator.CodeEnumDebugLevel.Comm, "Sending: " .. table.getn(aRequests) .. " queued trait requests to " .. strTarget)
    
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

---------------------------------------------------------------------------------------------------
-- Package Registration
---------------------------------------------------------------------------------------------------
function Communicator:Initialize()
  Apollo.RegisterPackage(self, MAJOR, MINOR, { })
end

Communicator:Initialize()