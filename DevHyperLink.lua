-- DevHyperLink.lua
require "Window"
require "Apollo"
require "GameLib"
require "ChatSystemLib"

-- A small (but complete) addon, that doesn't do anything, but shows usage of the callbacks.

-- Create the addon object and register it with Apollo in a single line
local DevHyperLink = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("DevHyperLink", false, {"ChatLog","Gemini:Logging-1.2","Gemini:DB-1.0"}, "Gemini:Hook-1.0")
local log
local patterns = {
  -- X://Y url
  "^(%a[%w+.-]+://%S+)",
  "%f[%S](%a[%w+.-]+://%S+)",
  -- www.X.Y url
  "^(www%.[-%w_%%]+%.(%a%a+))",
  "%f[%S](www%.[-%w_%%]+%.(%a%a+))",
  -- "W X"@Y.Z email (this is seriously a valid email)
  '^(%"[^%"]+%"@[%w_.-%%]+%.(%a%a+))',
  '%f[%S](%"[^%"]+%"@[%w_.-%%]+%.(%a%a+))',
  -- X@Y.Z email
  "(%S+@[%w_.-%%]+%.(%a%a+))",
  -- XXX.YYY.ZZZ.WWW:VVVV/UUUUU IPv4 address with port and path
  "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
  "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
  -- XXX.YYY.ZZZ.WWW:VVVV IPv4 address with port (IP of ts server for example)
  "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
  "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
  -- XXX.YYY.ZZZ.WWW/VVVVV IPv4 address with path
  "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%/%S+)",
  "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%/%S+)",
  -- XXX.YYY.ZZZ.WWW IPv4 address
  "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%)%f[%D]",
  "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%)%f[%D]",
  -- X.Y.Z:WWWW/VVVVV url with port and path
  "^([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d/%S+)",
  "%f[%S]([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d/%S+)",
  -- X.Y.Z:WWWW url with port (ts server for example)
  "^([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d)%f[%D]",
  "%f[%S]([%w_.-%%]+[%w_-%%]%.(%a%a+):[0-6]?%d?%d?%d?%d)%f[%D]",
  -- X.Y.Z/WWWWW url with path
  "^([%w_.-%%]+[%w_-%%]%.(%a%a+)/%S+)",
  "%f[%S]([%w_.-%%]+[%w_-%%]%.(%a%a+)/%S+)",
  -- X.Y.Z url
  "^([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
  "%f[%S]([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
  "^([-%w_%%]+%.(%a%a+))",
  "%f[%S]([-%w_%%]+%.(%a%a+))"
}

local db
local defaults = {} 
defaults.profile = {}
defaults.profile.checkboxes = {
	[ChatSystemLib.ChatChannel_Whisper] = {buttonName = "Whisper_Checkbox" , channel = ChatSystemLib.ChatChannel_Whisper, value = true},
	[ChatSystemLib.ChatChannel_Society] = {buttonName = "Society_Checkbox" , channel = ChatSystemLib.ChatChannel_Society, value = false},
	[ChatSystemLib.ChatChannel_Party] = {buttonName = "Party_Checkbox" , channel = ChatSystemLib.ChatChannel_Party, value = false},
	[ChatSystemLib.ChatChannel_Guild] = {buttonName = "Guild_Checkbox" , channel = ChatSystemLib.ChatChannel_Guild, value = true},
	[ChatSystemLib.ChatChannel_Realm] = {buttonName = "Realm_Checkbox" , channel = ChatSystemLib.ChatChannel_Realm, value = false},
	[ChatSystemLib.ChatChannel_Say] = {buttonName = "Say_Checkbox" , channel = ChatSystemLib.ChatChannel_Say, value = false},
	[ChatSystemLib.ChatChannel_Zone] = {buttonName = "Zone_Checkbox" , channel = ChatSystemLib.ChatChannel_Zone, value = false},
	[ChatSystemLib.ChatChannel_Trade] = {buttonName = "Trade_Checkbox" , channel = ChatSystemLib.ChatChannel_Trade, value = false},
	[ChatSystemLib.ChatChannel_Advice] = {buttonName = "Advice_Checkbox" , channel = ChatSystemLib.ChatChannel_Advice, value = false},
	[ChatSystemLib.ChatChannel_AccountWhisper] = {buttonName = "AccountWhisper_Checkbox" , channel = ChatSystemLib.ChatChannel_AccountWhisper, value = false},
	[ChatSystemLib.ChatChannel_Instance] = {buttonName = "Instance_Checkbox" , channel = ChatSystemLib.ChatChannel_Instance, value = false}
}
local cachedSettings = {}

-- Replaces MyAddon:OnLoad
function DevHyperLink:OnInitialize()
  -- do init tasks here, like setting default states
  -- or setting up slash commands.

	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	local opts = {level = GeminiLogging.INFO, pattern = "%d ]] %c:%n [[ - %m", appender = "GeminiConsole"}
	log = GeminiLogging:GetLogger(opts)
	
	log:debug("Initializing addon 'DevHyperLink'")
	self.log = log	
	db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)
	self.db = db
end

function DevHyperLink:OnDependencyError(strDep, strError)
    log:debug(strError)
    if strDep == "ChatLog" then
        local cReplacements = Apollo.GetReplacement(strDep)
        if #cReplacements ~= 1 then
            return false
        end
        self.ChatLogReplace = cReplacements[1]
        return true
    end
    return false
end

-- Called when player has loaded and entered the world
function DevHyperLink:OnEnable()
  -- Do more initialization here, that really enables the use of your addon.
  -- Register Events, Hook functions, Create Frames, Get information from 
  -- the game that wasn't available in OnInitialize.  Here you can Load XML, etc.

  -- Just like in OnInitialize the ChatLog has not loaded at this point so Print is still not possible.
  -- So that this addon does actually print something we'll delay for 1 second then Print.
  -- NOTE: On really slow machines this may still fail as they will still not have loaded ChatLog
	self.xmlDoc = XmlDoc.CreateFromFile("DevHyperLink.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)	
	self.ChatLog = self:GetChatLog()
	if self.ChatLog == nil then
		Apollo.AddAddonErrorText(self, "Could not find Compatible ChatLog addon.")
		return
	end
	self:PostHook(self.ChatLog, "OnChatMessage")
	self:PostHook(self.ChatLog, "OnNodeClick")

end

function DevHyperLink:GetChatLog()
	if self.ChatLogReplace ~= nil then
		return self.ChatLogReplace
	end
	return Apollo.GetAddon("ChatLog")		
end

function DevHyperLink:OnDocumentReady()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "DevHyperLinkForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)		
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("devh", "OnDevHyperLinkOn", self)

		-- Do additional Addon initialization here
		self.wndCopyInput = Apollo.LoadForm(self.xmlDoc, "CopyWindow", nil, self)
		self.wndCopyInput:Show(false, true)
			 
	end
end

function DevHyperLink:OnDisable()
  -- Unhook, Unregister Events, Hide/destroy windows that you created.
  -- You would probably only use an OnDisable if you want to 
  -- build a "standby" mode, or be able to toggle modules on/off.
end


-- on SlashCommand "/devh"
function DevHyperLink:OnDevHyperLinkOn()
	cachedSettings.checkboxes = {}
	local i, v = next(self.db.profile.checkboxes, nil)
	while i do
		cachedSettings.checkboxes[i] = self:deepCopy(v)
		i, v = next(self.db.profile.checkboxes, i)
	end
		
	for i, checkbox in pairs(cachedSettings.checkboxes) do
		self.wndMain:FindChild(checkbox.buttonName):SetCheck(checkbox.value)
	end	
	self.wndMain:Invoke() -- show the window
end

function DevHyperLink:deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        -- as before, but if we find a table, make sure we copy that too
        if type(v) == 'table' then
            v = self:deepCopy(v)
        end
        copy[k] = v
    end
    return copy
end

function DevHyperLink:OnChatMessage(luaCaller, channelCurrent, tMessage)
	log:debug("Started OnChatMessage")
	-- tMessage has bAutoResponse, bGM, bSelf, strSender, strRealmName, nPresenceState, arMessageSegments, unitSource, bShowChatBubble, bCrossFaction, nReportId
	
	-- early exit
	if self.db.profile.checkboxes[channelCurrent:GetType()] == nil or not self.db.profile.checkboxes[channelCurrent:GetType()].value then
		return
	end	
		
	local tQueuedMessage = {}
	tQueuedMessage.tMessage = tMessage
	tQueuedMessage.eChannelType = channelCurrent:GetType()
	tQueuedMessage.strChannelName = channelCurrent:GetName()
	tQueuedMessage.strChannelCommand = channelCurrent:GetCommand()
	self:HelperGenerateChatLinkMessage(tQueuedMessage)
	
	-- queue message on windows.	
	for i, wndChat in pairs(self.ChatLog.tChatWindows) do
		if wndChat:GetData().tViewedChannels[tQueuedMessage.eChannelType] then -- check flags for filtering
			self.ChatLog.bQueuedMessages = true
			wndChat:GetData().tMessageQueue:Push(tQueuedMessage)
		end
	end
	
end

function DevHyperLink:HelperGenerateChatLinkMessage(tQueuedMessage)
	log:debug("Started HelperGenerateChatLinkMessage")
	if tQueuedMessage.xml == nil then
		log:debug("Xml is nil")
		tQueuedMessage.xml = XmlDoc.new()
	end
	local eChannelType = tQueuedMessage.eChannelType
	local tMessage = tQueuedMessage.tMessage
	local tm = GameLib.GetLocalTime()
	local crChatText = self:GetArChatColor(eChannelType)
	local strChatFont = "CRB_Interface10"
	for idx, tSegment in pairs(tMessage.arMessageSegments) do
		local links = self:SearchInputForUrl(tSegment)
		if next(links) ~= nil then
			for i, link in pairs(links) do
				log:debug("Found Url: " .. link)
				local strTime = "" if self.bShowTimestamp then strTime = string.format("%d:%02d ", tm.nHour, tm.nMinute) end
				tQueuedMessage.xml:AddLine(strTime, crChatText, "CRB_Interface10", "Text")
				tQueuedMessage.xml:AppendText("[DevHyperLink]: ", crChatText, "CRB_Interface10", "Text")
				tQueuedMessage.xml:AppendText("link detected, click on link to copy: ", crChatText, strChatFont)					
				tQueuedMessage.xml:AppendText("["..link.."]", "fffff799", strChatFont, {strUrl=link} , "URL")
			end
		end	
	end
	return
end

function DevHyperLink:GetArChatColor(eChannelType)
		self.arChatColor =
	{
		[ChatSystemLib.ChatChannel_Command] 		= ApolloColor.new("ChatCommand"),
		[ChatSystemLib.ChatChannel_System] 			= ApolloColor.new("ChatSystem"),
		[ChatSystemLib.ChatChannel_Debug] 			= ApolloColor.new("ChatDebug"),
		[ChatSystemLib.ChatChannel_Say] 			= ApolloColor.new("ChatSay"),
		[ChatSystemLib.ChatChannel_Yell] 			= ApolloColor.new("ChatShout"),
		[ChatSystemLib.ChatChannel_Whisper] 		= ApolloColor.new("ChatWhisper"),
		[ChatSystemLib.ChatChannel_Party] 			= ApolloColor.new("ChatParty"),
		[ChatSystemLib.ChatChannel_AnimatedEmote] 	= ApolloColor.new("ChatEmote"),
		[ChatSystemLib.ChatChannel_Zone] 			= ApolloColor.new("ChatZone"),
		[ChatSystemLib.ChatChannel_ZonePvP] 		= ApolloColor.new("ChatPvP"),
		[ChatSystemLib.ChatChannel_Trade] 			= ApolloColor.new("ChatTrade"),
		[ChatSystemLib.ChatChannel_Guild] 			= ApolloColor.new("ChatGuild"),
		[ChatSystemLib.ChatChannel_GuildOfficer] 	= ApolloColor.new("ChatGuildOfficer"),
		[ChatSystemLib.ChatChannel_Society] 		= ApolloColor.new("ChatCircle2"),
		[ChatSystemLib.ChatChannel_Custom] 			= ApolloColor.new("ChatCustom"),
		[ChatSystemLib.ChatChannel_NPCSay] 			= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_NPCYell] 		= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_NPCWhisper] 		= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_Datachron] 		= ApolloColor.new("ChatNPC"),
		[ChatSystemLib.ChatChannel_Combat] 			= ApolloColor.new("ChatGeneral"),
		[ChatSystemLib.ChatChannel_Realm] 			= ApolloColor.new("ChatSupport"),
		[ChatSystemLib.ChatChannel_Loot] 			= ApolloColor.new("ChatLoot"),
		[ChatSystemLib.ChatChannel_Emote] 			= ApolloColor.new("ChatEmote"),
		[ChatSystemLib.ChatChannel_PlayerPath] 		= ApolloColor.new("ChatGeneral"),
		[ChatSystemLib.ChatChannel_Instance] 		= ApolloColor.new("ChatParty"),
		[ChatSystemLib.ChatChannel_WarParty] 		= ApolloColor.new("ChatWarParty"),
		[ChatSystemLib.ChatChannel_WarPartyOfficer] = ApolloColor.new("ChatWarPartyOfficer"),
		[ChatSystemLib.ChatChannel_Advice] 			= ApolloColor.new("ChatAdvice"),
		[ChatSystemLib.ChatChannel_AccountWhisper]	= ApolloColor.new("ChatAccountWisper"),
	}
	return self.arChatColor[eChannelType]
end

function DevHyperLink:OnNodeClick(luaCaller, wndHandler, wndControl, strNode, tAttributes, eMouseButton)
	log:debug("Opening Copy Window")
	if strNode == "URL" then
		local strData = tAttributes.strUrl
		self.wndCopyInput:FindChild("CopyButton"):SetActionData(GameLib.CodeEnumConfirmButtonType.CopyToClipboard, strData)		
		self.wndCopyInput:FindChild("EditBox"):SetText(strData)
		self.wndCopyInput:ToFront()
		self.wndCopyInput:FindChild("EditBox"):SetFocus()
		self.wndCopyInput:Invoke()
	end
end

function DevHyperLink:SearchInputForUrl(tSegment)
	local links = {}
	local text = tSegment.strText
	for idx, pattern in pairs(patterns) do
		while string.find(text, pattern) ~= nil do
			table.insert(links, string.sub(text, string.find(text, pattern)))
			text = self:SubstractUrl(text, pattern)				
		end			
	end
	return links	
end

function DevHyperLink:SubstractUrl(_text, _pattern)
	if string.find(_text, _pattern) == nil then
		return _text
	end 
	return string.gsub(_text, _pattern, "", 1)
end

---------------------------------------------------------------------------------------------------
-- DevHyperLinkForm Functions
---------------------------------------------------------------------------------------------------

-- when the OK button is clicked
function DevHyperLink:OnOK()
	self.db.profile.checkboxes = {}
	local i, v = next(cachedSettings.checkboxes, nil)
	while i do
		self.db.profile.checkboxes[i] = self:deepCopy(v)
		i, v = next(cachedSettings.checkboxes, i)
	end
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Realm, "DevHyperLink Settings saved!", "")	
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function DevHyperLink:OnCancel()
	cachedSettings.checkboxes = {}
	local i, v = next(self.db.profile.checkboxes, nil)
	while i do
		cachedSettings.checkboxes[i] = self:deepCopy(v)
		i, v = next(self.db.profile.checkboxes, i)
	end
	self.wndMain:Close() -- hide the window
end

-- when a checkbox is clicked
function DevHyperLink:ConfigureChatChannel( wndHandler, wndControl, eMouseButton )
	for i, checkbox in pairs(cachedSettings.checkboxes) do
		if wndControl:GetName() == checkbox.buttonName then
			if wndHandler:IsChecked() then
				checkbox.value = true
				return
			else
				checkbox.value = false
				return
			end		
		end	
	end
end

---------------------------------------------------------------------------------------------------
-- CopyWindow Functions
---------------------------------------------------------------------------------------------------

function DevHyperLink:OnNo( wndHandler, wndControl, eMouseButton )
	wndControl:GetParent():Close()
end