--!strict
--[[
	JsonParser.lua
	Robust JSON decoding, schema normalization, and validation for Figma payloads.
]]

local HttpService = game:GetService("HttpService")

local Types = require(script.Parent.Parent:WaitForChild("Types"))

type FigmaNode = Types.FigmaNode
type ParseResult = Types.ParseResult

local JsonParser = {}

-- Recursively count total nodes in hierarchy
local function countNodes(node: FigmaNode): number
	local count = 1
	if node.children and type(node.children) == "table" then
		for _, child in ipairs(node.children) do
			if type(child) == "table" then
				count += countNodes(child)
			end
		end
	end
	return count
end

-- Normalizes node properties so standard field access is safe
local function normalizeNode(rawNode: any): FigmaNode?
	if type(rawNode) ~= "table" then
		return nil
	end
	
	local node: FigmaNode = {
		id = tostring(rawNode.id or rawNode.name or HttpService:GenerateGUID(false)),
		name = tostring(rawNode.name or rawNode.id or "FigmaElement"),
		type = string.upper(tostring(rawNode.type or "FRAME")),
		visible = if rawNode.visible ~= nil then rawNode.visible else true,
		opacity = if type(rawNode.opacity) == "number" then rawNode.opacity else 1,
		absoluteBoundingBox = rawNode.absoluteBoundingBox,
		absoluteRenderBounds = rawNode.absoluteRenderBounds,
		size = rawNode.size,
		fills = rawNode.fills,
		strokes = rawNode.strokes,
		strokeWeight = rawNode.strokeWeight,
		strokeAlign = rawNode.strokeAlign,
		cornerRadius = rawNode.cornerRadius,
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
		layoutWrap = rawNode.layoutWrap,
		
		characters = rawNode.characters,
		style = rawNode.style,
		constraints = rawNode.constraints,
		children = nil,
	}
	
	-- Support alternate bounding box formats (e.g. width/height at root level or size vector)
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
	
	-- Recursively process children
	if rawNode.children and type(rawNode.children) == "table" then
		local normalizedChildren: { FigmaNode } = {}
		for _, childRaw in ipairs(rawNode.children) do
			local childNode = normalizeNode(childRaw)
			if childNode then
				table.insert(normalizedChildren, childNode)
			end
		end
		node.children = normalizedChildren
	end
	
	return node
end

-- Drill down into DOCUMENT or CANVAS to find the primary UI frame
local function extractRootFromPayload(decoded: any): (FigmaNode?, string?)
	if type(decoded) ~= "table" then
		return nil, "JSON content must be an object or array."
	end
	
	-- Scenario 1: Array of nodes -> extract first or wrap
	if #decoded > 0 then
		local first = decoded[1]
		if type(first) == "table" then
			return normalizeNode(first), "ARRAY"
		end
		return nil, "JSON array contains invalid items."
	end
	
	-- Scenario 2: Figma REST API nodes endpoint -> { "nodes": { "1:2": { "document": { ... } } } }
	if decoded.nodes and type(decoded.nodes) == "table" then
		for _, nodeContainer in pairs(decoded.nodes) do
			if type(nodeContainer) == "table" then
				local target = nodeContainer.document or nodeContainer
				return normalizeNode(target), "FIGMA_NODES_API"
			end
		end
	end
	
	-- Scenario 3: Figma REST API full file -> { "document": { "children": [ { "type": "CANVAS", "children": [ ... ] } ] } }
	local candidate = decoded.document or decoded.data or decoded.root or decoded
	
	if candidate.type == "DOCUMENT" then
		if candidate.children and #candidate.children > 0 then
			local canvas = candidate.children[1]
			if canvas.children and #canvas.children > 0 then
				return normalizeNode(canvas.children[1]), "FIGMA_DOCUMENT_API"
			end
		end
	elseif candidate.type == "CANVAS" then
		if candidate.children and #candidate.children > 0 then
			return normalizeNode(candidate.children[1]), "FIGMA_CANVAS"
		end
	end
	
	-- Scenario 4: Direct Figma Node (Frame / Component / Group / etc.)
	local directNode = normalizeNode(candidate)
	if directNode and directNode.type then
		return directNode, directNode.type
	end
	
	return nil, "Could not identify a valid Figma root node in JSON payload."
end

--[[
	Parses a raw JSON string and extracts a normalized FigmaNode root tree.
]]
function JsonParser.Parse(rawJson: string): ParseResult
	local trimmed = string.match(rawJson, "^%s*(.-)%s*$") or ""
	
	if trimmed == "" then
		return {
			success = false,
			rootNode = nil,
			errorMessage = "Please paste Figma JSON data into the text box.",
			nodeCount = 0,
		}
	end
	
	-- Decode JSON safely
	local decodeSuccess, decoded = pcall(function()
		return HttpService:JSONDecode(trimmed)
	end)
	
	if not decodeSuccess or decoded == nil then
		return {
			success = false,
			rootNode = nil,
			errorMessage = string.format("Invalid JSON syntax: %s", tostring(decoded or "Unknown parse error")),
			nodeCount = 0,
		}
	end
	
	-- Extract and normalize root
	local rootNode, rawType = extractRootFromPayload(decoded)
	if not rootNode then
		return {
			success = false,
			rootNode = nil,
			errorMessage = rawType or "Failed to extract Figma UI components from JSON.",
			nodeCount = 0,
		}
	end
	
	local totalCount = countNodes(rootNode)
	
	return {
		success = true,
		rootNode = rootNode,
		errorMessage = nil,
		nodeCount = totalCount,
		rawType = rawType,
	}
end

-- Returns a sample Figma JSON template for quick testing
function JsonParser.GetSampleJson(): string
	local sample = {
		id = "10:100",
		name = "SampleCard",
		type = "FRAME",
		absoluteBoundingBox = { x = 100, y = 100, width = 360, height = 240 },
		fills = {
			{
				type = "SOLID",
				visible = true,
				opacity = 1,
				color = { r = 0.12, g = 0.14, b = 0.18, a = 1 },
			},
		},
		cornerRadius = 12,
		strokes = {
			{
				type = "SOLID",
				visible = true,
				opacity = 1,
				color = { r = 0.25, g = 0.3, b = 0.4, a = 1 },
			},
		},
		strokeWeight = 1.5,
		clipsContent = true,
		children = {
			{
				id = "10:101",
				name = "CardHeader",
				type = "TEXT",
				absoluteBoundingBox = { x = 120, y = 120, width = 320, height = 28 },
				characters = "Figma To Roblox UI",
				style = {
					fontFamily = "BuilderSans",
					fontWeight = 700,
					fontSize = 20,
					textAlignHorizontal = "LEFT",
					textAlignVertical = "CENTER",
				},
				fills = {
					{
						type = "SOLID",
						visible = true,
						color = { r = 1, g = 1, b = 1, a = 1 },
					},
				},
			},
			{
				id = "10:102",
				name = "CardDescription",
				type = "TEXT",
				absoluteBoundingBox = { x = 120, y = 154, width = 320, height = 40 },
				characters = "Automated conversion with high-fidelity styles, responsive scaling, and clean Luau mapping.",
				style = {
					fontFamily = "BuilderSans",
					fontWeight = 400,
					fontSize = 12,
					textAlignHorizontal = "LEFT",
					textAlignVertical = "TOP",
				},
				fills = {
					{
						type = "SOLID",
						visible = true,
						color = { r = 0.7, g = 0.75, b = 0.85, a = 1 },
					},
				},
			},
			{
				id = "10:103",
				name = "ActionButton",
				type = "FRAME",
				absoluteBoundingBox = { x = 120, y = 210, width = 140, height = 36 },
				cornerRadius = 6,
				fills = {
					{
						type = "SOLID",
						visible = true,
						color = { r = 0.0, g = 0.63, b = 1.0, a = 1 },
					},
				},
				children = {
					{
						id = "10:104",
						name = "ButtonLabel",
						type = "TEXT",
						absoluteBoundingBox = { x = 120, y = 210, width = 140, height = 36 },
						characters = "Explore",
						style = {
							fontFamily = "BuilderSans",
							fontWeight = 600,
							fontSize = 13,
							textAlignHorizontal = "CENTER",
							textAlignVertical = "CENTER",
						},
						fills = {
							{
								type = "SOLID",
								visible = true,
								color = { r = 1, g = 1, b = 1, a = 1 },
							},
						},
					},
				},
			},
		},
	}
	
	return HttpService:JSONEncode(sample)
end

return JsonParser
