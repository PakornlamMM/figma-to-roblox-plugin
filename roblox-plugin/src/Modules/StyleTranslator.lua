--!strict
--[[
	StyleTranslator.lua
	Converts Figma colors, fills, gradients, corner radii, and strokes into Roblox UI styling instances.
	Supports backgroundColor on frames, fills array, 0-1 and 0-255 scales, and hex strings.
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type FigmaNode = Types.FigmaNode
type FigmaColor = Types.FigmaColor
type FigmaPaint = Types.FigmaPaint

local StyleTranslator = {}

--[[
	Converts any Figma color representation (0-1, 0-255, Hex string, table) to Color3 and transparency.
]]
function StyleTranslator.ToColor3(figmaColor: any?): (Color3, number)
	if not figmaColor then
		return Color3.new(1, 1, 1), 0
	end
	
	-- Scenario 1: Hex string e.g. "#1E2022" or "1E2022"
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
	
	-- Scenario 2: Color table { r, g, b, a? }
	if type(figmaColor) == "table" then
		local rawR = tonumber(figmaColor.r or figmaColor.red or figmaColor[1]) or 0
		local rawG = tonumber(figmaColor.g or figmaColor.green or figmaColor[2]) or 0
		local rawB = tonumber(figmaColor.b or figmaColor.blue or figmaColor[3]) or 0
		local rawA = figmaColor.a or figmaColor.alpha or figmaColor.opacity or figmaColor[4]
		
		-- Detect 0-255 vs 0-1 scale
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

--[[
	Extracts the primary visible paint fill from a Figma node.
	Checks fills array, backgroundColor, and direct color properties.
]]
function StyleTranslator.GetPrimaryFill(node: any): (Color3?, number)
	local nodeOpacity = if type(node.opacity) == "number" then math.clamp(node.opacity, 0, 1) else 1
	
	-- 1. Check fills array
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
					local color3, colorTrans = StyleTranslator.ToColor3(fill)
					return color3, colorTrans
				end
			end
		elseif type(fills) == "string" then
			local color3, colorTrans = StyleTranslator.ToColor3(fills)
			return color3, colorTrans
		end
	end
	
	-- 2. Check backgroundColor (Crucial for Figma Frames!)
	local bg = node.backgroundColor or node.bgColor or node.background
	if bg then
		local color3, colorTrans = StyleTranslator.ToColor3(bg)
		local effectiveAlpha = (1 - colorTrans) * nodeOpacity
		return color3, math.clamp(1 - effectiveAlpha, 0, 1)
	end
	
	-- 3. Check direct color on node
	if node.color and type(node.color) == "table" and (node.color.r or node.color[1]) then
		local color3, colorTrans = StyleTranslator.ToColor3(node.color)
		return color3, math.clamp(1 - ((1 - colorTrans) * nodeOpacity), 0, 1)
	end
	
	return nil, 1
end

--[[
	Applies background color, transparency, and gradients to a GuiObject.
]]
function StyleTranslator.ApplyBackground(guiObject: GuiObject, node: any)
	local color, transparency = StyleTranslator.GetPrimaryFill(node)
	
	if color then
		guiObject.BackgroundColor3 = color
		guiObject.BackgroundTransparency = transparency
	else
		guiObject.BackgroundTransparency = 1
	end
	
	guiObject.BorderSizePixel = 0
	
	if node.clipsContent ~= nil then
		guiObject.ClipsDescendants = node.clipsContent
	end
	
	-- Linear Gradient fill
	local fills = node.fills or node.fill
	if fills and type(fills) == "table" then
		for _, fill in ipairs(fills) do
			if type(fill) == "table" and fill.visible ~= false and fill.type == "GRADIENT_LINEAR" and fill.gradientStops then
				local colorKeypoints = {}
				for _, stop in ipairs(fill.gradientStops) do
					local stopColor = StyleTranslator.ToColor3(stop.color)
					local pos = math.clamp(stop.position or 0, 0, 1)
					table.insert(colorKeypoints, ColorSequenceKeypoint.new(pos, stopColor))
				end
				
				if #colorKeypoints >= 2 then
					local gradient = Instance.new("UIGradient")
					gradient.Name = "FigmaGradient"
					gradient.Color = ColorSequence.new(colorKeypoints)
					gradient.Parent = guiObject
				end
				break
			end
		end
	end
end

--[[
	Applies UICorner to round edges if cornerRadius > 0.
]]
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

--[[
	Applies UIStroke for outlines and borders.
]]
function StyleTranslator.ApplyStrokes(guiObject: GuiObject, node: any): UIStroke?
	local strokes = node.strokes or node.stroke
	local weight = tonumber(node.strokeWeight or node.borderWidth or node.strokeWidth) or 0
	
	if not strokes and weight <= 0 then
		return nil
	end
	
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
		
		if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
			uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		else
			uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		end
		
		uiStroke.Parent = guiObject
		return uiStroke
	end
	
	return nil
end

return StyleTranslator
