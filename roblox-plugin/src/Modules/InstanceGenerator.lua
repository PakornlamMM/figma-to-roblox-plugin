--!strict
--[[
	InstanceGenerator.lua
	Recursively converts a normalized FigmaNode hierarchy into native Roblox UI instances.
	Intelligently detects TextLabels, ImageLabels, Frames, applies proper AnchorPoints and styles.
]]

local LayoutTranslator = require(script.Parent:WaitForChild("LayoutTranslator"))
local StyleTranslator = require(script.Parent:WaitForChild("StyleTranslator"))
local TextTranslator = require(script.Parent:WaitForChild("TextTranslator"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))

type FigmaNode = Types.FigmaNode
type FigmaRect = Types.FigmaRect
type ConversionOptions = Types.ConversionOptions

export type GenerationStats = {
	TotalCreated: number,
	Frames: number,
	TextLabels: number,
	ImageLabels: number,
	Corners: number,
	Strokes: number,
	Layouts: number,
}

local InstanceGenerator = {}

--[[
	Intelligently categorizes node into "TEXT", "IMAGE", or "FRAME".
]]
local function resolveNodeType(node: any): string
	local t = string.upper(tostring(node.type or node.nodeType or node.kind or node.tag or ""))
	
	-- 1. Check if node is Text
	if t == "TEXT" or (node.characters ~= nil and tostring(node.characters) ~= "") or (node.text ~= nil and tostring(node.text) ~= "") then
		return "TEXT"
	end
	
	-- 2. Check if node is Vector / Shape / Image
	if t == "VECTOR" or t == "ELLIPSE" or t == "STAR" or t == "POLYGON" or t == "LINE" or t == "IMAGE" then
		return "IMAGE"
	end
	
	-- 3. Check for image fills
	local fills = node.fills or node.fill
	if fills and type(fills) == "table" then
		if fills.type and string.upper(tostring(fills.type)) == "IMAGE" then
			return "IMAGE"
		end
		for _, fill in ipairs(fills) do
			if type(fill) == "table" and string.upper(tostring(fill.type or "")) == "IMAGE" then
				return "IMAGE"
			end
		end
	end
	
	return "FRAME"
end

--[[
	Recursively builds the Roblox UI hierarchy from the Figma node tree.
]]
local function buildHierarchy(
	node: any,
	parentInstance: Instance,
	parentRect: any?,
	options: ConversionOptions,
	stats: GenerationStats
): GuiObject?
	if options.ignoreInvisible and node.visible == false then
		return nil
	end
	
	local resolvedType = resolveNodeType(node)
	local guiObject: GuiObject
	
	-- 1. Create Instance based on resolved node type
	if resolvedType == "TEXT" then
		local textLabel = Instance.new("TextLabel")
		TextTranslator.ApplyText(textLabel, node)
		guiObject = textLabel
		stats.TextLabels += 1
	elseif resolvedType == "IMAGE" then
		local imageLabel = Instance.new("ImageLabel")
		imageLabel.BackgroundTransparency = 1
		imageLabel.BorderSizePixel = 0
		imageLabel.ScaleType = Enum.ScaleType.Fit
		StyleTranslator.ApplyBackground(imageLabel, node)
		guiObject = imageLabel
		stats.ImageLabels += 1
	else
		local frame = Instance.new("Frame")
		StyleTranslator.ApplyBackground(frame, node)
		guiObject = frame
		stats.Frames += 1
	end
	
	guiObject.Name = tostring(node.name or node.id or "FigmaElement")
	
	-- 2. Calculate and apply Transform (Position, Size, AnchorPoint)
	local position, size, anchorPoint = LayoutTranslator.CalculateTransform(node, parentRect, options)
	guiObject.Position = position
	guiObject.Size = size
	guiObject.AnchorPoint = anchorPoint
	
	-- 3. Apply UICorner
	local corner = StyleTranslator.ApplyCorners(guiObject, node)
	if corner then
		stats.Corners += 1
	end
	
	-- 4. Apply UIStroke
	local stroke = StyleTranslator.ApplyStrokes(guiObject, node)
	if stroke then
		stats.Strokes += 1
	end
	
	-- 5. Apply AutoLayout (UIListLayout and UIPadding)
	LayoutTranslator.ApplyAutoLayout(guiObject, node)
	if node.layoutMode and node.layoutMode ~= "NONE" then
		stats.Layouts += 1
	end
	
	-- Parent to container
	guiObject.Parent = parentInstance
	stats.TotalCreated += 1
	
	-- 6. Recursively process children
	local currentRect = node.absoluteBoundingBox or node.absoluteRenderBounds or node.size or node.bounds or parentRect
	
	local children = node.children
	if children and type(children) == "table" and #children > 0 then
		for _, childNode in ipairs(children) do
			if type(childNode) == "table" then
				buildHierarchy(childNode, guiObject, currentRect, options, stats)
			end
		end
	end
	
	return guiObject
end

--[[
	Entry point to generate a complete Figma hierarchy inside a target ScreenGui.
]]
function InstanceGenerator.Generate(
	rootNode: any,
	targetParent: Instance,
	options: ConversionOptions
): (GuiObject?, GenerationStats)
	local stats: GenerationStats = {
		TotalCreated = 0,
		Frames = 0,
		TextLabels = 0,
		ImageLabels = 0,
		Corners = 0,
		Strokes = 0,
		Layouts = 0,
	}
	
	local rootGui = buildHierarchy(rootNode, targetParent, nil, options, stats)
	
	return rootGui, stats
end

return InstanceGenerator
