--!strict
--[[
	Types.lua
	Type definitions for Figma JSON schema and conversion pipeline.
]]

export type FigmaColor = {
	r: number,
	g: number,
	b: number,
	a: number?,
}

export type FigmaRect = {
	x: number,
	y: number,
	width: number,
	height: number,
}

export type FigmaPaint = {
	type: string, -- "SOLID", "IMAGE", "GRADIENT_LINEAR", etc.
	visible: boolean?,
	opacity: number?,
	color: FigmaColor?,
	blendMode: string?,
}

export type FigmaLayoutConstraint = {
	vertical: string?, -- "TOP", "BOTTOM", "CENTER", "TOP_BOTTOM", "SCALE"
	horizontal: string?, -- "LEFT", "RIGHT", "CENTER", "LEFT_RIGHT", "SCALE"
}

export type FigmaTypeStyle = {
	fontFamily: string?,
	fontPostScriptName: string?,
	fontWeight: number?,
	fontSize: number?,
	textAlignHorizontal: string?, -- "LEFT", "CENTER", "RIGHT", "JUSTIFIED"
	textAlignVertical: string?, -- "TOP", "CENTER", "BOTTOM"
	letterSpacing: number?,
	lineHeightPx: number?,
	lineHeightPercent: number?,
	italic: boolean?,
}

export type FigmaStroke = {
	type: string,
	color: FigmaColor?,
	opacity: number?,
}

export type FigmaNode = {
	id: string,
	name: string,
	type: string, -- "FRAME", "GROUP", "COMPONENT", "INSTANCE", "TEXT", "RECTANGLE", "VECTOR", etc.
	visible: boolean?,
	opacity: number?,
	absoluteBoundingBox: FigmaRect?,
	absoluteRenderBounds: FigmaRect?,
	size: { x: number, y: number }?,
	fills: { FigmaPaint }?,
	strokes: { FigmaPaint }?,
	strokeWeight: number?,
	strokeAlign: string?, -- "INSIDE", "OUTSIDE", "CENTER"
	cornerRadius: number?,
	rectangleCornerRadii: { number }?, -- [top-left, top-right, bottom-right, bottom-left]
	clipsContent: boolean?,
	
	-- AutoLayout properties
	layoutMode: string?, -- "NONE", "HORIZONTAL", "VERTICAL"
	primaryAxisAlignItems: string?, -- "MIN", "CENTER", "MAX", "SPACE_BETWEEN"
	counterAxisAlignItems: string?, -- "MIN", "CENTER", "MAX", "BASELINE"
	itemSpacing: number?,
	paddingLeft: number?,
	paddingRight: number?,
	paddingTop: number?,
	paddingBottom: number?,
	layoutWrap: string?, -- "NO_WRAP", "WRAP"
	
	-- Text properties
	characters: string?,
	style: FigmaTypeStyle?,
	
	-- Constraints
	constraints: FigmaLayoutConstraint?,
	
	-- Hierarchy
	children: { FigmaNode }?,
	
	-- Custom metadata
	[string]: any,
}

export type ConversionOptions = {
	sizingMode: "ResponsiveScale" | "ExactOffset" | "Hybrid",
	targetContainer: "StarterGui" | "Selection" | "Workspace",
	ignoreInvisible: boolean,
	createScreenGui: boolean,
	screenGuiName: string?,
}

export type ParseResult = {
	success: boolean,
	rootNode: FigmaNode?,
	errorMessage: string?,
	nodeCount: number,
	rawType: string?,
}

return {}
