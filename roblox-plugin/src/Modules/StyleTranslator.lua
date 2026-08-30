--!strict
--[[
	StyleTranslator.lua
	Converts Figma colors, solid fills, vertical/horizontal/rainbow gradients,
	drop shadows, corner radii (including stadium/pill buttons), and strokes into native Roblox UI styling instances.
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type FigmaNode = Types.FigmaNode
type FigmaColor = Types.FigmaColor
type FigmaPaint = Types.FigmaPaint

local StyleTranslator = {}

-- Standard high-fidelity 9-slice soft drop shadow asset
local SHADOW_ASSET_ID = "rbxassetid://1316045217"
local SHADOW_SLICE_CENTER = Rect.new(10, 10, 118, 118)

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
	Safely builds a validated, sorted Roblox ColorSequence adhering to engine limits (0..1, <= 20 keypoints).
]]
local function buildColorSequence(stops: { any }): ColorSequence?
	if not stops or #stops == 0 then
		return nil
	end
	
	local parsed = {}
	for _, stop in ipairs(stops) do
		if type(stop) == "table" then
			local colorData = stop.color or stop
			local stopColor, _ = StyleTranslator.ToColor3(colorData)
			local rawPos = tonumber(stop.position or stop.pos or stop.offset or stop.location) or 0
			table.insert(parsed, { Time = math.clamp(rawPos, 0, 1), Color = stopColor })
		end
	end
	
	if #parsed == 0 then
		return nil
	end
	
	-- Sort keypoints ascending by position
	table.sort(parsed, function(a, b)
		return a.Time < b.Time
	end)
	
	-- Ensure distinct, strictly increasing positions (min step 0.001)
	for i = 2, #parsed do
		if parsed[i].Time <= parsed[i - 1].Time then
			parsed[i].Time = math.min(1, parsed[i - 1].Time + 0.001)
		end
	end
	
	-- Ensure starting point at Time = 0
	if parsed[1].Time > 0 then
		table.insert(parsed, 1, { Time = 0, Color = parsed[1].Color })
	end
	
	-- Ensure end point at Time = 1
	if parsed[#parsed].Time < 1 then
		table.insert(parsed, { Time = 1, Color = parsed[#parsed].Color })
	end
	
	-- Cap at 20 keypoints (Roblox engine limit)
	while #parsed > 20 do
		table.remove(parsed, #parsed - 1)
	end
	
	if #parsed < 2 then
		return nil
	end
	
	local keypoints = {}
	for _, p in ipairs(parsed) do
		table.insert(keypoints, ColorSequenceKeypoint.new(p.Time, p.Color))
	end
	
	local success, seq = pcall(function()
		return ColorSequence.new(keypoints)
	end)
	
	return if success then seq else nil
end

--[[
	Safely builds a validated, sorted Roblox NumberSequence for transparency.
]]
local function buildTransparencySequence(stops: { any }, nodeOpacity: number): NumberSequence?
	if not stops or #stops == 0 then
		return nil
	end
	
	local parsed = {}
	for _, stop in ipairs(stops) do
		if type(stop) == "table" then
			local colorData = stop.color or stop
			local _, stopTrans = StyleTranslator.ToColor3(colorData)
			local rawPos = tonumber(stop.position or stop.pos or stop.offset or stop.location) or 0
			local effectiveTrans = math.clamp(1 - ((1 - stopTrans) * nodeOpacity), 0, 1)
			table.insert(parsed, { Time = math.clamp(rawPos, 0, 1), Value = effectiveTrans })
		end
	end
	
	if #parsed == 0 then
		return nil
	end
	
	table.sort(parsed, function(a, b)
		return a.Time < b.Time
	end)
	
	for i = 2, #parsed do
		if parsed[i].Time <= parsed[i - 1].Time then
			parsed[i].Time = math.min(1, parsed[i - 1].Time + 0.001)
		end
	end
	
	if parsed[1].Time > 0 then
		table.insert(parsed, 1, { Time = 0, Value = parsed[1].Value })
	end
	
	if parsed[#parsed].Time < 1 then
		table.insert(parsed, { Time = 1, Value = parsed[#parsed].Value })
	end
	
	while #parsed > 20 do
		table.remove(parsed, #parsed - 1)
	end
	
	if #parsed < 2 then
		return nil
	end
	
	local keypoints = {}
	for _, p in ipairs(parsed) do
		table.insert(keypoints, NumberSequenceKeypoint.new(p.Time, p.Value))
	end
	
	local success, seq = pcall(function()
		return NumberSequence.new(keypoints)
	end)
	
	return if success then seq else nil
end

--[[
	Extracts the primary visible paint fill from a Figma node.
]]
function StyleTranslator.GetPrimaryFill(node: any): (Color3?, number, any?)
	local nodeOpacity = if type(node.opacity) == "number" then math.clamp(node.opacity, 0, 1) else 1
	local fills = node.fills or node.fill
	
	if fills then
		if type(fills) == "table" and (fills.color or fills.r or fills.type or fills.gradientStops) and not fills[1] then
			fills = { fills }
		end
		
		if type(fills) == "table" and #fills > 0 then
			for _, fill in ipairs(fills) do
				if type(fill) == "table" and fill.visible ~= false then
					local fillOpacity = if type(fill.opacity) == "number" then math.clamp(fill.opacity, 0, 1) else 1
					local fillType = string.upper(tostring(fill.type or "SOLID"))
					
					-- 1. Gradient Fill
					if fillType:find("GRADIENT") ~= nil or fill.gradientStops ~= nil then
						local effectiveAlpha = fillOpacity * nodeOpacity
						return Color3.new(1, 1, 1), math.clamp(1 - effectiveAlpha, 0, 1), fill
					end
					
					-- 2. Solid Color Fill
					if fill.color or fill.r or fillType == "SOLID" then
						local colorData = fill.color or fill
						local color3, colorTrans = StyleTranslator.ToColor3(colorData)
						local effectiveAlpha = (1 - colorTrans) * fillOpacity * nodeOpacity
						return color3, math.clamp(1 - effectiveAlpha, 0, 1), fill
					elseif fillType == "IMAGE" then
						return Color3.new(1, 1, 1), 0, fill
					end
				elseif type(fill) == "string" then
					local color3, colorTrans = StyleTranslator.ToColor3(fill)
					return color3, colorTrans, nil
				end
			end
		elseif type(fills) == "string" then
			local color3, colorTrans = StyleTranslator.ToColor3(fills)
			return color3, colorTrans, nil
		end
	end
	
	-- 3. Check direct backgroundColor
	local bg = node.backgroundColor or node.bgColor or node.background
	if bg then
		local color3, colorTrans = StyleTranslator.ToColor3(bg)
		return color3, math.clamp(1 - ((1 - colorTrans) * nodeOpacity), 0, 1), nil
	end
	
	-- 4. Check direct color property
	if node.color and type(node.color) == "table" and (node.color.r or node.color[1]) then
		local color3, colorTrans = StyleTranslator.ToColor3(node.color)
		return color3, math.clamp(1 - ((1 - colorTrans) * nodeOpacity), 0, 1), nil
	end
	
	return nil, 1, nil
end

--[[
	Applies background color, transparency, and multi-stop UIGradient to a GuiObject.
]]
function StyleTranslator.ApplyBackground(guiObject: GuiObject, node: any)
	local nodeOpacity = if type(node.opacity) == "number" then math.clamp(node.opacity, 0, 1) else 1
	local color, transparency, activeFill = StyleTranslator.GetPrimaryFill(node)
	
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
	
	-- Gradient handling
	local fills = node.fills or node.fill or (if activeFill then { activeFill } else nil)
	if fills then
		if type(fills) == "table" and not fills[1] and (fills.type or fills.gradientStops) then
			fills = { fills }
		end
		
		if type(fills) == "table" then
			for _, fill in ipairs(fills) do
				if type(fill) == "table" and fill.visible ~= false then
					local fillType = string.upper(tostring(fill.type or ""))
					local isGradient = fillType:find("GRADIENT") ~= nil or fill.gradientStops ~= nil
					
					if isGradient and fill.gradientStops and type(fill.gradientStops) == "table" then
						local colorSeq = buildColorSequence(fill.gradientStops)
						local transSeq = buildTransparencySequence(fill.gradientStops, nodeOpacity)
						
						if colorSeq then
							guiObject.BackgroundColor3 = Color3.new(1, 1, 1)
							guiObject.BackgroundTransparency = 0
							
							local gradient = Instance.new("UIGradient")
							gradient.Name = "FigmaGradient"
							gradient.Color = colorSeq
							
							if transSeq then
								gradient.Transparency = transSeq
							end
							
							-- Precise gradient rotation angle calculation
							local rotationSet = false
							if fill.gradientTransform and type(fill.gradientTransform) == "table" then
								local m = fill.gradientTransform
								if m[1] and m[2] then
									local a = tonumber(m[1][1]) or 0
									local b = tonumber(m[2][1] or m[1][2]) or 0
									local angle = math.deg(math.atan2(b, a))
									gradient.Rotation = math.round(angle)
									rotationSet = true
								end
							end
							
							if not rotationSet and fill.gradientHandlePositions and #fill.gradientHandlePositions >= 2 then
								local p0 = fill.gradientHandlePositions[1]
								local p1 = fill.gradientHandlePositions[2]
								local dx = (p1.x or 0) - (p0.x or 0)
								local dy = (p1.y or 0) - (p0.y or 0)
								local angle = math.deg(math.atan2(dy, dx))
								gradient.Rotation = math.round(angle)
								rotationSet = true
							end
							
							-- Default vertical gradient if linear gradient without explicit handles (top to bottom)
							if not rotationSet and fillType == "GRADIENT_LINEAR" then
								gradient.Rotation = 90
							end
							
							gradient.Parent = guiObject
						end
						break
					end
				end
			end
		end
	end
end

--[[
	Applies soft Drop Shadow overlay from Figma effects.
]]
function StyleTranslator.ApplyEffects(guiObject: GuiObject, node: any): ImageLabel?
	local effects = node.effects or node.effect
	if not effects or type(effects) ~= "table" then
		return nil
	end
	
	if not effects[1] and (effects.type or effects.color) then
		effects = { effects }
	end
	
	for _, effect in ipairs(effects) do
		if type(effect) == "table" and effect.visible ~= false and effect.type == "DROP_SHADOW" then
			local shadowColor, shadowTrans = StyleTranslator.ToColor3(effect.color)
			local offset = effect.offset or { x = 0, y = 4 }
			local offX = tonumber(offset.x) or 0
			local offY = tonumber(offset.y) or 4
			local radius = math.max(tonumber(effect.radius) or 8, 4)
			local spread = tonumber(effect.spread) or 0
			
			local shadow = Instance.new("ImageLabel")
			shadow.Name = "FigmaDropShadow"
			shadow.BackgroundTransparency = 1
			shadow.BorderSizePixel = 0
			shadow.Image = SHADOW_ASSET_ID
			shadow.ScaleType = Enum.ScaleType.Slice
			shadow.SliceCenter = SHADOW_SLICE_CENTER
			shadow.ImageColor3 = shadowColor
			shadow.ImageTransparency = math.clamp(shadowTrans, 0, 0.95)
			
			local extra = (radius + spread) * 2
			shadow.Size = UDim2.new(1, extra, 1, extra)
			shadow.Position = UDim2.new(0.5, offX, 0.5, offY)
			shadow.AnchorPoint = Vector2.new(0.5, 0.5)
			shadow.ZIndex = math.max(guiObject.ZIndex - 1, 1)
			shadow.Parent = guiObject
			return shadow
		end
	end
	
	return nil
end

--[[
	Applies UICorner to round edges if cornerRadius > 0.
	Supports perfect pill/stadium buttons when radius >= height / 2.
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
		
		local h = tonumber(node.height or (node.absoluteBoundingBox and node.absoluteBoundingBox.height)) or 0
		if (h > 0 and radius >= (h / 2)) or radius >= 100 then
			corner.CornerRadius = UDim.new(1, 0) -- Perfect pill / stadium end caps
		else
			corner.CornerRadius = UDim.new(0, math.round(radius))
		end
		
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
		
		if guiObject:IsA("TextLabel") or guiObject:IsA("TextBox") then
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
