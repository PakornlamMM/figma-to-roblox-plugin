# Figma to Roblox Plugin Suite

A complete bidirectional workflow to export UI designs from **Figma** and generate pixel-perfect, native UI hierarchies in **Roblox Studio**.

---

## 📁 Repository Structure

```
figma-to-roblox-plugin/
├── figma-companion-plugin/         # Figma Desktop Plugin (1-Click JSON Exporter)
│   ├── manifest.json               # Figma plugin manifest
│   ├── code.js                     # Extraction logic (Colors, Frames, AutoLayout, Text, Strokes)
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
            ├── LayoutTranslator.lua# UDim2 positioning, responsive scale & AutoLayout
            ├── StyleTranslator.lua # Colors, backgroundColor, UICorner & UIStroke
            ├── TextTranslator.lua  # Font matching, sizes, alignments & text wrapping
            └── InstanceGenerator.lua# Recursive tree traversal & instance generator
```

---

## 🚀 Quick Start Guide

### Step 1: Export from Figma
1. In the **Figma Desktop App**, open your design file.
2. Go to **Plugins** $\rightarrow$ **Development** $\rightarrow$ **Import plugin from manifest...**.
3. Select `figma-companion-plugin/manifest.json`.
4. Select your UI frame (e.g. `Frame 1`) and click **"📋 Copy JSON for Roblox"**.

### Step 2: Import into Roblox Studio
1. Open your place in **Roblox Studio**.
2. In Explorer, create a Script, paste the contents of `roblox-plugin/INSTALL_IN_STUDIO.lua`, and right-click $\rightarrow$ **"Save as Local Plugin..."**.
3. Click the **"Figma to Roblox"** button in your Plugins toolbar.
4. Paste (`Ctrl + V`) into the text box and click **"⚡ Generate UI in StarterGui"**.
5. Your UI will generate centered in `StarterGui` with full `Ctrl + Z` undo support!

---

## 📝 Changelog

### `v0.0.1`
- **Description:** Can import some simple UI but still can't import Figma details components.
- Initial foundational release of the Figma to Roblox conversion suite.
- Included Figma Companion Exporter plugin (`figma-companion-plugin`).
- Included Roblox Studio DockWidget generator plugin with native Studio Theme support and `ChangeHistoryService` undo/redo (`roblox-plugin`).
- Support for basic `Frame`, `TextLabel`, `ImageLabel`, `UICorner`, `UIStroke`, solid fills, background colors, and simple positioning.