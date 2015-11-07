-----------------------------------------------------------------------------------------------
-- Client Lua Script for MendingSaves
-----------------------------------------------------------------------------------------------
 
require "Window"
 
local MendingSaves = {} 
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function MendingSaves:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end

function MendingSaves:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

	self.GridTable = {
		["Index"]	= {},
		["Names"]	= {},
		["Saves"]	= {},
		["Useful"]	= {},
	}
	self.GridIndex = {"Names", "Saves", "Useful"}
	self.Saved = {}
	self.Settings = {
		["Position"] = { 145, 45, 560, 300 },
	}
end
 

-----------------------------------------------------------------------------------------------
-- MendingSaves OnLoad
-----------------------------------------------------------------------------------------------
function MendingSaves:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MendingSaves.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
end

-----------------------------------------------------------------------------------------------
-- MendingSaves OnDocLoaded
-----------------------------------------------------------------------------------------------
function MendingSaves:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MendingSavesForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		Apollo.RegisterSlashCommand("mending", "OnMendingSavesOn", self)
		Apollo.RegisterEventHandler("UnitEnteredCombat", "OnEnteredCombat", self)
		Apollo.RegisterEventHandler("BuffAdded", "OnBuffAdded", self)
		Apollo.RegisterEventHandler("CombatLogDamage", "OnCombatLogDamage", self)

		
		self.wndGrid = self.wndMain:FindChild("wndGrid")
		self.wndMain:SetAnchorOffsets(self.Settings["Position"][1], self.Settings["Position"][2], self.Settings["Position"][3], self.Settings["Position"][4])

	end
end

-----------------------------------------------------------------------------------------------
-- MendingSaves Save/Load Functions
-----------------------------------------------------------------------------------------------

function MendingSaves:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end
	local left, top, right, bottom = self.wndMain:GetAnchorOffsets()
	self.Settings["Position"] = { left, top, right, bottom }

	return self.Settings
end

function MendingSaves:OnRestore(eType, tLoad)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	for k, v in pairs(tLoad) do
		self.Settings[k] = v
	end	
end



-----------------------------------------------------------------------------------------------
-- MendingSaves Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function MendingSaves:OnMendingSavesOn()
	self:UpdateGrid()
	self.wndMain:Show(true, false)
end



function MendingSaves:OnBuffAdded(unit,buff)

	if not unit or not buff then return end
	if buff.splEffect:GetName() ~= "Recently Saved" then return end
	local unitname = unit:GetName()
	self.found = false
	local n = table.getn(self.GridTable["Names"])
	for k, v in pairs(self.GridTable["Names"]) do
		if v == unitname then
			self.GridTable["Saves"][k] = self.GridTable["Saves"][k] + 1
			self.GridTable["Useful"][k] = self.GridTable["Useful"][k] + 1
			self.found = true
		end
	end
	if self.found == false then
		local nCount = n + 1
		self.GridTable["Index"][unitname] = nCount
		self.GridTable["Names"][nCount] = unitname
		self.GridTable["Saves"][nCount] = 1
		self.GridTable["Useful"][nCount] = 1
	end

	self:UpdateGrid()
	self.Saved[unitname] = Apollo.GetTickCount()
end


function MendingSaves:OnCombatLogDamage(tinfo)
	if not tinfo.bTargetKilled then return end	
	local unitname = tinfo.unitTarget:GetName()
	local tick = Apollo.GetTickCount()
	--Any time someone dies, go through this list and find out how much time has passed since their last save
	for k, v in pairs (self.Saved) do
		local diff = tick - v
		if diff > 10000 then
			-- if it's been more than 10 seconds, they're off the hook. 
			table.remove(self.Saved,v)
		elseif (diff < 5000) and unitname == k then
			-- if they died shortly after their save, it was either a wipe call, or they're bad. Either way, not a useful save
			local nameindex = self.GridTable["Index"][k]
			self.GridTable["Useful"][nameindex] = self.GridTable["Useful"][nameindex] - 1
			table.remove(self.Saved,v)
		end
	end
	self:UpdateGrid()
end

function MendingSaves:UpdateGrid()
	local h = table.getn(self.GridTable["Names"])
	local w = table.getn(self.GridIndex)
	self:ClearGrid()
	if h < 1 then return end
	for i = 1, h do
		self.wndGrid:AddRow("")
		self.wndGrid:SetCellText(i, 1, self.GridTable["Names"][i])
		self.wndGrid:SetCellText(i, 2, self.GridTable["Saves"][i])
		self.wndGrid:SetCellText(i, 3, self.GridTable["Useful"][i])
	end
end 



function MendingSaves:ClearGrid()
	local h = self.wndGrid:GetRowCount()
	if h then
		for i = 1, h do
			self.wndGrid:DeleteRow(1)
		end
	end
end



function MendingSaves:OnCombat()
	self.SavedLastFight = self.SavedThisFight
	self.SavedThisFight = { }
end

-----------------------------------------------------------------------------------------------
-- MendingSavesForm Functions
-----------------------------------------------------------------------------------------------
function MendingSaves:OnClose()
	self.wndMain:Close()
end


function MendingSaves:OnReset()
	for k, v in pairs(self.GridTable) do
		self.GridTable[k] = {}
	end
	self:UpdateGrid()
end

-----------------------------------------------------------------------------------------------
-- MendingSaves Instance
-----------------------------------------------------------------------------------------------
local MendingSavesInst = MendingSaves:new()
MendingSavesInst:Init()
