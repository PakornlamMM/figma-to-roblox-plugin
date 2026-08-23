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
        ├── LayoutTranslator.lua    # UDim2 positioning, responsive scale & AutoLayout
        ├── StyleTranslator.lua     # Colors, backgroundColor, UICorner & UIStroke
        ├── TextTranslator.lua      # Font matching, sizes, alignments & text wrapping
        └── InstanceGenerator.lua   # Recursive tree traversal & instance generator
```

---

## 🛠️ Features & Components

### 1. Plugin Lifecycle & DockWidget (`init.server.lua`)
- Creates a dedicated Toolbar item and Action Button under Studio's **Plugins** tab.
- Initializes a `DockWidgetPluginGui` with saved state and docking support.
- Implements `ChangeHistoryService` recording (`TryBeginRecording` / `FinishRecording`) so generated UI hierarchies are fully undoable/redoable in Studio.
- Auto-selects the generated `ScreenGui` in `StarterGui` via `Selection:Set()`.

### 2. Studio Theme Engine (`ThemeManager.lua`)
- Integrates with `settings().Studio.Theme` to retrieve native Studio style guide colors.
- Automatically listens to `settings().Studio.ThemeChanged` to adapt all UI elements on-the-fly when switching between Dark and Light mode.

### 3. Multi-Line JSON Input Interface (`PluginUI.lua`)
- Modern, clean layout with rounded corners (`UICorner`) and outline strokes (`UIStroke`).
- Action row with **Load Sample** (loads valid test JSON) and **Clear** buttons.
- Multi-line, scrollable `TextBox` with clear placeholder directions.
- Live Status / Feedback Bar with colored indicators for parsing, validating, and errors.
- Prominent **⚡ Generate UI in StarterGui** button with hover micro-interactions.

---

## 📝 Changelog

### `v0.0.1`
- **Description:** Can import some simple UI but still can't import Figma details components.
- Initial foundational release.
- Added basic `Frame`, `TextLabel`, `ImageLabel`, `UICorner`, `UIStroke`, solid fills, background colors, and simple positioning.
