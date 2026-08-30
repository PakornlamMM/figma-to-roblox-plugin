--!strict
--[[
	LayoutTranslator.lua
	Handles coordinate mapping, responsive UDim2 calculation, AnchorPoints,
	AutoLayout (HUG, FILL, FIXED, SpaceBetween, UIPadding), and UIAspectRatioConstraint.
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type FigmaNode = Types.FigmaNode
type FigmaRect = Types.FigmaRect
type ConversionOptions = Types.ConversionOptions

local LayoutTranslator = {}

--[[
	Calculates UDim2 Position, Size, and Vector2 AnchorPoint for a node.
	Respects AutoLayout sizing modes: HUG, FILL, and FIXED.
]]
function LayoutTranslator.CalculateTransform(
	node: any,
	parentRect: any?,
	options: any
): (UDim2, UDim2, Vector2)
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
	
	-- 1. ROOT NODE (No parent frame)
	-- Center directly on screen with exact reference pixel dimensions
	if not parentRect then
		return UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, math.round(width), 0, math.round(height)), Vector2.new(0.5, 0.5)
	end
	
	-- 2. CHILD NODE
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
	
	local sizingH = string.upper(tostring(node.layoutSizingHorizontal or "FIXED"))
	local sizingV = string.upper(tostring(node.layoutSizingVertical or "FIXED"))
	
	local mode = if type(options) == "table" and options.sizingMode then options.sizingMode else "ResponsiveScale"
	local position: UDim2
	local size: UDim2
	
	-- Sizing calculation
	local sizeScaleX = if sizingH == "FILL" then 1 else (width / parentWidth)
	local sizeOffsetX = if sizingH == "HUG" then 0 elseif sizingH == "FILL" then 0 else math.round(width)
	
	local sizeScaleY = if sizingV == "FILL" then 1 else (height / parentHeight)
	local sizeOffsetY = if sizingV == "HUG" then 0 elseif sizingV == "FILL" then 0 else math.round(height)
	
	if mode == "ResponsiveScale" or mode == "ResponsiveAuto" then
		position = UDim2.new(relX / parentWidth, 0, relY / parentHeight, 0)
		size = if (sizingH == "HUG" or sizingV == "HUG")
			then UDim2.new(if sizingH == "HUG" then 0 else sizeScaleX, if sizingH == "HUG" then 0 else 0, if sizingV == "HUG" then 0 else sizeScaleY, if sizingV == "HUG" then 0 else 0)
			else UDim2.new(sizeScaleX, 0, sizeScaleY, 0)
	elseif mode == "ExactOffset" then
		position = UDim2.new(0, math.round(relX), 0, math.round(relY))
		size = UDim2.new(if sizingH == "FILL" then 1 else 0, sizeOffsetX, if sizingV == "FILL" then 1 else 0, sizeOffsetY)
	else
		position = UDim2.new(relX / parentWidth, 0, relY / parentHeight, 0)
		size = UDim2.new(if sizingH == "FILL" then 1 else 0, sizeOffsetX, if sizingV == "FILL" then 1 else 0, sizeOffsetY)
	end
	
	return position, size, Vector2.new(0, 0)
end

--[[
	Applies UIAspectRatioConstraint to prevent distortion of 1:1 shapes, avatars, icons, and badges.
]]
function LayoutTranslator.ApplyAspectRatio(guiObject: GuiObject, node: any): UIAspectRatioConstraint?
	local nodeRect = node.absoluteBoundingBox or node.absoluteRenderBounds or node.size or node.bounds
	if not nodeRect then return nil end
	
	local width = tonumber(nodeRect.width or nodeRect.w) or 0
	local height = tonumber(nodeRect.height or nodeRect.h) or 0
	if width <= 0 or height <= 0 then return nil end
	
	local t = string.upper(tostring(node.type or node.nodeType or ""))
	local role = string.upper(tostring(node.role or ""))
	local is1to1 = math.abs(width - height) < 1.5
	local isIconOrAvatar = (role == "ICON" or role == "AVATAR" or t == "ELLIPSE" or t == "STAR" or node.isVector == true)
	
	if is1to1 or isIconOrAvatar or node.preserveAspectRatio == true then
		local constraint = Instance.new("UIAspectRatioConstraint")
		constraint.Name = "FigmaAspectRatio"
		constraint.AspectRatio = math.round((width / height) * 1000) / 1000
		constraint.AspectType = Enum.AspectType.FitWithinMaxSize
		constraint.DominantAxis = Enum.DominantAxis.Width
		constraint.Parent = guiObject
		return constraint
	end
	
	return nil
end

--[[
	Applies AutoLayout (UIListLayout, UIPadding, UIFlexItem, AutomaticSize) to a GuiObject.
	Only applies UIListLayout to container frames with children.
]]
function LayoutTranslator.ApplyAutoLayout(guiObject: GuiObject, node: any)
	local sizingH = string.upper(tostring(node.layoutSizingHorizontal or ""))
	local sizingV = string.upper(tostring(node.layoutSizingVertical or ""))
	
	-- Apply AutomaticSize if HUG is configured
	if sizingH == "HUG" and sizingV == "HUG" then
		guiObject.AutomaticSize = Enum.AutomaticSize.XY
	elseif sizingH == "HUG" then
		guiObject.AutomaticSize = Enum.AutomaticSize.X
	elseif sizingV == "HUG" then
		guiObject.AutomaticSize = Enum.AutomaticSize.Y
	end
	
	-- Apply UIFlexItem if FILL is configured
	if sizingH == "FILL" or sizingV == "FILL" then
		pcall(function()
			local flexItem = Instance.new("UIFlexItem")
			flexItem.Name = "FigmaFlexItem"
			flexItem.FlexMode = (Enum :: any).UIFlexMode.Fill
			flexItem.Parent = guiObject
		end)
	end
	
	local layoutMode = node.layoutMode
	if not layoutMode or layoutMode == "NONE" then
		return
	end
	
	-- Only attach UIListLayout if the node has children
	if node.children and type(node.children) == "table" and #node.children > 0 then
		local listLayout = Instance.new("UIListLayout")
		listLayout.Name = "FigmaListLayout"
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		
		local isHorizontal = (layoutMode == "HORIZONTAL")
		listLayout.FillDirection = if isHorizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
		
		local spacing = node.itemSpacing or 0
		listLayout.Padding = UDim.new(0, math.round(spacing))
		
		local primaryAlign = string.upper(tostring(node.primaryAxisAlignItems or "MIN"))
		local counterAlign = string.upper(tostring(node.counterAxisAlignItems or "MIN"))
		
		-- Alignments
		if isHorizontal then
			if primaryAlign == "CENTER" then
				listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			elseif primaryAlign == "MAX" then
				listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			elseif primaryAlign == "SPACE_BETWEEN" then
				pcall(function()
					(listLayout :: any).HorizontalFlex = (Enum :: any).UIFlexAlignment.SpaceBetween
				end)
			else
				listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			end
			
			if counterAlign == "CENTER" then
				listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			elseif counterAlign == "MAX" then
				listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
			else
				listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			end
		else
			if primaryAlign == "CENTER" then
				listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			elseif primaryAlign == "MAX" then
				listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
			elseif primaryAlign == "SPACE_BETWEEN" then
				pcall(function()
					(listLayout :: any).VerticalFlex = (Enum :: any).UIFlexAlignment.SpaceBetween
				end)
			else
				listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			end
			
			if counterAlign == "CENTER" then
				listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			elseif counterAlign == "MAX" then
				listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			else
				listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			end
		end
		
		listLayout.Parent = guiObject
	end
	
	-- UIPadding
	local padLeft = node.paddingLeft or 0
	local padRight = node.paddingRight or 0
	local padTop = node.paddingTop or 0
	local padBottom = node.paddingBottom or 0
	
	if padLeft > 0 or padRight > 0 or padTop > 0 or padBottom > 0 then
		local uiPadding = Instance.new("UIPadding")
		uiPadding.Name = "FigmaPadding"
		uiPadding.PaddingLeft = UDim.new(0, math.round(padLeft))
		uiPadding.PaddingRight = UDim.new(0, math.round(padRight))
		uiPadding.PaddingTop = UDim.new(0, math.round(padTop))
		uiPadding.PaddingBottom = UDim.new(0, math.round(padBottom))
		uiPadding.Parent = guiObject
	end
end

return LayoutTranslator
