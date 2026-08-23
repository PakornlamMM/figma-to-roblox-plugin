--!strict
--[[
	LayoutTranslator.lua
	Handles coordinate mapping, responsive UDim2 calculation, AnchorPoints, and Figma AutoLayout translation.
]]

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type FigmaNode = Types.FigmaNode
type FigmaRect = Types.FigmaRect
type ConversionOptions = Types.ConversionOptions

local LayoutTranslator = {}

--[[
	Calculates UDim2 Position, Size, and Vector2 AnchorPoint for a node.
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
	-- Center directly on screen with exact pixel dimensions
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
		-- Global canvas coordinates: rawX >= parentX and within reasonable proximity
		if rawX >= parentX and (rawX - parentX) < (parentWidth * 2) then
			relX = rawX - parentX
			relY = (rawY or 0) - parentY
		else
			-- Already local relative offset
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
		-- Responsive percentage of parent
		position = UDim2.new(relX / parentWidth, 0, relY / parentHeight, 0)
		size = UDim2.new(width / parentWidth, 0, height / parentHeight, 0)
	elseif mode == "ExactOffset" then
		-- Exact pixel dimensions
		position = UDim2.new(0, math.round(relX), 0, math.round(relY))
		size = UDim2.new(0, math.round(width), 0, math.round(height))
	else
		-- Hybrid: Position uses scale, size uses exact offset
		position = UDim2.new(relX / parentWidth, 0, relY / parentHeight, 0)
		size = UDim2.new(0, math.round(width), 0, math.round(height))
	end
	
	return position, size, Vector2.new(0, 0)
end

--[[
	Applies AutoLayout (UIListLayout or UIGridLayout) and UIPadding to a GuiObject.
]]
function LayoutTranslator.ApplyAutoLayout(guiObject: GuiObject, node: any)
	local layoutMode = node.layoutMode
	if not layoutMode or layoutMode == "NONE" then
		return
	end
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Name = "FigmaListLayout"
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	if layoutMode == "HORIZONTAL" then
		listLayout.FillDirection = Enum.FillDirection.Horizontal
	else
		listLayout.FillDirection = Enum.FillDirection.Vertical
	end
	
	local spacing = node.itemSpacing or 0
	listLayout.Padding = UDim.new(0, math.round(spacing))
	
	local primaryAlign = node.primaryAxisAlignItems or "MIN"
	local counterAlign = node.counterAxisAlignItems or "MIN"
	
	if layoutMode == "HORIZONTAL" then
		if primaryAlign == "CENTER" then
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		elseif primaryAlign == "MAX" then
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
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
