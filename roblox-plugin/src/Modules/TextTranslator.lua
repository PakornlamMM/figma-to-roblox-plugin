--!strict
--[[
	TextTranslator.lua
	Translates Figma typography, text styles, font families, alignments, and sizes to TextLabel properties.
]]

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local StyleTranslator = require(script.Parent:WaitForChild("StyleTranslator"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))

type FigmaNode = Types.FigmaNode
type FigmaTypeStyle = Types.FigmaTypeStyle

local TextTranslator = {}

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

-- Comprehensive Figma font family to Roblox Enum.Font lookup
local FONT_MAPPINGS: { [string]: Enum.Font } = {
	["buildersans"] = Config.UI.Font,
	["buildersansbold"] = Config.UI.FontBold,
	["inter"] = Enum.Font.Gotham,
	["roboto"] = Enum.Font.Roboto,
	["robotomono"] = Enum.Font.RobotoMono,
	["gotham"] = Enum.Font.Gotham,
	["gothambold"] = Enum.Font.GothamBold,
	["gothamblack"] = Enum.Font.GothamBlack,
	["montserrat"] = Enum.Font.Montserrat,
	["sourcesanspro"] = Enum.Font.SourceSans,
	["sourcesans"] = Enum.Font.SourceSans,
	["sourcesansbold"] = Enum.Font.SourceSansBold,
	["arial"] = Enum.Font.Arial,
	["arialbold"] = Enum.Font.ArialBold,
	["fredokaone"] = Enum.Font.FredokaOne,
	["fredoka"] = Enum.Font.FredokaOne,
	["luckiestguy"] = Enum.Font.LuckiestGuy,
	["poppins"] = Enum.Font.Gotham,
	["segoeui"] = Enum.Font.SourceSans,
	["helvetica"] = Enum.Font.Arial,
	["ubuntu"] = Enum.Font.Ubuntu,
	["bangers"] = Enum.Font.Bangers,
	["comicneue"] = Enum.Font.ComicNeueAngular,
	["code"] = Enum.Font.Code,
}

--[[
	Resolves the best matching Roblox Enum.Font based on font family, weight, and style.
]]
function TextTranslator.ResolveFont(style: any?): Enum.Font
	if not style then
		return Config.UI.Font
	end
	
	local family = string.lower(string.gsub(tostring(style.fontFamily or style.font or "buildersans"), "%s+", ""))
	local weight = tonumber(style.fontWeight or style.weight or 400) or 400
	
	if FONT_MAPPINGS[family] then
		local baseFont = FONT_MAPPINGS[family]
		if weight >= 700 then
			if family == "gotham" or family == "inter" or family == "poppins" then
				return Enum.Font.GothamBold
			elseif family == "sourcesans" or family == "sourcesanspro" then
				return Enum.Font.SourceSansBold
			elseif family == "buildersans" then
				return Config.UI.FontBold
			elseif family == "arial" then
				return Enum.Font.ArialBold
			end
		end
		return baseFont
	end
	
	-- If bold weight requested
	if weight >= 700 then
		return Config.UI.FontBold
	end
	
	return Config.UI.Font
end

--[[
	Translates Figma horizontal alignment to Enum.TextXAlignment.
]]
function TextTranslator.GetXAlignment(style: any?): Enum.TextXAlignment
	if not style then
		return Enum.TextXAlignment.Center
	end
	
	local rawAlign = style.textAlignHorizontal or style.textAlign or style.align or "CENTER"
	local align = string.upper(tostring(rawAlign))
	if align == "LEFT" then
		return Enum.TextXAlignment.Left
	elseif align == "RIGHT" then
		return Enum.TextXAlignment.Right
	end
	
	return Enum.TextXAlignment.Center
end

--[[
	Translates Figma vertical alignment to Enum.TextYAlignment.
]]
function TextTranslator.GetYAlignment(style: any?): Enum.TextYAlignment
	if not style then
		return Enum.TextYAlignment.Center
	end
	
	local rawAlign = style.textAlignVertical or style.verticalAlign or "CENTER"
	local align = string.upper(tostring(rawAlign))
	if align == "TOP" then
		return Enum.TextYAlignment.Top
	elseif align == "BOTTOM" then
		return Enum.TextYAlignment.Bottom
	end
	
	return Enum.TextYAlignment.Center
end

--[[
	Applies typography properties to a TextLabel or TextButton.
]]
function TextTranslator.ApplyText(label: TextLabel, node: any)
	local style = node.style or node.textStyle or node
	
	-- Text Content
	local textContent = node.characters or node.text or node.value or node.content or node.name or ""
	label.Text = tostring(textContent)
	
	-- Font & Sizing
	label.Font = TextTranslator.ResolveFont(style)
	
	local fontSize = style.fontSize or node.fontSize or 28
	local parsedSize = math.clamp(math.round(tonumber(fontSize) or 28), 8, 100)
	label.TextSize = parsedSize
	
	-- Alignments
	label.TextXAlignment = TextTranslator.GetXAlignment(style)
	label.TextYAlignment = TextTranslator.GetYAlignment(style)
	
	-- Wrapping & Scaling
	label.TextWrapped = true
	label.AutoLocalize = false
	label.ClipsDescendants = false
	
	-- Text Color & Transparency from fills
	local textColor, textTrans = StyleTranslator.GetPrimaryFill(node)
	if textColor then
		label.TextColor3 = textColor
		label.TextTransparency = textTrans
	else
		if node.color then
			local c3, t = StyleTranslator.ToColor3(node.color)
			label.TextColor3 = c3
			label.TextTransparency = t
		else
			-- Default text color: Black for titles or White if parent is dark
			label.TextColor3 = Color3.fromRGB(0, 0, 0)
			label.TextTransparency = 0
		end
	end
	
	label.BackgroundTransparency = 1
end

return TextTranslator
