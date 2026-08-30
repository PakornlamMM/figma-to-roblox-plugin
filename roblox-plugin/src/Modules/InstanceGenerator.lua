--!strict
--[[
	InstanceGenerator.lua
	Recursively converts a normalized FigmaNode hierarchy into native Roblox UI instances.
	Supports:
	• Multi-Resolution Responsive Scaler (UIScale & responsive LocalScript)
	• UIAspectRatioConstraint (preserves 1:1 shapes, avatars, icons, badges)
	• Interactive Controls (TextButton, ImageButton, TextBox)
	• Button Label Auto-Centering (guarantees text inside buttons spans 100% and is centered)
	• Drop Shadows (9-slice ImageLabel overlay)
	• Multi-stop & Rainbow Gradients (UIGradient)
	• AutoLayout Engine (HUG, FILL, SpaceBetween, UIPadding)
	• UICorner (including full pill/stadium buttons) & UIStroke (Border/Contextual)
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
	AspectRatios: number,
	Scalers: number,
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
	stats: GenerationStats,
	isRoot: boolean?
): GuiObject?
	if options.ignoreInvisible and node.visible == false then
		return nil
	end
	
	local instanceType = resolveInstanceType(node)
	local guiObject: GuiObject
	
	-- 1. Instantiate matching Roblox GuiObject
	if instanceType == "BUTTON_TEXT" then
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = true
		btn.Text = "" -- Empty text so child styled TextLabels render cleanly
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
	
	-- 2. Transform (Position, Size, AnchorPoint)
	local isButtonChild = parentInstance:IsA("TextButton") or parentInstance:IsA("ImageButton")
	if isButtonChild and guiObject:IsA("TextLabel") then
		-- Child label inside a Button: guarantee 100% full span and centered alignment
		guiObject.Position = UDim2.new(0, 0, 0, 0)
		guiObject.Size = UDim2.new(1, 0, 1, 0)
		guiObject.AnchorPoint = Vector2.new(0, 0)
		guiObject.TextXAlignment = Enum.TextXAlignment.Center
		guiObject.TextYAlignment = Enum.TextYAlignment.Center
	else
		local position, size, anchorPoint = LayoutTranslator.CalculateTransform(node, parentRect, options)
		guiObject.Position = position
		guiObject.Size = size
		guiObject.AnchorPoint = anchorPoint
	end
	
	-- 3. Apply UICorner
	local corner = StyleTranslator.ApplyCorners(guiObject, node)
	if corner then stats.Corners += 1 end
	
	-- 4. Apply UIStroke
	local stroke = StyleTranslator.ApplyStrokes(guiObject, node)
	if stroke then stats.Strokes += 1 end
	
	-- 5. Apply Drop Shadows (Effects)
	local shadow = StyleTranslator.ApplyEffects(guiObject, node)
	if shadow then stats.Shadows += 1 end
	
	-- 6. Apply AutoLayout (UIListLayout, UIPadding, UIFlexItem, AutomaticSize)
	LayoutTranslator.ApplyAutoLayout(guiObject, node)
	if node.layoutMode and node.layoutMode ~= "NONE" then stats.Layouts += 1 end
	
	-- 7. Apply UIAspectRatioConstraint for icons, avatars, and 1:1 shapes (non-root)
	if not isRoot and not isButtonChild then
		local aspect = LayoutTranslator.ApplyAspectRatio(guiObject, node)
		if aspect then stats.AspectRatios += 1 end
	end
	
	-- 8. Root Scaler setup
	if isRoot then
		local uiScale = Instance.new("UIScale")
		uiScale.Name = "ResponsiveUIScale"
		uiScale.Scale = 1
		uiScale.Parent = guiObject
		stats.Scalers += 1
	end
	
	guiObject.Parent = parentInstance
	stats.TotalCreated += 1
	
	-- 9. Process Children
	local currentRect = node.absoluteBoundingBox or node.absoluteRenderBounds or node.size or node.bounds or parentRect
	local children = node.children
	if children and type(children) == "table" and #children > 0 then
		for _, childNode in ipairs(children) do
			if type(childNode) == "table" then
				buildHierarchy(childNode, guiObject, currentRect, options, stats, false)
			end
		end
	end
	
	return guiObject
end

--[[
	Generates the client-side responsive scaler controller script.
]]
local function injectResponsiveScript(screenGui: ScreenGui, refWidth: number, refHeight: number)
	screenGui:SetAttribute("ReferenceResolution", Vector2.new(refWidth, refHeight))
	screenGui:SetAttribute("DesignWidth", refWidth)
	screenGui:SetAttribute("DesignHeight", refHeight)
	
	local localScript = Instance.new("LocalScript")
	localScript.Name = "ResponsiveUIScaler"
	localScript.Source = string.format([=[--!strict
--[[
	ResponsiveUIScaler (Auto-generated by FigmaToRoblox)
	Dynamically updates UIScale based on current viewport size to preserve
	pixel-perfect design proportions across Mobile, Tablet, Desktop, and 4K displays.
]]

local camera = workspace.CurrentCamera
local screenGui = script.Parent

local function getTargetScale(): UIScale?
	local rootFrame = screenGui:FindFirstChildWhichIsA("GuiObject")
	if rootFrame then
		local scale = rootFrame:FindFirstChild("ResponsiveUIScale") or rootFrame:FindFirstChildWhichIsA("UIScale")
		if scale and scale:IsA("UIScale") then
			return scale
		end
	end
	return screenGui:FindFirstChildWhichIsA("UIScale")
end

local function updateScale()
	local uiScale = getTargetScale()
	if not uiScale then return end
	
	local refRes = screenGui:GetAttribute("ReferenceResolution") or Vector2.new(%d, %d)
	local viewport = camera.ViewportSize
	
	if viewport.X > 0 and viewport.Y > 0 and refRes.X > 0 and refRes.Y > 0 then
		local scaleX = viewport.X / refRes.X
		local scaleY = viewport.Y / refRes.Y
		-- Use minimum scale factor to guarantee zero UI clipping on any device
		local factor = math.min(scaleX, scaleY)
		uiScale.Scale = math.clamp(factor, 0.2, 3.0)
	end
end

if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

screenGui.AncestryChanged:Connect(function()
	if screenGui:IsDescendantOf(game) then
		updateScale()
	end
end)

updateScale()
]=], math.round(refWidth), math.round(refHeight))
	
	localScript.Parent = screenGui
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
		AspectRatios = 0,
		Scalers = 0,
	}
	
	local rootRect = rootNode.absoluteBoundingBox or rootNode.absoluteRenderBounds or rootNode.size or rootNode.bounds
	local refWidth = if rootRect then math.max(tonumber(rootRect.width or rootRect.w) or 1920, 100) else 1920
	local refHeight = if rootRect then math.max(tonumber(rootRect.height or rootRect.h) or 1080, 100) else 1080
	
	local rootGui = buildHierarchy(rootNode, targetParent, nil, options, stats, true)
	
	if targetParent:IsA("ScreenGui") then
		injectResponsiveScript(targetParent, refWidth, refHeight)
	elseif rootGui then
		rootGui:SetAttribute("ReferenceResolution", Vector2.new(refWidth, refHeight))
		rootGui:SetAttribute("DesignWidth", refWidth)
		rootGui:SetAttribute("DesignHeight", refHeight)
	end
	
	return rootGui, stats
end

return InstanceGenerator
