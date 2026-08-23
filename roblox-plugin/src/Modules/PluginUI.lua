--!strict
--[[
	PluginUI.lua
	Constructs and manages the DockWidgetPluginGui interface with full Studio theme support.
]]

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local ThemeManager = require(script.Parent:WaitForChild("ThemeManager"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))

type ThemeColors = ThemeManager.ThemeColors
type ConversionOptions = Types.ConversionOptions

local PluginUI = {}
PluginUI.__index = PluginUI

export type UIHandle = {
	Widget: DockWidgetPluginGui,
	GetJsonText: () -> string,
	SetJsonText: (text: string) -> (),
	SetStatus: (message: string, statusType: "idle" | "success" | "warning" | "error" | "working") -> (),
	GetOptions: () -> ConversionOptions,
	OnGenerateClicked: (callback: () -> ()) -> RBXScriptConnection,
	OnSampleClicked: (callback: () -> ()) -> RBXScriptConnection,
	OnClearClicked: (callback: () -> ()) -> RBXScriptConnection,
	Destroy: () -> (),
}

function PluginUI.Create(widget: DockWidgetPluginGui): UIHandle
	-- Clear any pre-existing elements
	for _, child in ipairs(widget:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local colors = ThemeManager.GetColors()

	-- Root Container
	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "RootFrame"
	rootFrame.Size = UDim2.new(1, 0, 1, 0)
	rootFrame.BackgroundColor3 = colors.MainBackground
	rootFrame.BorderSizePixel = 0
	rootFrame.Parent = widget

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

	-- =========================================================================
	-- 1. Header Section
	-- =========================================================================
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderFrame"
	headerFrame.Size = UDim2.new(1, 0, 0, 42)
	headerFrame.BackgroundTransparency = 1
	headerFrame.LayoutOrder = 1
	headerFrame.Parent = rootFrame

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 10)
	headerLayout.Parent = headerFrame

	-- Header Icon Badge
	local iconBadge = Instance.new("Frame")
	iconBadge.Name = "IconBadge"
	iconBadge.Size = UDim2.new(0, 36, 0, 36)
	iconBadge.BackgroundColor3 = colors.Accent
	iconBadge.BorderSizePixel = 0
	iconBadge.Parent = headerFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = Config.UI.CornerRadius
	iconCorner.Parent = iconBadge

	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.Size = UDim2.new(0, 22, 0, 22)
	iconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = Config.ButtonIcon
	iconImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
	iconImage.Parent = iconBadge

	-- Title & Subtitle Container
	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.new(1, -50, 1, 0)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = headerFrame

	local titleList = Instance.new("UIListLayout")
	titleList.FillDirection = Enum.FillDirection.Vertical
	titleList.VerticalAlignment = Enum.VerticalAlignment.Center
	titleList.Padding = UDim.new(0, 2)
	titleList.Parent = titleContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 18)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Config.UI.FontBold
	titleLabel.TextSize = Config.UI.TextSizeHeader
	titleLabel.TextColor3 = colors.MainText
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Figma To Roblox"
	titleLabel.Parent = titleContainer

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubLabel"
	subLabel.Size = UDim2.new(1, 0, 0, 14)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Config.UI.Font
	subLabel.TextSize = Config.UI.TextSizeSmall
	subLabel.TextColor3 = colors.SubText
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Text = "Paste Figma API JSON to generate native UI"
	subLabel.Parent = titleContainer

	-- =========================================================================
	-- 2. Toolbar / Actions Row
	-- =========================================================================
	local actionRow = Instance.new("Frame")
	actionRow.Name = "ActionRow"
	actionRow.Size = UDim2.new(1, 0, 0, 26)
	actionRow.BackgroundTransparency = 1
	actionRow.LayoutOrder = 2
	actionRow.Parent = rootFrame

	local actionRowLayout = Instance.new("UIListLayout")
	actionRowLayout.FillDirection = Enum.FillDirection.Horizontal
	actionRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	actionRowLayout.Padding = UDim.new(0, 8)
	actionRowLayout.Parent = actionRow

	-- Sample Button
	local sampleButton = Instance.new("TextButton")
	sampleButton.Name = "SampleButton"
	sampleButton.Size = UDim2.new(0, 90, 1, 0)
	sampleButton.BackgroundColor3 = colors.ButtonBackground
	sampleButton.BorderSizePixel = 0
	sampleButton.Font = Config.UI.Font
	sampleButton.TextSize = Config.UI.TextSizeSmall
	sampleButton.TextColor3 = colors.MainText
	sampleButton.Text = "Load Sample"
	sampleButton.AutoButtonColor = true
	sampleButton.Parent = actionRow

	local sampleCorner = Instance.new("UICorner")
	sampleCorner.CornerRadius = Config.UI.SmallCornerRadius
	sampleCorner.Parent = sampleButton

	local sampleStroke = Instance.new("UIStroke")
	sampleStroke.Color = colors.Border
	sampleStroke.Thickness = 1
	sampleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sampleStroke.Parent = sampleButton

	-- Clear Button
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.Size = UDim2.new(0, 60, 1, 0)
	clearButton.BackgroundColor3 = colors.ButtonBackground
	clearButton.BorderSizePixel = 0
	clearButton.Font = Config.UI.Font
	clearButton.TextSize = Config.UI.TextSizeSmall
	clearButton.TextColor3 = colors.MainText
	clearButton.Text = "Clear"
	clearButton.AutoButtonColor = true
	clearButton.Parent = actionRow

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = Config.UI.SmallCornerRadius
	clearCorner.Parent = clearButton

	local clearStroke = Instance.new("UIStroke")
	clearStroke.Color = colors.Border
	clearStroke.Thickness = 1
	clearStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	clearStroke.Parent = clearButton

	-- =========================================================================
	-- 3. JSON Input Box (Multi-Line Scrollable)
	-- =========================================================================
	local inputContainer = Instance.new("Frame")
	inputContainer.Name = "InputContainer"
	inputContainer.Size = UDim2.new(1, 0, 1, -170) -- Flexes based on widget height
	inputContainer.BackgroundColor3 = colors.InputFieldBackground
	inputContainer.BorderSizePixel = 0
	inputContainer.LayoutOrder = 3
	inputContainer.ClipsDescendants = true
	inputContainer.Parent = rootFrame

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = Config.UI.CornerRadius
	inputCorner.Parent = inputContainer

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Name = "BorderStroke"
	inputStroke.Color = colors.Border
	inputStroke.Thickness = 1
	inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inputStroke.Parent = inputContainer

	local scrollContainer = Instance.new("ScrollingFrame")
	scrollContainer.Name = "ScrollContainer"
	scrollContainer.Size = UDim2.new(1, 0, 1, 0)
	scrollContainer.BackgroundTransparency = 1
	scrollContainer.BorderSizePixel = 0
	scrollContainer.ScrollBarThickness = 6
	scrollContainer.ScrollBarImageColor3 = colors.DimmedText
	scrollContainer.CanvasSize = UDim2.new(1, 0, 0, 0)
	scrollContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollContainer.Parent = inputContainer

	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, 8)
	scrollPadding.PaddingBottom = UDim.new(0, 8)
	scrollPadding.PaddingLeft = UDim.new(0, 10)
	scrollPadding.PaddingRight = UDim.new(0, 10)
	scrollPadding.Parent = scrollContainer

	local jsonTextBox = Instance.new("TextBox")
	jsonTextBox.Name = "JsonTextBox"
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
	jsonTextBox.PlaceholderText = "-- Paste Figma JSON string here --\n\nSupports:\n• Figma REST API responses\n• Custom Figma plugin node exports\n• Array or single node payloads"
	jsonTextBox.TextXAlignment = Enum.TextXAlignment.Left
	jsonTextBox.TextYAlignment = Enum.TextYAlignment.Top
	jsonTextBox.Text = ""
	jsonTextBox.Parent = scrollContainer

	-- =========================================================================
	-- 4. Status Bar
	-- =========================================================================
	local statusFrame = Instance.new("Frame")
	statusFrame.Name = "StatusFrame"
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
	statusDot.Name = "StatusDot"
	statusDot.Size = UDim2.new(0, 8, 0, 8)
	statusDot.BackgroundColor3 = colors.DimmedText
	statusDot.BorderSizePixel = 0
	statusDot.Parent = statusFrame

	local statusDotCorner = Instance.new("UICorner")
	statusDotCorner.CornerRadius = UDim.new(1, 0)
	statusDotCorner.Parent = statusDot

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -20, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Config.UI.Font
	statusLabel.TextSize = Config.UI.TextSizeSmall
	statusLabel.TextColor3 = colors.SubText
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Text = "Ready. Paste JSON above and click Generate."
	statusLabel.Parent = statusFrame

	-- =========================================================================
	-- 5. Generate UI Button
	-- =========================================================================
	local generateButton = Instance.new("TextButton")
	generateButton.Name = "GenerateButton"
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

	-- Hover animation effect
	generateButton.MouseEnter:Connect(function()
		generateButton.BackgroundColor3 = colors.AccentHover
	end)
	generateButton.MouseLeave:Connect(function()
		generateButton.BackgroundColor3 = colors.Accent
	end)

	-- =========================================================================
	-- Dynamic Studio Theme Updating
	-- =========================================================================
	local themeConnection = ThemeManager.OnThemeChanged(function(newColors: ThemeColors)
		colors = newColors
		rootFrame.BackgroundColor3 = newColors.MainBackground
		iconBadge.BackgroundColor3 = newColors.Accent
		titleLabel.TextColor3 = newColors.MainText
		subLabel.TextColor3 = newColors.SubText
		
		sampleButton.BackgroundColor3 = newColors.ButtonBackground
		sampleButton.TextColor3 = newColors.MainText
		sampleStroke.Color = newColors.Border
		
		clearButton.BackgroundColor3 = newColors.ButtonBackground
		clearButton.TextColor3 = newColors.MainText
		clearStroke.Color = newColors.Border
		
		inputContainer.BackgroundColor3 = newColors.InputFieldBackground
		inputStroke.Color = newColors.Border
		scrollContainer.ScrollBarImageColor3 = newColors.DimmedText
		jsonTextBox.TextColor3 = newColors.MainText
		jsonTextBox.PlaceholderColor3 = newColors.DimmedText
		
		statusFrame.BackgroundColor3 = newColors.SecondaryBackground
		statusLabel.TextColor3 = newColors.SubText
		generateButton.BackgroundColor3 = newColors.Accent
	end)

	-- =========================================================================
	-- UI Handle API
	-- =========================================================================
	local uiHandle: UIHandle = {
		Widget = widget,
		GetJsonText = function(): string
			return jsonTextBox.Text
		end,
		SetJsonText = function(text: string)
			jsonTextBox.Text = text
		end,
		SetStatus = function(message: string, statusType: "idle" | "success" | "warning" | "error" | "working")
			statusLabel.Text = message
			if statusType == "success" then
				statusDot.BackgroundColor3 = colors.Success
				statusLabel.TextColor3 = colors.Success
			elseif statusType == "error" then
				statusDot.BackgroundColor3 = colors.Error
				statusLabel.TextColor3 = colors.Error
			elseif statusType == "warning" then
				statusDot.BackgroundColor3 = colors.Warning
				statusLabel.TextColor3 = colors.Warning
			elseif statusType == "working" then
				statusDot.BackgroundColor3 = colors.Accent
				statusLabel.TextColor3 = colors.MainText
			else
				statusDot.BackgroundColor3 = colors.DimmedText
				statusLabel.TextColor3 = colors.SubText
			end
		end,
		GetOptions = function(): ConversionOptions
			return {
				sizingMode = Config.Defaults.SizingMode,
				targetContainer = Config.Defaults.TargetContainer,
				ignoreInvisible = Config.Defaults.IgnoreInvisible,
				createScreenGui = Config.Defaults.CreateScreenGui,
			}
		end,
		OnGenerateClicked = function(callback: () -> ()): RBXScriptConnection
			return generateButton.MouseButton1Click:Connect(callback)
		end,
		OnSampleClicked = function(callback: () -> ()): RBXScriptConnection
			return sampleButton.MouseButton1Click:Connect(callback)
		end,
		OnClearClicked = function(callback: () -> ()): RBXScriptConnection
			return clearButton.MouseButton1Click:Connect(callback)
		end,
		Destroy = function()
			if themeConnection then
				themeConnection:Disconnect()
			end
			rootFrame:Destroy()
		end,
	}

	return uiHandle
end

return PluginUI
