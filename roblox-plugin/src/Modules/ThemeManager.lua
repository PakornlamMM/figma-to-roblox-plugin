--!strict
--[[
	ThemeManager.lua
	Provides dynamic Roblox Studio theme colors with 100% crash-safe enum and method wrappers.
]]

local ThemeManager = {}
ThemeManager.__index = ThemeManager

export type ThemeColors = {
	MainBackground: Color3,
	SecondaryBackground: Color3,
	InputFieldBackground: Color3,
	Border: Color3,
	MainText: Color3,
	SubText: Color3,
	DimmedText: Color3,
	Accent: Color3,
	AccentHover: Color3,
	AccentText: Color3,
	Success: Color3,
	Error: Color3,
	Warning: Color3,
	ButtonBackground: Color3,
	ButtonHover: Color3,
}

-- Safe query for StudioTheme color without risking enum index runtime errors
local function getStudioColor(guideColorName: string, fallback: Color3, modifierName: string?): Color3
	local success, theme = pcall(function()
		return settings().Studio.Theme
	end)
	if not success or not theme then
		return fallback
	end
	
	local enumSuccess, guideColor = pcall(function()
		return (Enum.StudioStyleGuideColor :: any)[guideColorName]
	end)
	if not enumSuccess or not guideColor then
		return fallback
	end
	
	local modifier = Enum.StudioStyleGuideModifier.Default
	if modifierName then
		pcall(function()
			modifier = (Enum.StudioStyleGuideModifier :: any)[modifierName] or modifier
		end)
	end
	
	local colorSuccess, color = pcall(function()
		return theme:GetColor(guideColor, modifier)
	end)
	if colorSuccess and typeof(color) == "Color3" then
		return color
	end
	
	return fallback
end

function ThemeManager.GetColors(): ThemeColors
	-- Valid StudioStyleGuideColor enums in Studio:
	-- MainBackground, InputFieldBackground, Border, MainText, SubText, DimmedText, Button
	local mainBg = getStudioColor("MainBackground", Color3.fromRGB(46, 46, 46))
	
	-- Darker or derived secondary background for card headers / sub-sections
	local isDark = (mainBg.R + mainBg.G + mainBg.B) / 3 < 0.5
	local secondaryBg = if isDark
		then Color3.new(math.max(0, mainBg.R - 0.04), math.max(0, mainBg.G - 0.04), math.max(0, mainBg.B - 0.04))
		else Color3.new(math.min(1, mainBg.R + 0.04), math.min(1, mainBg.G + 0.04), math.min(1, mainBg.B + 0.04))
	
	return {
		MainBackground = mainBg,
		SecondaryBackground = secondaryBg,
		InputFieldBackground = getStudioColor("InputFieldBackground", Color3.fromRGB(28, 28, 28)),
		Border = getStudioColor("Border", Color3.fromRGB(60, 60, 60)),
		MainText = getStudioColor("MainText", Color3.fromRGB(240, 240, 240)),
		SubText = getStudioColor("SubText", Color3.fromRGB(180, 180, 180)),
		DimmedText = getStudioColor("DimmedText", Color3.fromRGB(130, 130, 130)),
		Accent = Color3.fromRGB(0, 162, 255),
		AccentHover = Color3.fromRGB(51, 180, 255),
		AccentText = Color3.fromRGB(255, 255, 255),
		Success = Color3.fromRGB(46, 204, 113),
		Error = Color3.fromRGB(231, 76, 60),
		Warning = Color3.fromRGB(241, 196, 15),
		ButtonBackground = getStudioColor("Button", Color3.fromRGB(56, 56, 56)),
		ButtonHover = getStudioColor("Button", Color3.fromRGB(70, 70, 70), "Hover"),
	}
end

function ThemeManager.OnThemeChanged(callback: (colors: ThemeColors) -> ()): RBXScriptConnection?
	local success, event = pcall(function()
		return settings().Studio.ThemeChanged
	end)
	if success and event then
		return event:Connect(function()
			callback(ThemeManager.GetColors())
		end)
	end
	return nil
end

return ThemeManager
