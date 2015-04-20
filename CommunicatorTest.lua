-----------------------------------------------------------------------------------------------
-- Client Lua Script for CommunicatorTest
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 require "ICCommLib"
-----------------------------------------------------------------------------------------------
-- CommunicatorTest Module Definition
-----------------------------------------------------------------------------------------------
local CommunicatorTest = {} 
local Comm
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

local karRaceToString = {
[GameLib.CodeEnumRace.Human] 	= Apollo.GetString("RaceHuman"),
[GameLib.CodeEnumRace.Granok] 	= Apollo.GetString("RaceGranok"),
[GameLib.CodeEnumRace.Aurin] 	= Apollo.GetString("RaceAurin"),
[GameLib.CodeEnumRace.Draken] = Apollo.GetString("RaceDraken"),
[GameLib.CodeEnumRace.Mechari] 	= Apollo.GetString("RaceMechari"),
[GameLib.CodeEnumRace.Chua] 	= Apollo.GetString("RaceChua"),
[GameLib.CodeEnumRace.Mordesh] 	= Apollo.GetString("CRB_Mordesh"),
}
local karGenderToString = { [0] = Apollo.GetString("CRB_Male"), [1] = Apollo.GetString("CRB_Female"), [2] = Apollo.GetString("CRB_UnknownType"),}
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function CommunicatorTest:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function CommunicatorTest:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"Lib:dkJSON-2.5",
		"Communicator-1.0",
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- CommunicatorTest OnLoad
-----------------------------------------------------------------------------------------------
function CommunicatorTest:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("CommunicatorTest.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- CommunicatorTest OnDocLoaded
-----------------------------------------------------------------------------------------------
function CommunicatorTest:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "wnd_CommTestForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("commtest", "OnCommunicatorTestOn", self)
		Apollo.RegisterEventHandler("Communicator_TraitChanged", "OnTraitChanged", self)
		Apollo.RegisterEventHandler("Communicator_PlayerUpdated", "OnPlayerUpdated", self)
		-- Do additional Addon initialization here
		Comm = Apollo.GetPackage("Communicator-1.0").tPackage
		self.tmrRefreshCharacterSheet = ApolloTimer.Create(3, true, "UpdateCharacterSheet", self)
		Comm:ClearCachedPlayerList()
		Comm:SetDebugLevel(1)
	end
end

-----------------------------------------------------------------------------------------------
-- CommunicatorTest Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/commtest"
function CommunicatorTest:OnCommunicatorTestOn()
	Comm:SetLocalTrait("fullname", GameLib.GetPlayerUnit():GetName())
	Comm:SetLocalTrait("race", karRaceToString[GameLib.GetPlayerUnit():GetRaceId()])
	Comm:SetLocalTrait("gender",karGenderToString[GameLib.GetPlayerUnit():GetGender()])
	self.wndMain:Invoke() -- show the window
end

function CommunicatorTest:UpdateCharacterSheet()
	if GameLib.GetTargetUnit() == nil or GameLib.GetTargetUnit() == GameLib.GetPlayerUnit() then return end
	local player = self.wndMain:GetData()
	if player == GameLib.GetPlayerUnit():GetName() then return end
	local rpFullname, rpRace, rpGender
	local xmlCS = XmlDoc.new()
	
	rpFullname = Comm:GetTrait(player,"fullname")
	rpRace = Comm:GetTrait(player, "race")
	rpGender = Comm:GetTrait(player, "gender")
	
	local strLabelColor = "FF009999"
	local strEntryColor = "FF99FFFF"
	xmlCS:AddLine("Name: ", strLabelColor,"CRB_InterfaceMedium")
	xmlCS:AppendText(rpFullname, strEntryColor, "CRB_InterfaceMedium")
	xmlCS:AddLine("Species: ", strLabelColor, "CRB_InterfaceMedium")
	xmlCS:AppendText(rpRace, strEntryColor, "CRB_InterfaceMedium")
	xmlCS:AddLine("Gender: ", strLabelColor, "CRB_InterfaceMedium")
	xmlCS:AppendText(rpGender, strEntryColor, "CRB_InterfaceMedium")
	self.wndMain:FindChild("wnd_Display"):SetDoc(xmlCS)
end

function CommunicatorTest:OnPlayerUpdated(tData)
	Print(tData.player.." data updated.")
end

function CommunicatorTest:OnTraitChanged(tTraitInfo)
	--tTraitInfo
	Print(string.format("Player: %s\nTrait: %s\nData: %s\nRevision: %s", tTraitInfo.player, tTraitInfo.trait, tTraitInfo.data, tTraitInfo.revision))
end
-----------------------------------------------------------------------------------------------
-- CommunicatorTestForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function CommunicatorTest:OnOK()
	local strCharacter = GameLib.GetTargetUnit():GetName()
	if(strCharacter == nil or strCharacter == "") then return end
	Comm:GetAllTraits(strCharacter)
	self.wndMain:SetData(strCharacter)
end

-- when the Cancel button is clicked
function CommunicatorTest:OnCancel()
	self.wndMain:Close() -- hide the window
end


-----------------------------------------------------------------------------------------------
-- CommunicatorTest Instance
-----------------------------------------------------------------------------------------------
local CommunicatorTestInst = CommunicatorTest:new()
CommunicatorTestInst:Init()
