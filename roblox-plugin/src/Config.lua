--!strict
--[[
	Config.lua
	Default settings, widget metadata, and configuration constants.
]]

-- Safe font fallback helper
local function getSafeFont(fontName: string, fallback: Enum.Font): Enum.Font
	local success, font = pcall(function()
		return (Enum.Font :: any)[fontName]
	end)
	if success and font then
		return font
	end
	return fallback
end

local Config = {
	PluginName = "FigmaToRoblox",
	PluginId = "FigmaToRoblox_DockWidget_v2.0", -- Bumped version ID to reset cached Studio layout
	ToolbarTitle = "Figma UI",
	ButtonTitle = "Figma to Roblox",
	ButtonTooltip = "Convert Figma JSON into native Roblox UI instances",
	ButtonIcon = "rbxassetid://6031075931",
	
	Widget = {
		InitialDockState = Enum.InitialDockState.Float, -- Float in center so it's immediately visible
		InitiallyEnabled = false,
		OverrideRestore = true, -- Force Studio to show widget floating with default size
		DefaultWidth = 420,
		DefaultHeight = 560,
		MinWidth = 320,
		MinHeight = 360,
	},
	
	Defaults = {
		SizingMode = "ResponsiveScale",
		TargetContainer = "StarterGui",
		IgnoreInvisible = true,
		CreateScreenGui = true,
		BaseResolution = Vector2.new(1920, 1080),
	},
	
	UI = {
		Font = getSafeFont("BuilderSans", Enum.Font.Gotham),
		FontBold = getSafeFont("BuilderSansBold", Enum.Font.GothamBold),
		FontMedium = getSafeFont("BuilderSansMedium", Enum.Font.GothamMedium),
		FontCode = Enum.Font.Code,
		TextSizeSmall = 11,
		TextSizeRegular = 13,
		TextSizeHeader = 16,
		CornerRadius = UDim.new(0, 6),
		SmallCornerRadius = UDim.new(0, 4),
		Padding = 12,
		ElementGap = 10,
	},
}

return Config
