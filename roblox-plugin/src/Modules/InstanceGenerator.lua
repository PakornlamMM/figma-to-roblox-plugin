--!strict
--[[
	InstanceGenerator.lua
	Recursively converts a normalized FigmaNode hierarchy into native Roblox UI instances.
	Supports Interactive Controls (TextButton, ImageButton, TextBox), Vectors (ImageLabel),
	Drop Shadows (ImageLabel 9-slice), Multi-stop Gradients (UIGradient),
	and Frames with AutoLayout (HUG/FILL), UICorner, and UIStroke.
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
	Buttons: number,
	TextBoxes: number,
	Corners: number,
	Strokes: number,
	Shadows: number,
	Layouts: number,
}

local InstanceGenerator = {}

--[[
	Detects if a node has image fills or vector graphic types.
]]
local function isImageOrVector(node: any): boolean
	local t = string.upper(tostring(node.type or node.nodeType or node.kind or node.tag or ""))
	if t == "VECTOR" or t == "ELLIPSE" or t == "STAR" or t == "POLYGON" or t == "LINE" or t == "IMAGE" or node.isVector == true then
		return true
	end
	
	local fills = node.fills or node.fill
	if fills and type(fills) == "table" then
		if fills.type and string.upper(tostring(fills.type)) == "IMAGE" then
			return true
		end
		for _, fill in ipairs(fills) do
			if type(fill) == "table" and string.upper(tostring(fill.type or "")) == "IMAGE" then
				return true
			end
		end
	end
	
	return false
end

--[[
	Intelligently categorizes node into UI instance types:
	"BUTTON_TEXT" | "BUTTON_IMAGE" | "TEXT_BOX" | "TEXT_LABEL" | "IMAGE_LABEL" | "FRAME"
]]
local function resolveInstanceType(node: any): string
	local name = string.lower(tostring(node.name or ""))
	local t = string.upper(tostring(node.type or node.nodeType or node.kind or node.tag or ""))
	local role = string.upper(tostring(node.role or ""))
	
	-- 1. Check if node is an Interactive Button
	local isBtn = node.isButton == true or role == "BUTTON"
		or name:match("^btn") or name:match("button$") or name:match("_btn") or name:match("%-btn")
		or name:match("cta") or name:match("actionbutton") or name:match("submit") or name:match("closebtn")
	
	if isBtn then
		if isImageOrVector(node) and not (node.characters ~= nil or node.text ~= nil) then
			return "BUTTON_IMAGE"
		else
			return "BUTTON_TEXT"
		end
	end
	
	-- 2. Check if node is an Interactive Input Field (TextBox)
	local isInput = node.isInput == true or role == "INPUT"
		or name:match("input") or name:match("textbox") or name:match("textfield")
		or name:match("searchbar") or name:match("search") or name:match("field")
	
	if isInput and t ~= "TEXT" then
		return "TEXT_BOX"
	end
	
	-- 3. Check if node is Text
	if t == "TEXT" or (node.characters ~= nil and tostring(node.characters) ~= "") or (node.text ~= nil and tostring(node.text) ~= "") then
		return "TEXT_LABEL"
	end
	
	-- 4. Check if node is Vector / Shape / Image
	if isImageOrVector(node) then
		return "IMAGE_LABEL"
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
	
	local instanceType = resolveInstanceType(node)
	local guiObject: GuiObject
	
	-- 1. Instantiate the matching Roblox GuiObject
	if instanceType == "BUTTON_TEXT" then
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = true
		btn.Text = "" -- Keep text empty so inner styled TextLabels or icons render with full fidelity
		btn.ClipsDescendants = node.clipsContent or false
		StyleTranslator.ApplyBackground(btn, node)
		guiObject = btn
		stats.Buttons += 1
	elseif instanceType == "BUTTON_IMAGE" then
		local btn = Instance.new("ImageButton")
		btn.AutoButtonColor = true
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.ScaleType = Enum.ScaleType.Fit
		StyleTranslator.ApplyBackground(btn, node)
		guiObject = btn
		stats.Buttons += 1
	elseif instanceType == "TEXT_BOX" then
		local textBox = Instance.new("TextBox")
		textBox.ClearTextOnFocus = false
		textBox.ClipsDescendants = false
		textBox.AutoLocalize = false
		
		-- Setup placeholder text if applicable
		local rawText = tostring(node.characters or node.text or node.placeholder or "")
		if rawText ~= "" and (rawText:lower():match("^enter") or rawText:lower():match("^search") or rawText:lower():match("^type") or rawText:lower():match("^your")) then
			textBox.PlaceholderText = rawText
			textBox.Text = ""
		else
			textBox.Text = rawText
			textBox.PlaceholderText = "Type here..."
		end
		
		textBox.PlaceholderColor3 = Color3.fromRGB(160, 160, 160)
		TextTranslator.ApplyText(textBox :: any, node)
		StyleTranslator.ApplyBackground(textBox, node)
		guiObject = textBox
		stats.TextBoxes += 1
	elseif instanceType == "TEXT_LABEL" then
		local textLabel = Instance.new("TextLabel")
		TextTranslator.ApplyText(textLabel, node)
		guiObject = textLabel
		stats.TextLabels += 1
	elseif instanceType == "IMAGE_LABEL" then
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
	
	-- 5. Apply Drop Shadows (Effects)
	local shadow = StyleTranslator.ApplyEffects(guiObject, node)
	if shadow then
		stats.Shadows += 1
	end
	
	-- 6. Apply AutoLayout (UIListLayout, UIPadding, UIFlexItem, AutomaticSize)
	LayoutTranslator.ApplyAutoLayout(guiObject, node)
	if node.layoutMode and node.layoutMode ~= "NONE" then
		stats.Layouts += 1
	end
	
	-- Parent to container
	guiObject.Parent = parentInstance
	stats.TotalCreated += 1
	
	-- 7. Recursively process children
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
		Buttons = 0,
		TextBoxes = 0,
		Corners = 0,
		Strokes = 0,
		Shadows = 0,
		Layouts = 0,
	}
	
	local rootGui = buildHierarchy(rootNode, targetParent, nil, options, stats)
	
	return rootGui, stats
end

return InstanceGenerator
