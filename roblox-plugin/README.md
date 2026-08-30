# FigmaToRoblox Studio Plugin

A high-fidelity Roblox Studio plugin that converts raw Figma JSON payloads (exported via Figma REST API or custom Figma plugins) directly into native Roblox UI hierarchies.

---

## 📁 Architecture & File Structure

```
roblox-plugin/
├── INSTALL_IN_STUDIO.lua           # Self-contained single script for quick Studio installation
├── README.md                       # Plugin architecture & features
└── src/
    ├── init.server.lua             # Plugin entry point (Toolbar, Button, DockWidget, Lifecycle)
    ├── Config.lua                  # Configuration, default sizes, UI style constants
    ├── Types.lua                   # Luau type definitions for Figma schema & conversion options
    └── Modules/
        ├── ThemeManager.lua        # Dynamic Studio Light / Dark theme color adapter
        ├── PluginUI.lua            # DockWidget interface (Input, status bar, action buttons)
        ├── JsonParser.lua          # Safe JSON decoder, normalizer, and schema validator
        ├── LayoutTranslator.lua    # AutoLayout, UDim2, UIAspectRatioConstraint & UIPadding
        ├── StyleTranslator.lua     # Drop Shadows, Multi-stop UIGradients, Stadium Corners & UIStroke
        ├── TextTranslator.lua      # Font matching, sizes, alignments & text wrapping
        └── InstanceGenerator.lua   # Recursive tree traversal, UIScale controller & interactive controls generator
```

---

## 🛠️ Features & Components

### 1. Multi-Resolution Responsive Scaler (`UIScale` & `UIAspectRatioConstraint`)
- **Dynamic Device Scaling:** Automatically extracts the design canvas resolution and attaches a responsive `UIScale` controller and `LocalScript` so UI elements adapt smoothly across **Mobile phones, Tablets, PCs, and 4K displays** with zero UI clipping.
- **Aspect Ratio Protection:** Detects circular avatars, square icons, and 1:1 badges, attaching `UIAspectRatioConstraint` to prevent distortion.

### 2. Interactive Controls Engine (`InstanceGenerator.lua`)
- **`TextButton` & `ImageButton`**: Converts button layers to native, clickable Roblox buttons with `AutoButtonColor = true`.
- **`TextBox`**: Converts input fields to functional `TextBox` instances with placeholder text.

### 3. AutoLayout & Responsive Flex Engine (`LayoutTranslator.lua`)
- **`HUG` Sizing**: Maps to `AutomaticSize = Enum.AutomaticSize.XY / X / Y` so components dynamically expand with content.
- **`FILL` Container**: Maps to `UIFlexItem` with `FlexMode.Fill` and percentage scale.
- **`SPACE_BETWEEN`**: Translates Figma spacing to `UIListLayout.HorizontalFlex` / `VerticalFlex`.
- **`UIPadding`**: Applies precise top, bottom, left, and right padding.

### 4. Advanced Visuals Engine (`StyleTranslator.lua`)
- **Drop Shadows**: Generates realistic 9-slice soft drop shadow overlays (`ImageLabel`) from Figma `effects: DROP_SHADOW`.
- **Multi-Stop & Rainbow Gradients**: Converts linear gradients with multiple color keypoints, transparency sequences, and calculated rotation angles to native `UIGradient`.
- **Stadium / Pill Buttons**: Automatically applies `CornerRadius = UDim.new(1, 0)` when radius $\ge$ half height.

---

## 📝 Changelog

### `v0.0.3`
- Added Multi-Resolution Responsive Scaler with `UIScale` and client-side `ResponsiveUIScaler` controller script.
- Added `UIAspectRatioConstraint` support for 1:1 shapes, avatars, and icons.
- Added `gradientTransform` matrix rotation angle computation for linear gradients.
- Added stadium / pill button rounded corners (`UDim.new(1, 0)`).

### `v0.0.2`
- Added automatic detection and generation for interactive `TextButton`, `ImageButton`, and `TextBox` instances.
- Added AutoLayout sizing modes (`HUG`, `FILL`, `FIXED`, `AutomaticSize`, `UIFlexItem`).
- Added drop shadows via 9-slice overlays (`effects: DROP_SHADOW`).
- Added multi-stop `UIGradient` sequences with angle calculation.

### `v0.0.1`
- **Description:** Can import some simple UI but still can't import Figma details components.
- Initial foundational release.
- Added basic `Frame`, `TextLabel`, `ImageLabel`, `UICorner`, `UIStroke`, solid fills, background colors, and simple positioning.
