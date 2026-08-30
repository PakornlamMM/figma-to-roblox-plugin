# Figma to Roblox Plugin Suite

# This plugin aren't perfect yet. There's still some bugs to fix.
## Don't expect perfect UI translation from this plugin

A complete bidirectional workflow to export UI designs from **Figma** and generate pixel-perfect, native UI hierarchies in **Roblox Studio**.

---

## 📁 Repository Structure

```
figma-to-roblox-plugin/
├── figma-companion-plugin/         # Figma Desktop Plugin (1-Click JSON Exporter)
│   ├── manifest.json               # Figma plugin manifest
│   ├── code.js                     # Extraction logic (AutoLayout, Effects, Gradients, Roles, Vectors)
│   ├── ui.html                     # Clean UI with 'Copy JSON for Roblox' button
│   └── README.md                   # Installation & usage instructions
│
└── roblox-plugin/                  # Roblox Studio Plugin (UI Hierarchy Generator)
    ├── INSTALL_IN_STUDIO.lua       # Single bundled script for 1-click Studio installation
    ├── README.md                   # Plugin architecture & features
    └── src/
        ├── init.server.lua         # Plugin entry (Toolbar, DockWidget, ChangeHistoryService)
        ├── Config.lua              # Settings, dimensions, and typography tokens
        ├── Types.lua               # Strict Luau types
        └── Modules/
            ├── ThemeManager.lua    # Studio Light/Dark theme adaptation
            ├── PluginUI.lua        # DockWidget interface & status bar
            ├── JsonParser.lua      # Multi-format JSON decoder & schema normalizer
            ├── LayoutTranslator.lua# AutoLayout (HUG/FILL/SpaceBetween), UDim2, UIAspectRatioConstraint & UIPadding
            ├── StyleTranslator.lua # Drop Shadows, Multi-stop UIGradients, Stadium Corners & UIStroke
            ├── TextTranslator.lua  # Font matching, sizes, alignments & text wrapping
            └── InstanceGenerator.lua# Recursive tree traversal, UIScale controller & interactive controls generator
```

---

## 🚀 Quick Start Guide

### Step 1: Export from Figma
1. In the **Figma Desktop App**, open your design file.
2. Go to **Plugins** $\rightarrow$ **Development** $\rightarrow$ **Import plugin from manifest...**.
3. Select `figma-companion-plugin/manifest.json`.
4. Select your UI frame (e.g. `HeaderBar`, `Card`, or `TextButton`) and click **"📋 Copy JSON for Roblox"**.

### Step 2: Import into Roblox Studio
1. Open your place in **Roblox Studio**.
2. In Explorer, create a Script, paste the contents of `roblox-plugin/INSTALL_IN_STUDIO.lua`, and right-click $\rightarrow$ **"Save as Local Plugin..."**.
3. Click the **"Figma to Roblox"** button in your Plugins toolbar.
4. Paste (`Ctrl + V`) into the text box and click **"⚡ Generate UI in StarterGui"**.
5. Your UI will generate centered in `StarterGui` with responsive scaling and full `Ctrl + Z` undo support!

---

## 📝 Changelog

### `v0.0.3`
- **Multi-Resolution Responsive Scaler Engine:**
  - Automatically calculates the canvas reference resolution (`DesignWidth` / `DesignHeight`) from the root Figma frame.
  - Attaches a responsive `UIScale` object to the root GUI frame.
  - Automatically generates a standalone client-side `ResponsiveUIScaler` controller `LocalScript` inside `ScreenGui` that adapts smoothly across **Mobile phones, Tablets, PCs, and 4K displays** with zero UI cut-off or distortion.
- **Aspect Ratio Protection (`UIAspectRatioConstraint`):**
  - Automatically detects 1:1 shapes (square buttons, badges, circular avatars, icons) and attaches `UIAspectRatioConstraint` to prevent unwanted stretching across different screen ratios.
- **Gradient Matrix & Visual Refinements:**
  - Gradient angle rotation derived from Figma `gradientTransform` affine matrix and `gradientHandlePositions`.
  - Added support for smooth stadium/pill buttons (`CornerRadius = UDim.new(1, 0)`).
  - Ensured `Contextual` text stroke outline rendering on all `TextLabel` and `TextBox` elements.

### `v0.0.2`
- **Interactive Controls Support:**
  - Automatically identifies and converts button layers (`Button`, `Btn`, `CTA`, `ActionButton`) to native, clickable Roblox `TextButton` and `ImageButton` instances with `AutoButtonColor = true`.
  - Automatically detects text inputs (`Input`, `TextBox`, `TextField`, `Search`) and converts them to functional Roblox `TextBox` instances with placeholder text and left alignment.
- **AutoLayout & Responsive Flex Engine:**
  - `HUG` contents mapped to Roblox `AutomaticSize = Enum.AutomaticSize.XY / X / Y`.
  - `FILL` container mapped to `UIFlexItem` (`FlexMode.Fill`) and responsive percentage sizing.
  - `SPACE_BETWEEN` alignments mapped to `UIListLayout.HorizontalFlex` / `VerticalFlex`.
  - Accurate `UIPadding` and gap spacing translation.
- **Advanced Visual Effects:**
  - Drop Shadows: translates Figma `effects: DROP_SHADOW` into soft 9-slice drop shadow overlays.
  - Multi-Stop Gradients: translates linear gradients with multi-color keypoints, transparency sequences, and calculated rotation angles to `UIGradient`.
- **Vector & Asset Metadata:**
  - Enhanced Figma companion exporter to detect vector graphics, SVG icons, and component roles (`BUTTON`, `INPUT`, `ICON`, `CARD`).

### `v0.0.1`
- **Description:** Can import some simple UI but still can't import Figma details components.
- Initial foundational release of the Figma to Roblox conversion suite.
- Included Figma Companion Exporter plugin (`figma-companion-plugin`).
- Included Roblox Studio DockWidget generator plugin with native Studio Theme support and `ChangeHistoryService` undo/redo (`roblox-plugin`).
- Support for basic `Frame`, `TextLabel`, `ImageLabel`, `UICorner`, `UIStroke`, solid fills, background colors, and simple positioning.