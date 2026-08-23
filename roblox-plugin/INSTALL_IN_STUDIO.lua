--!strict
--[[
	INSTALL_IN_STUDIO.lua
	Single-file bundled distribution of the FigmaToRoblox plugin.
	
	HOW TO RE-INSTALL:
	1. In Roblox Studio, open any place.
	2. In Explorer, create a Script (e.g. under ServerStorage or workspace).
	3. Paste this entire file into that Script.
	4. Right-click the Script in Explorer -> "Save as Local Plugin...".
	5. Overwrite the existing plugin file in your Studio plugins folder.
	6. In the Plugins tab, click "Figma to Roblox" -> The floating window will pop up immediately!
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")

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

-- =============================================================================
-- 1. Configuration
-- =============================================================================
local Config = {
	PluginName = "FigmaToRoblox",
	PluginId = "FigmaToRoblox_DockWidget_v2.3",
	ToolbarTitle = "Figma UI",
	ButtonTitle = "Figma to Roblox",
	ButtonTooltip = "Convert Figma JSON into native Roblox UI instances",
	ButtonIcon = "rbxassetid://6031075931",
	
	Widget = {
		InitialDockState = Enum.InitialDockState.Float,
		InitiallyEnabled = false,
		OverrideRestore = true,
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

-- =============================================================================
-- 2. Theme Manager (Crash-Safe Studio Theme Responsive)
-- =============================================================================
local ThemeManager = {}

type ThemeColors = {
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
}

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
	local mainBg = getStudioColor("MainBackground", Color3.fromRGB(46, 46, 46))
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

-- =============================================================================
-- 3. JSON Parser & Normalizer
-- =============================================================================
local JsonParser = {}

local function normalizeNode(rawNode: any): any?
	if type(rawNode) ~= "table" then
		return nil
	end
	
	local node = {
		id = tostring(rawNode.id or rawNode.name or HttpService:GenerateGUID(false)),
		name = tostring(rawNode.name or rawNode.id or "FigmaElement"),
		type = string.upper(tostring(rawNode.type or rawNode.nodeType or rawNode.kind or "FRAME")),
		visible = if rawNode.visible ~= nil then rawNode.visible else true,
		opacity = if type(rawNode.opacity) == "number" then rawNode.opacity else 1,
		absoluteBoundingBox = rawNode.absoluteBoundingBox or rawNode.absoluteRenderBounds or rawNode.bounds,
		size = rawNode.size,
		fills = rawNode.fills or rawNode.fill,
		backgroundColor = rawNode.backgroundColor or rawNode.bgColor,
		strokes = rawNode.strokes or rawNode.stroke,
		strokeWeight = rawNode.strokeWeight or rawNode.borderWidth or rawNode.strokeWidth,
		cornerRadius = rawNode.cornerRadius or rawNode.radius,
		rectangleCornerRadii = rawNode.rectangleCornerRadii,
		clipsContent = rawNode.clipsContent,
		layoutMode = rawNode.layoutMode,
		primaryAxisAlignItems = rawNode.primaryAxisAlignItems,
		counterAxisAlignItems = rawNode.counterAxisAlignItems,
		itemSpacing = rawNode.itemSpacing,
		paddingLeft = rawNode.paddingLeft,
		paddingRight = rawNode.paddingRight,
		paddingTop = rawNode.paddingTop,
		paddingBottom = rawNode.paddingBottom,
		characters = rawNode.characters or rawNode.text or rawNode.value or rawNode.content,
		style = rawNode.style or rawNode.textStyle,
		children = nil,
	}
	
	if not node.absoluteBoundingBox then
		if rawNode.width and rawNode.height then
			node.absoluteBoundingBox = {
				x = rawNode.x or 0,
				y = rawNode.y or 0,
				width = rawNode.width,
				height = rawNode.height,
			}
		elseif rawNode.size and type(rawNode.size) == "table" then
			node.absoluteBoundingBox = {
				x = rawNode.x or 0,
				y = rawNode.y or 0,
				width = rawNode.size.x or rawNode.size.width or 100,
				height = rawNode.size.y or rawNode.size.height or 100,
			}
		end
	end
	
	if rawNode.children and type(rawNode.children) == "table" then
		local children = {}
		for _, childRaw in ipairs(rawNode.children) do
			local childNode = normalizeNode(childRaw)
			if childNode then
				table.insert(children, childNode)
			end
		end
		node.children = children
	end
	
	return node
end

local function countNodes(node: any): number
	local count = 1
	if node.children and type(node.children) == "table" then
		for _, child in ipairs(node.children) do
			count += countNodes(child)
		end
	end
	return count
end

function JsonParser.Parse(rawJson: string): (boolean, any?, string?, number)
	local trimmed = string.match(rawJson, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return false, nil, "Please paste Figma JSON into the text box.", 0
	end
	
	local decodeSuccess, decoded = pcall(function()
		return HttpService:JSONDecode(trimmed)
	end)
	
	if not decodeSuccess or decoded == nil then
		return false, nil, string.format("Invalid JSON syntax: %s", tostring(decoded or "Unknown error")), 0
	end
	
	local candidate = decoded.document or decoded.data or decoded.root or decoded
	if candidate.nodes and type(candidate.nodes) == "table" then
		for _, v in pairs(candidate.nodes) do
			candidate = v.document or v
			break
		end
	elseif candidate.type == "DOCUMENT" and candidate.children and #candidate.children > 0 then
		local canvas = candidate.children[1]
		if canvas.children and #canvas.children > 0 then
			candidate = canvas.children[1]
		end
	end
	
	local root = normalizeNode(candidate)
	if not root then
		return false, nil, "Could not find a valid Figma root node.", 0
	end
	
	local total = countNodes(root)
	return true, root, nil, total
end

function JsonParser.GetSample(): string
	return HttpService:JSONEncode({
		id = "10:100",
		name = "DonationCard",
		type = "FRAME",
		absoluteBoundingBox = { x = 0, y = 0, width = 640, height = 360 },
		cornerRadius = 32,
		backgroundColor = { r = 0.78, g = 0.78, b = 0.78, a = 1 },
		strokes = { { type = "SOLID", visible = true, color = { r = 0, g = 0, b = 0, a = 1 } } },
		strokeWeight = 12,
		clipsContent = true,
		children = {
			{
				id = "10:101",
				name = "TitleText",
				type = "TEXT",
				absoluteBoundingBox = { x = 26, y = 36, width = 588, height = 77 },
				characters = "Wanna donate me?",
				style = { fontFamily = "FredokaOne", fontWeight = 700, fontSize = 48, textAlignHorizontal = "CENTER", textAlignVertical = "CENTER" },
				fills = { { type = "SOLID", visible = true, color = { r = 0, g = 0, b = 0, a = 1 } } },
			},
			{
				id = "10:102",
				name = "TextButton",
				type = "FRAME",
				absoluteBoundingBox = { x = 50, y = 160, width = 540, height = 130 },
				cornerRadius = 65,
				fills = { { type = "SOLID", visible = true, color = { r = 0.05, g = 0.82, b = 0.18, a = 1 } } },
				strokes = { { type = "SOLID", visible = true, color = { r = 0, g = 0, b = 0, a = 1 } } },
				strokeWeight = 10,
				clipsContent = true,
				children = {
					{
						id = "10:103",
						name = "YES",
						type = "TEXT",
						absoluteBoundingBox = { x = 50, y = 160, width = 540, height = 130 },
						characters = "YES",
						style = { fontFamily = "FredokaOne", fontWeight = 700, fontSize = 52, textAlignHorizontal = "CENTER", textAlignVertical = "CENTER" },
						fills = { { type = "SOLID", visible = true, color = { r = 1, g = 1, b = 1, a = 1 } } },
					},
				},
			},
		},
	})
end

-- =============================================================================
-- 4. Translators & Generator Pipeline
-- =============================================================================
local StyleTranslator = {}
function StyleTranslator.ToColor3(figmaColor: any?): (Color3, number)
	if not figmaColor then
		return Color3.new(1, 1, 1), 0
	end
	
	if type(figmaColor) == "string" then
		local hex = string.gsub(figmaColor, "#", "")
		if #hex >= 6 then
			local r = tonumber(string.sub(hex, 1, 2), 16) or 255
			local g = tonumber(string.sub(hex, 3, 4), 16) or 255
			local b = tonumber(string.sub(hex, 5, 6), 16) or 255
			local a = 1
			if #hex >= 8 then
				a = (tonumber(string.sub(hex, 7, 8), 16) or 255) / 255
			end
			return Color3.fromRGB(r, g, b), 1 - a
		end
	end
	
	if type(figmaColor) == "table" then
		local rawR = tonumber(figmaColor.r or figmaColor.red or figmaColor[1]) or 0
		local rawG = tonumber(figmaColor.g or figmaColor.green or figmaColor[2]) or 0
		local rawB = tonumber(figmaColor.b or figmaColor.blue or figmaColor[3]) or 0
		local rawA = figmaColor.a or figmaColor.alpha or figmaColor.opacity or figmaColor[4]
		
		local is255 = (rawR > 1 or rawG > 1 or rawB > 1)
		local r = if is255 then math.clamp(rawR / 255, 0, 1) else math.clamp(rawR, 0, 1)
		local g = if is255 then math.clamp(rawG / 255, 0, 1) else math.clamp(rawG, 0, 1)
		local b = if is255 then math.clamp(rawB / 255, 0, 1) else math.clamp(rawB, 0, 1)
		
		local alpha = 1
		if rawA ~= nil then
			local numA = tonumber(rawA) or 1
			alpha = if numA > 1 then math.clamp(numA / 255, 0, 1) else math.clamp(numA, 0, 1)
		end
		
		return Color3.new(r, g, b), 1 - alpha
	end
	
	return Color3.new(1, 1, 1), 0
end

function StyleTranslator.GetPrimaryFill(node: any): (Color3?, number)
	local nodeOpacity = if type(node.opacity) == "number" then math.clamp(node.opacity, 0, 1) else 1
	
	local fills = node.fills or node.fill
	if fills then
		if type(fills) == "table" and (fills.color or fills.r or fills.type == "SOLID") and not fills[1] then
			fills = { fills }
		end
		if type(fills) == "table" and #fills > 0 then
			for _, fill in ipairs(fills) do
				if type(fill) == "table" and fill.visible ~= false then
					local fillOpacity = if type(fill.opacity) == "number" then math.clamp(fill.opacity, 0, 1) else 1
					local fillType = string.upper(tostring(fill.type or "SOLID"))
					if fill.color or fill.r or fillType == "SOLID" then
						local colorData = fill.color or fill
						local color3, colorTrans = StyleTranslator.ToColor3(colorData)
						local effectiveAlpha = (1 - colorTrans) * fillOpacity * nodeOpacity
						return color3, math.clamp(1 - effectiveAlpha, 0, 1)
					elseif fillType == "IMAGE" then
						return Color3.new(1, 1, 1), 0
					end
				elseif type(fill) == "string" then
					return StyleTranslator.ToColor3(fill)
				end
			end
		elseif type(fills) == "string" then
			return StyleTranslator.ToColor3(fills)
		end
	end
	
	local bg = node.backgroundColor or node.bgColor or node.background
	if bg then
		local color3, colorTrans = StyleTranslator.ToColor3(bg)
		return color3, math.clamp(1 - ((1 - colorTrans) * nodeOpacity), 0, 1)
	end
	
	if node.color and type(node.color) == "table" and (node.color.r or node.color[1]) then
		local color3, colorTrans = StyleTranslator.ToColor3(node.color)
		return color3, math.clamp(1 - ((1 - colorTrans) * nodeOpacity), 0, 1)
	end
	
	return nil, 1
end

function StyleTranslator.ApplyBackground(guiObject: GuiObject, node: any)
	local color, trans = StyleTranslator.GetPrimaryFill(node)
	if color then
		guiObject.BackgroundColor3 = color
		guiObject.BackgroundTransparency = trans
	else
		guiObject.BackgroundTransparency = 1
	end
	guiObject.BorderSizePixel = 0
	if node.clipsContent ~= nil then
		guiObject.ClipsDescendants = node.clipsContent
	end
end

function StyleTranslator.ApplyCorners(guiObject: GuiObject, node: any): UICorner?
	local radius = tonumber(node.cornerRadius or node.radius or node.borderRadius) or 0
	if radius <= 0 and node.rectangleCornerRadii and type(node.rectangleCornerRadii) == "table" then
		for _, r in ipairs(node.rectangleCornerRadii) do
			local num = tonumber(r)
			if num and num > 0 then
				radius = num
				break
			end
		end
	end
	if radius > 0 then
		local corner = Instance.new("UICorner")
		corner.Name = "FigmaCorner"
		corner.CornerRadius = UDim.new(0, math.round(radius))
		corner.Parent = guiObject
		return corner
	end
	return nil
end

function StyleTranslator.ApplyStrokes(guiObject: GuiObject, node: any): UIStroke?
	local strokes = node.strokes or node.stroke
	local weight = tonumber(node.strokeWeight or node.borderWidth or node.strokeWidth) or 0
	
	if not strokes and weight <= 0 then return nil end
	if type(strokes) == "table" and not strokes[1] and (strokes.color or strokes.r) then
		strokes = { strokes }
	end
	
	local strokeColor = Color3.new(0, 0, 0)
	local strokeTrans = 0
	local hasStroke = false
	
	if type(strokes) == "table" and #strokes > 0 then
		for _, stroke in ipairs(strokes) do
			if type(stroke) == "table" and stroke.visible ~= false then
				local colorData = stroke.color or stroke
				strokeColor, strokeTrans = StyleTranslator.ToColor3(colorData)
				local strokeOpacity = if type(stroke.opacity) == "number" then math.clamp(stroke.opacity, 0, 1) else 1
				strokeTrans = math.clamp(1 - ((1 - strokeTrans) * strokeOpacity), 0, 1)
				hasStroke = true
				break
			end
		end
	elseif type(strokes) == "string" then
		strokeColor, strokeTrans = StyleTranslator.ToColor3(strokes)
		hasStroke = true
	end
	
	if not hasStroke and weight > 0 then
		strokeColor = Color3.new(0, 0, 0)
		strokeTrans = 0
		hasStroke = true
	end
	
	if hasStroke and weight > 0 then
		local uiStroke = Instance.new("UIStroke")
		uiStroke.Name = "FigmaStroke"
		uiStroke.Color = strokeColor
		uiStroke.Thickness = math.max(1, math.round(weight))
		uiStroke.Transparency = strokeTrans
		uiStroke.ApplyStrokeMode = if guiObject:IsA("TextLabel") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
		uiStroke.Parent = guiObject
		return uiStroke
	end
	return nil
end

local LayoutTranslator = {}
function LayoutTranslator.CalculateTransform(node: any, parentRect: any?, options: any): (UDim2, UDim2, Vector2)
	local nodeRect = node.absoluteBoundingBox or node.absoluteRenderBounds or node.size or node.bounds
	local width = 100
	local height = 100
	if nodeRect then
		width = math.max(tonumber(nodeRect.width or nodeRect.w or nodeRect.x) or 100, 1)
		height = math.max(tonumber(nodeRect.height or nodeRect.h or nodeRect.y) or 100, 1)
	elseif node.width and node.height then
		width = math.max(tonumber(node.width) or 100, 1)
		height = math.max(tonumber(node.height) or 100, 1)
	end
	
	if not parentRect then
		return UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, math.round(width), 0, math.round(height)), Vector2.new(0.5, 0.5)
	end
	
	local parentWidth = math.max(tonumber(parentRect.width or parentRect.w) or 100, 1)
	local parentHeight = math.max(tonumber(parentRect.height or parentRect.h) or 100, 1)
	
	local rawX = if nodeRect then (nodeRect.x or nodeRect.left) else node.x
	local rawY = if nodeRect then (nodeRect.y or nodeRect.top) else node.y
	local parentX = parentRect.x or parentRect.left or 0
	local parentY = parentRect.y or parentRect.top or 0
	
	local relX = 0
	local relY = 0
	
	if rawX ~= nil and parentX ~= nil then
		if rawX >= parentX and (rawX - parentX) < (parentWidth * 2) then
			relX = rawX - parentX
			relY = (rawY or 0) - parentY
		else
			relX = rawX
			relY = rawY or 0
		end
	elseif rawX ~= nil then
		relX = rawX
		relY = rawY or 0
	end
	
	local mode = if type(options) == "table" and options.sizingMode then options.sizingMode else "ResponsiveScale"
	local position: UDim2
	local size: UDim2
	
	if mode == "ResponsiveScale" then
		position = UDim2.new(relX / parentWidth, 0, relY / parentHeight, 0)
		size = UDim2.new(width / parentWidth, 0, height / parentHeight, 0)
	elseif mode == "ExactOffset" then
		position = UDim2.new(0, math.round(relX), 0, math.round(relY))
		size = UDim2.new(0, math.round(width), 0, math.round(height))
	else
		position = UDim2.new(relX / parentWidth, 0, relY / parentHeight, 0)
		size = UDim2.new(0, math.round(width), 0, math.round(height))
	end
	
	return position, size, Vector2.new(0, 0)
end

function LayoutTranslator.ApplyAutoLayout(guiObject: GuiObject, node: any)
	local layoutMode = node.layoutMode
	if not layoutMode or layoutMode == "NONE" then
		return
	end
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Name = "FigmaListLayout"
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.FillDirection = if layoutMode == "HORIZONTAL" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, math.round(node.itemSpacing or 0))
	
	local primaryAlign = node.primaryAxisAlignItems or "MIN"
	local counterAlign = node.counterAxisAlignItems or "MIN"
	
	if layoutMode == "HORIZONTAL" then
		listLayout.HorizontalAlignment = if primaryAlign == "CENTER" then Enum.HorizontalAlignment.Center elseif primaryAlign == "MAX" then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
		listLayout.VerticalAlignment = if counterAlign == "CENTER" then Enum.VerticalAlignment.Center elseif counterAlign == "MAX" then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top
	else
		listLayout.VerticalAlignment = if primaryAlign == "CENTER" then Enum.VerticalAlignment.Center elseif primaryAlign == "MAX" then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top
		listLayout.HorizontalAlignment = if counterAlign == "CENTER" then Enum.HorizontalAlignment.Center elseif counterAlign == "MAX" then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	end
	listLayout.Parent = guiObject
	
	local padL = node.paddingLeft or 0
	local padR = node.paddingRight or 0
	local padT = node.paddingTop or 0
	local padB = node.paddingBottom or 0
	if padL > 0 or padR > 0 or padT > 0 or padB > 0 then
		local uiPadding = Instance.new("UIPadding")
		uiPadding.Name = "FigmaPadding"
		uiPadding.PaddingLeft = UDim.new(0, math.round(padL))
		uiPadding.PaddingRight = UDim.new(0, math.round(padR))
		uiPadding.PaddingTop = UDim.new(0, math.round(padT))
		uiPadding.PaddingBottom = UDim.new(0, math.round(padB))
		uiPadding.Parent = guiObject
	end
end

local TextTranslator = {}
local FONT_MAP = {
	["buildersans"] = Config.UI.Font,
	["buildersansbold"] = Config.UI.FontBold,
	["inter"] = Enum.Font.Gotham,
	["roboto"] = Enum.Font.Roboto,
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
	["bangers"] = Enum.Font.Bangers,
}

function TextTranslator.ResolveFont(style: any?): Enum.Font
	if not style then
		return Config.UI.Font
	end
	local fam = string.lower(string.gsub(tostring(style.fontFamily or style.font or "buildersans"), "%s+", ""))
	local weight = tonumber(style.fontWeight or style.weight or 400) or 400
	if FONT_MAP[fam] then
		if weight >= 700 then
			if fam == "gotham" or fam == "inter" or fam == "poppins" then return Enum.Font.GothamBold end
			if fam == "sourcesans" or fam == "sourcesanspro" then return Enum.Font.SourceSansBold end
			if fam == "buildersans" then return Config.UI.FontBold end
			if fam == "arial" then return Enum.Font.ArialBold end
		end
		return FONT_MAP[fam]
	end
	if weight >= 700 then return Config.UI.FontBold end
	return Config.UI.Font
end

function TextTranslator.ApplyText(label: TextLabel, node: any)
	local style = node.style or node.textStyle or node
	label.Text = tostring(node.characters or node.text or node.value or node.content or node.name or "")
	label.Font = TextTranslator.ResolveFont(style)
	local fontSize = style.fontSize or node.fontSize or 28
	label.TextSize = math.clamp(math.round(tonumber(fontSize) or 28), 8, 100)
	
	local xAlign = string.upper(tostring(style.textAlignHorizontal or style.textAlign or "CENTER"))
	label.TextXAlignment = if xAlign == "LEFT" then Enum.TextXAlignment.Left elseif xAlign == "RIGHT" then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center
	
	local yAlign = string.upper(tostring(style.textAlignVertical or style.verticalAlign or "CENTER"))
	label.TextYAlignment = if yAlign == "TOP" then Enum.TextYAlignment.Top elseif yAlign == "BOTTOM" then Enum.TextYAlignment.Bottom else Enum.TextYAlignment.Center
	
	label.TextWrapped = true
	label.AutoLocalize = false
	
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
			label.TextColor3 = Color3.fromRGB(0, 0, 0)
			label.TextTransparency = 0
		end
	end
	label.BackgroundTransparency = 1
end

local InstanceGenerator = {}

local function resolveNodeType(node: any): string
	local t = string.upper(tostring(node.type or node.nodeType or node.kind or node.tag or ""))
	if t == "TEXT" or (node.characters ~= nil and tostring(node.characters) ~= "") or (node.text ~= nil and tostring(node.text) ~= "") then
		return "TEXT"
	end
	if t == "VECTOR" or t == "ELLIPSE" or t == "STAR" or t == "POLYGON" or t == "LINE" or t == "IMAGE" then
		return "IMAGE"
	end
	local fills = node.fills or node.fill
	if fills and type(fills) == "table" then
		if fills.type and string.upper(tostring(fills.type)) == "IMAGE" then return "IMAGE" end
		for _, f in ipairs(fills) do
			if type(f) == "table" and string.upper(tostring(f.type or "")) == "IMAGE" then return "IMAGE" end
		end
	end
	return "FRAME"
end

local function buildHierarchy(node: any, parent: Instance, parentRect: any?, stats: any, options: any): GuiObject?
	if options and options.ignoreInvisible and node.visible == false then
		return nil
	end
	
	local resolvedType = resolveNodeType(node)
	local gui: GuiObject
	
	if resolvedType == "TEXT" then
		local label = Instance.new("TextLabel")
		TextTranslator.ApplyText(label, node)
		gui = label
		stats.TextLabels += 1
	elseif resolvedType == "IMAGE" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		StyleTranslator.ApplyBackground(img, node)
		gui = img
		stats.ImageLabels += 1
	else
		local frame = Instance.new("Frame")
		StyleTranslator.ApplyBackground(frame, node)
		gui = frame
		stats.Frames += 1
	end
	
	gui.Name = tostring(node.name or node.id or "FigmaElement")
	local pos, sz, anchor = LayoutTranslator.CalculateTransform(node, parentRect, options)
	gui.Position = pos
	gui.Size = sz
	gui.AnchorPoint = anchor
	
	if StyleTranslator.ApplyCorners(gui, node) then stats.Corners += 1 end
	if StyleTranslator.ApplyStrokes(gui, node) then stats.Strokes += 1 end
	LayoutTranslator.ApplyAutoLayout(gui, node)
	if node.layoutMode and node.layoutMode ~= "NONE" then stats.Layouts += 1 end
	
	gui.Parent = parent
	stats.Total += 1
	
	local curRect = node.absoluteBoundingBox or node.absoluteRenderBounds or node.size or node.bounds or parentRect
	local children = node.children
	if children and type(children) == "table" and #children > 0 then
		for _, child in ipairs(children) do
			if type(child) == "table" then
				buildHierarchy(child, gui, curRect, stats, options)
			end
		end
	end
	return gui
end

function InstanceGenerator.Generate(root: any, target: Instance, options: any): (GuiObject?, any)
	local stats = { Total = 0, Frames = 0, TextLabels = 0, ImageLabels = 0, Corners = 0, Strokes = 0, Layouts = 0 }
	local rootGui = buildHierarchy(root, target, nil, stats, options or { sizingMode = "ResponsiveScale" })
	return rootGui, stats
end

-- =============================================================================
-- 5. DockWidget UI Setup & Event Wiring
-- =============================================================================
local toolbar = plugin:CreateToolbar(Config.ToolbarTitle)
local toggleButton = toolbar:CreateButton(
	Config.ButtonTitle,
	Config.ButtonTooltip,
	Config.ButtonIcon
)
toggleButton.ClickableWhenViewportHidden = true

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

for _, child in ipairs(dockWidget:GetChildren()) do
	if child:IsA("GuiObject") then
		child:Destroy()
	end
end

local colors = ThemeManager.GetColors()

local rootFrame = Instance.new("Frame")
rootFrame.Name = "RootFrame"
rootFrame.Size = UDim2.new(1, 0, 1, 0)
rootFrame.BackgroundColor3 = colors.MainBackground
rootFrame.BorderSizePixel = 0
rootFrame.Parent = dockWidget

local rootPadding = Instance.new("UIPadding")
rootPadding.PaddingTop = UDim.new(0, Config.UI.Padding)
rootPadding.PaddingBottom = UDim.new(0, Config.UI.Padding)
rootPadding.PaddingLeft = UDim.new(0, Config.UI.Padding)
rootPadding.PaddingRight = UDim.new(0, Config.UI.Padding)
rootPadding.Parent = rootFrame

local rootLayout = Instance.new("UIListLayout")
rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
rootLayout.Padding = UDim.new(0, Config.UI.ElementGap)
rootLayout.FillDirection = Enum.FillDirection.Vertical
rootLayout.Parent = rootFrame

-- Header
local headerFrame = Instance.new("Frame")
headerFrame.Size = UDim2.new(1, 0, 0, 36)
headerFrame.BackgroundTransparency = 1
headerFrame.LayoutOrder = 1
headerFrame.Parent = rootFrame

local headerList = Instance.new("UIListLayout")
headerList.FillDirection = Enum.FillDirection.Horizontal
headerList.VerticalAlignment = Enum.VerticalAlignment.Center
headerList.Padding = UDim.new(0, 8)
headerList.Parent = headerFrame

local iconBadge = Instance.new("Frame")
iconBadge.Size = UDim2.new(0, 32, 0, 32)
iconBadge.BackgroundColor3 = colors.Accent
iconBadge.BorderSizePixel = 0
iconBadge.Parent = headerFrame

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = Config.UI.CornerRadius
iconCorner.Parent = iconBadge

local iconImg = Instance.new("ImageLabel")
iconImg.Size = UDim2.new(0, 20, 0, 20)
iconImg.Position = UDim2.new(0.5, 0, 0.5, 0)
iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
iconImg.BackgroundTransparency = 1
iconImg.Image = Config.ButtonIcon
iconImg.ImageColor3 = Color3.new(1, 1, 1)
iconImg.Parent = iconBadge

local titleTextFrame = Instance.new("Frame")
titleTextFrame.Size = UDim2.new(1, -45, 1, 0)
titleTextFrame.BackgroundTransparency = 1
titleTextFrame.Parent = headerFrame

local titleTextList = Instance.new("UIListLayout")
titleTextList.FillDirection = Enum.FillDirection.Vertical
titleTextList.VerticalAlignment = Enum.VerticalAlignment.Center
titleTextList.Parent = titleTextFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 18)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Config.UI.FontBold
titleLabel.TextSize = Config.UI.TextSizeHeader
titleLabel.TextColor3 = colors.MainText
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Figma To Roblox"
titleLabel.Parent = titleTextFrame

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 14)
subLabel.BackgroundTransparency = 1
subLabel.Font = Config.UI.Font
subLabel.TextSize = Config.UI.TextSizeSmall
subLabel.TextColor3 = colors.SubText
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Text = "Paste Figma JSON to generate Studio UI hierarchy"
subLabel.Parent = titleTextFrame

-- Action Toolbar
local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, 0, 0, 24)
actionRow.BackgroundTransparency = 1
actionRow.LayoutOrder = 2
actionRow.Parent = rootFrame

local actionRowLayout = Instance.new("UIListLayout")
actionRowLayout.FillDirection = Enum.FillDirection.Horizontal
actionRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
actionRowLayout.Padding = UDim.new(0, 8)
actionRowLayout.Parent = actionRow

local sampleButton = Instance.new("TextButton")
sampleButton.Size = UDim2.new(0, 90, 1, 0)
sampleButton.BackgroundColor3 = colors.ButtonBackground
sampleButton.BorderSizePixel = 0
sampleButton.Font = Config.UI.Font
sampleButton.TextSize = Config.UI.TextSizeSmall
sampleButton.TextColor3 = colors.MainText
sampleButton.Text = "Load Sample"
sampleButton.Parent = actionRow

local sampleCorner = Instance.new("UICorner")
sampleCorner.CornerRadius = Config.UI.SmallCornerRadius
sampleCorner.Parent = sampleButton

local clearButton = Instance.new("TextButton")
clearButton.Size = UDim2.new(0, 60, 1, 0)
clearButton.BackgroundColor3 = colors.ButtonBackground
clearButton.BorderSizePixel = 0
clearButton.Font = Config.UI.Font
clearButton.TextSize = Config.UI.TextSizeSmall
clearButton.TextColor3 = colors.MainText
clearButton.Text = "Clear"
clearButton.Parent = actionRow

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = Config.UI.SmallCornerRadius
clearCorner.Parent = clearButton

-- JSON Input Box
local inputContainer = Instance.new("Frame")
inputContainer.Size = UDim2.new(1, 0, 1, -165)
inputContainer.BackgroundColor3 = colors.InputFieldBackground
inputContainer.BorderSizePixel = 0
inputContainer.LayoutOrder = 3
inputContainer.ClipsDescendants = true
inputContainer.Parent = rootFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = Config.UI.CornerRadius
inputCorner.Parent = inputContainer

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = colors.Border
inputStroke.Thickness = 1
inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
inputStroke.Parent = inputContainer

local scrollContainer = Instance.new("ScrollingFrame")
scrollContainer.Size = UDim2.new(1, 0, 1, 0)
scrollContainer.BackgroundTransparency = 1
scrollContainer.BorderSizePixel = 0
scrollContainer.ScrollBarThickness = 6
scrollContainer.ScrollBarImageColor3 = colors.DimmedText
scrollContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollContainer.CanvasSize = UDim2.new(1, 0, 0, 0)
scrollContainer.Parent = inputContainer

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingTop = UDim.new(0, 8)
scrollPadding.PaddingBottom = UDim.new(0, 8)
scrollPadding.PaddingLeft = UDim.new(0, 10)
scrollPadding.PaddingRight = UDim.new(0, 10)
scrollPadding.Parent = scrollContainer

local jsonTextBox = Instance.new("TextBox")
jsonTextBox.Size = UDim2.new(1, 0, 1, 0)
jsonTextBox.AutomaticSize = Enum.AutomaticSize.Y
jsonTextBox.BackgroundTransparency = 1
jsonTextBox.BorderSizePixel = 0
jsonTextBox.ClearTextOnFocus = false
jsonTextBox.MultiLine = true
jsonTextBox.TextWrapped = true
jsonTextBox.Font = Config.UI.FontCode
jsonTextBox.TextSize = Config.UI.TextSizeRegular
jsonTextBox.TextColor3 = colors.MainText
jsonTextBox.PlaceholderColor3 = colors.DimmedText
jsonTextBox.PlaceholderText = "-- Paste Figma JSON string here --\n\nSupports:\n• Figma REST API responses\n• Custom Figma plugin node exports"
jsonTextBox.TextXAlignment = Enum.TextXAlignment.Left
jsonTextBox.TextYAlignment = Enum.TextYAlignment.Top
jsonTextBox.Text = ""
jsonTextBox.Parent = scrollContainer

-- Status Bar
local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(1, 0, 0, 24)
statusFrame.BackgroundColor3 = colors.SecondaryBackground
statusFrame.BorderSizePixel = 0
statusFrame.LayoutOrder = 4
statusFrame.Parent = rootFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = Config.UI.SmallCornerRadius
statusCorner.Parent = statusFrame

local statusPadding = Instance.new("UIPadding")
statusPadding.PaddingLeft = UDim.new(0, 8)
statusPadding.PaddingRight = UDim.new(0, 8)
statusPadding.Parent = statusFrame

local statusLayout = Instance.new("UIListLayout")
statusLayout.FillDirection = Enum.FillDirection.Horizontal
statusLayout.VerticalAlignment = Enum.VerticalAlignment.Center
statusLayout.Padding = UDim.new(0, 6)
statusLayout.Parent = statusFrame

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.BackgroundColor3 = colors.DimmedText
statusDot.BorderSizePixel = 0
statusDot.Parent = statusFrame

local statusDotCorner = Instance.new("UICorner")
statusDotCorner.CornerRadius = UDim.new(1, 0)
statusDotCorner.Parent = statusDot

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Config.UI.Font
statusLabel.TextSize = Config.UI.TextSizeSmall
statusLabel.TextColor3 = colors.SubText
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Text = "Ready. Paste JSON above and click Generate."
statusLabel.Parent = statusFrame

-- Generate Button
local generateButton = Instance.new("TextButton")
generateButton.Size = UDim2.new(1, 0, 0, 38)
generateButton.BackgroundColor3 = colors.Accent
generateButton.BorderSizePixel = 0
generateButton.LayoutOrder = 5
generateButton.Font = Config.UI.FontBold
generateButton.TextSize = Config.UI.TextSizeRegular + 1
generateButton.TextColor3 = colors.AccentText
generateButton.Text = "⚡ Generate UI in StarterGui"
generateButton.AutoButtonColor = true
generateButton.Parent = rootFrame

local generateCorner = Instance.new("UICorner")
generateCorner.CornerRadius = Config.UI.CornerRadius
generateCorner.Parent = generateButton

ThemeManager.OnThemeChanged(function(newColors: ThemeColors)
	colors = newColors
	rootFrame.BackgroundColor3 = newColors.MainBackground
	iconBadge.BackgroundColor3 = newColors.Accent
	titleLabel.TextColor3 = newColors.MainText
	subLabel.TextColor3 = newColors.SubText
	sampleButton.BackgroundColor3 = newColors.ButtonBackground
	sampleButton.TextColor3 = newColors.MainText
	clearButton.BackgroundColor3 = newColors.ButtonBackground
	clearButton.TextColor3 = newColors.MainText
	inputContainer.BackgroundColor3 = newColors.InputFieldBackground
	inputStroke.Color = newColors.Border
	scrollContainer.ScrollBarImageColor3 = newColors.DimmedText
	jsonTextBox.TextColor3 = newColors.MainText
	jsonTextBox.PlaceholderColor3 = newColors.DimmedText
	statusFrame.BackgroundColor3 = newColors.SecondaryBackground
	statusLabel.TextColor3 = newColors.SubText
	generateButton.BackgroundColor3 = newColors.Accent
end)

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

local function setStatus(msg: string, statusType: "idle" | "success" | "warning" | "error" | "working")
	statusLabel.Text = msg
	if statusType == "success" then
		statusDot.BackgroundColor3 = colors.Success
		statusLabel.TextColor3 = colors.Success
	elseif statusType == "error" then
		statusDot.BackgroundColor3 = colors.Error
		statusLabel.TextColor3 = colors.Error
	elseif statusType == "working" then
		statusDot.BackgroundColor3 = colors.Accent
		statusLabel.TextColor3 = colors.MainText
	else
		statusDot.BackgroundColor3 = colors.DimmedText
		statusLabel.TextColor3 = colors.SubText
	end
end

sampleButton.MouseButton1Click:Connect(function()
	jsonTextBox.Text = JsonParser.GetSample()
	setStatus("Loaded sample Figma JSON. Click 'Generate UI' to test.", "idle")
end)

clearButton.MouseButton1Click:Connect(function()
	jsonTextBox.Text = ""
	setStatus("Cleared. Paste Figma JSON above.", "idle")
end)

generateButton.MouseButton1Click:Connect(function()
	local raw = jsonTextBox.Text
	setStatus("Parsing JSON...", "working")
	
	local ok, rootNode, err, count = JsonParser.Parse(raw)
	if not ok or not rootNode then
		setStatus(err or "Failed to parse JSON.", "error")
		return
	end
	
	local recordingSuccess, recordingId = pcall(function()
		return ChangeHistoryService:TryBeginRecording("Generate Figma UI")
	end)
	
	local statsResult
	local genSuccess, genErr = pcall(function()
		local screenGuiName = rootNode.name or "FigmaImport"
		local existing = StarterGui:FindFirstChild(screenGuiName)
		if existing and existing:IsA("ScreenGui") then
			existing:Destroy()
		end
		
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = screenGuiName
		screenGui.ResetOnSpawn = false
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.Parent = StarterGui
		
		local rootGui, stats = InstanceGenerator.Generate(rootNode, screenGui, { sizingMode = "ResponsiveScale" })
		statsResult = stats
		
		Selection:Set({ screenGui })
		
		print(string.format(
			"[FigmaToRoblox] Generated '%s' in StarterGui (%d Instances: %d Frames, %d TextLabels, %d Images, %d Corners, %d Strokes, %d Layouts)",
			screenGuiName, stats.Total, stats.Frames, stats.TextLabels, stats.ImageLabels, stats.Corners, stats.Strokes, stats.Layouts
		))
	end)
	
	if recordingSuccess and recordingId then
		if genSuccess then
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		else
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
		end
	else
		ChangeHistoryService:SetWaypoint("Generate Figma UI")
	end
	
	if genSuccess and statsResult then
		setStatus(string.format("✓ Generated '%s' (%d elements: %d text, %d img)!", rootNode.name, statsResult.Total, statsResult.TextLabels, statsResult.ImageLabels), "success")
	else
		setStatus(string.format("Generation error: %s", tostring(genErr)), "error")
	end
end)

print("[FigmaToRoblox] Bundled plugin ready.")
