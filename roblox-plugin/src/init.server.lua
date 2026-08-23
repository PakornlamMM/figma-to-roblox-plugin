--!strict
--[[
	init.server.lua
	Main plugin entry point for FigmaToRoblox.
	Sets up Studio toolbar, DockWidgetPluginGui, JSON parsing, and UI generation pipeline.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")

local Config = require(script:WaitForChild("Config"))
local Types = require(script:WaitForChild("Types"))
local ThemeManager = require(script:WaitForChild("Modules"):WaitForChild("ThemeManager"))
local JsonParser = require(script:WaitForChild("Modules"):WaitForChild("JsonParser"))
local PluginUI = require(script:WaitForChild("Modules"):WaitForChild("PluginUI"))
local InstanceGenerator = require(script:WaitForChild("Modules"):WaitForChild("InstanceGenerator"))

type FigmaNode = Types.FigmaNode
type ParseResult = Types.ParseResult

-- =============================================================================
-- 1. Create Toolbar & Action Button
-- =============================================================================
local toolbar = plugin:CreateToolbar(Config.ToolbarTitle)
local toggleButton = toolbar:CreateButton(
	Config.ButtonTitle,
	Config.ButtonTooltip,
	Config.ButtonIcon
)
toggleButton.ClickableWhenViewportHidden = true

-- =============================================================================
-- 2. Create DockWidgetPluginGui
-- =============================================================================
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Config.Widget.InitialDockState,
	Config.Widget.InitiallyEnabled,
	Config.Widget.OverrideRestore,
	Config.Widget.DefaultWidth,
	Config.Widget.DefaultHeight,
	Config.Widget.MinWidth,
	Config.Widget.MinHeight
)

local dockWidget = plugin:CreateDockWidgetPluginGui(Config.PluginId, widgetInfo)
dockWidget.Title = "Figma to Roblox"
dockWidget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- =============================================================================
-- 3. Initialize Plugin UI
-- =============================================================================
local ui = PluginUI.Create(dockWidget)

-- Sync button state with dock widget visibility
local function syncButtonState()
	toggleButton:SetActive(dockWidget.Enabled)
end

toggleButton.Click:Connect(function()
	dockWidget.Enabled = not dockWidget.Enabled
	syncButtonState()
	print(string.format("[FigmaToRoblox] Widget visibility toggled to: %s", tostring(dockWidget.Enabled)))
end)

dockWidget:BindToClose(function()
	dockWidget.Enabled = false
	syncButtonState()
end)

dockWidget:GetPropertyChangedSignal("Enabled"):Connect(syncButtonState)
syncButtonState()

-- =============================================================================
-- 4. Hook Up UI Action Handlers
-- =============================================================================

-- Sample Button: Loads sample Figma payload
ui.OnSampleClicked(function()
	local sample = JsonParser.GetSampleJson()
	ui.SetJsonText(sample)
	ui.SetStatus("Loaded sample Figma JSON. Click 'Generate UI' to test.", "idle")
end)

-- Clear Button: Resets input and status
ui.OnClearClicked(function()
	ui.SetJsonText("")
	ui.SetStatus("Cleared. Paste Figma JSON above.", "idle")
end)

-- Creates or retrieves the target ScreenGui in StarterGui
local function prepareTargetScreenGui(rootNode: any): ScreenGui
	local screenGuiName = rootNode.name or "FigmaImport"
	
	-- Check if a ScreenGui with this name already exists in StarterGui
	local existing = StarterGui:FindFirstChild(screenGuiName)
	if existing and existing:IsA("ScreenGui") then
		existing:Destroy()
	end
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = screenGuiName
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = StarterGui
	
	return screenGui
end

-- Generate Button: Parse JSON and execute UI conversion pipeline
ui.OnGenerateClicked(function()
	local rawJson = ui.GetJsonText()
	
	ui.SetStatus("Parsing JSON...", "working")
	
	-- 1. Parse & validate payload
	local result: ParseResult = JsonParser.Parse(rawJson)
	
	if not result.success or not result.rootNode then
		ui.SetStatus(result.errorMessage or "Failed to parse JSON.", "error")
		return
	end
	
	local rootNode = result.rootNode
	local nodeCount = result.nodeCount
	local options = ui.GetOptions()
	
	-- 2. Begin ChangeHistory recording for Studio Undo/Redo support
	local recordingSuccess, recordingId = pcall(function()
		return ChangeHistoryService:TryBeginRecording("Generate Figma UI")
	end)
	
	local statsResult
	local generateSuccess, generateErr = pcall(function()
		local screenGui = prepareTargetScreenGui(rootNode)
		
		-- 3. Recursively generate Roblox UI hierarchy
		local rootGui, stats = InstanceGenerator.Generate(rootNode, screenGui, options)
		statsResult = stats
		
		-- Select the generated ScreenGui in Studio Explorer
		Selection:Set({ screenGui })
		
		print(string.format(
			"[FigmaToRoblox] Conversion complete! Created '%s' in StarterGui (%d Instances: %d Frames, %d TextLabels, %d Images, %d Corners, %d Strokes, %d Layouts)",
			screenGui.Name,
			stats.TotalCreated,
			stats.Frames,
			stats.TextLabels,
			stats.ImageLabels,
			stats.Corners,
			stats.Strokes,
			stats.Layouts
		))
	end)
	
	-- 4. Commit Undo recording
	if recordingSuccess and recordingId then
		if generateSuccess then
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		else
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
		end
	else
		ChangeHistoryService:SetWaypoint("Generate Figma UI")
	end
	
	-- 5. Update Status UI
	if generateSuccess and statsResult then
		ui.SetStatus(
			string.format("✓ Generated '%s' (%d elements: %d text, %d img)!", rootNode.name, statsResult.TotalCreated, statsResult.TextLabels, statsResult.ImageLabels),
			"success"
		)
	else
		ui.SetStatus(
			string.format("Generation error: %s", tostring(generateErr)),
			"error"
		)
	end
end)

-- Cleanup on plugin unload
plugin.Unloading:Connect(function()
	ui.Destroy()
end)

print("[FigmaToRoblox] Plugin initialized successfully.")
