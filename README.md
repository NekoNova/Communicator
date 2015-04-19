# Communicator
Communicator is a re-written version of the original RPCore that was used with the PDA Addon in WildStar.
The new version has been tuned for Drop 5, and keeps the Queue's that were in place for properly handling
the messages.

Changes to the ICommLib, require us to change the way the library is initialized and how information is
being parsed. This requires proper serialization and de-serialization of the messages being sent over the
channel.

Outside that, the way Communicator works is almost the same as the way RPCore worked, and used the same
interface and types. Only the serialization of the messages is different, rending any compatibility between
them useless.

# Usage
## Including the Library
The first step for Addons to work with Communicator is to properly load the package in their source code.
This can be done using the following lines:

    local Communicator = {}
	
	function MyAddon:OnDocLoaded()
		if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "wnd_form", nil, self)
		
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("commtest", "OnCommunicatorTestOn", self)
		
		-- Do additional Addon initialization here
		Communicator = Apollo.GetPackage("Communicator-1.0").tPackage	  
	end
	
## Setting traits
Setting traits is the key usage to **Communicator**.
Assuming you have included the library as in the previous example, you can set the values for all your desires traits as follows:

The example will set three traits called "fullname", "race" and "gender".
By setting the traits, others will automatically be able to get these values by requesting them.

    local karRaceToString = {
		[GameLib.CodeEnumRace.Human] 	= Apollo.GetString("RaceHuman"),
		[GameLib.CodeEnumRace.Granok] 	= Apollo.GetString("RaceGranok"),
		[GameLib.CodeEnumRace.Aurin] 	= Apollo.GetString("RaceAurin"),
		[GameLib.CodeEnumRace.Draken] 	= Apollo.GetString("RaceDraken"),
		[GameLib.CodeEnumRace.Mechari] 	= Apollo.GetString("RaceMechari"),
		[GameLib.CodeEnumRace.Chua] 	= Apollo.GetString("RaceChua"),
		[GameLib.CodeEnumRace.Mordesh] 	= Apollo.GetString("CRB_Mordesh"),
	}

	local karGenderToString = { 
		[0] = Apollo.GetString("CRB_Male"),
		[1] = Apollo.GetString("CRB_Female"), 
		[2] = Apollo.GetString("CRB_UnknownType"),
	}
	
	-- Set our traits
	Comm:SetLocalTrait("fullname", GameLib.GetPlayerUnit():GetName())
	Comm:SetLocalTrait("race", karRaceToString[GameLib.GetPlayerUnit():GetRaceId()])
	Comm:SetLocalTrait("gender",karGenderToString[GameLib.GetPlayerUnit():GetGender()])
	
## Requesting Traits
Traits can be requested by simply reading out the responses that **Communicator** does in the back-end.
The Library will cache all information for a specific amount of time.
To request information, the cache is checked; if the cache is empty a request is send to the player in question:

	local rpFullname, rpRace, rpGender
		
	rpFullname = Comm:GetTrait(strPlayer,"fullname")
	rpRace = Comm:GetTrait(strPlayer, "race")
	rpGender = Comm:GetTrait(strPlayer, "gender")
	
The above example loads the three traits we defined by sending the requests to whatever player is defined in **strPlayer**
This causes the messages to be send and filled in by **Communicator**

It's also possible to be notifed when new data is being received.
This can be done by using Apollo to listen to the **Communicator_TraitChanged** event:

	function MyAddon:OnTraitChanged(tData)
		-- Process tData here.
		-- The table contains the following information:
		-- player = the name of the player who the trait belongs to.
		-- trait = Name of the trait being set
		-- data = The actual data of the trait
		-- revision = The revision of the trait, used for caching mechanics
	end
	
	function MyAddon:OnDocLoaded()
		-- Init code
		Apollo.RegisterEventHandler("Communicator_TraitChanged", "onTraitChanged", self)
	end