// Figma to Roblox JSON Exporter - Plugin Code v0.0.2
// Supports AutoLayout (HUG/FILL), Drop Shadows, Multi-Stop Gradients, Interactive Controls, and Vectors.
figma.showUI(__html__, { width: 360, height: 290 });

// Helper to convert paint array to serializable JSON
function serializePaints(paints) {
  if (!paints || !Array.isArray(paints)) return [];
  return paints.map(paint => {
    const item = {
      type: paint.type,
      visible: paint.visible !== false,
      opacity: typeof paint.opacity === 'number' ? paint.opacity : 1,
    };
    if (paint.color) {
      item.color = {
        r: paint.color.r,
        g: paint.color.g,
        b: paint.color.b,
        a: typeof paint.opacity === 'number' ? paint.opacity : 1,
      };
    }
    if (paint.gradientStops) {
      item.gradientStops = paint.gradientStops.map(stop => ({
        position: stop.position,
        color: {
          r: stop.color.r,
          g: stop.color.g,
          b: stop.color.b,
          a: typeof stop.color.a === 'number' ? stop.color.a : 1,
        },
      }));
    }
    if (paint.gradientTransform) {
      item.gradientTransform = paint.gradientTransform;
    }
    if (paint.gradientHandlePositions) {
      item.gradientHandlePositions = paint.gradientHandlePositions;
    }
    return item;
  });
}

// Helper to serialize effects (Drop Shadow, Inner Shadow, Blur)
function serializeEffects(effects) {
  if (!effects || !Array.isArray(effects)) return [];
  return effects.map(effect => {
    const item = {
      type: effect.type, // "DROP_SHADOW", "INNER_SHADOW", "LAYER_BLUR", "BACKGROUND_BLUR"
      visible: effect.visible !== false,
      radius: effect.radius || 0,
    };
    if (effect.color) {
      item.color = {
        r: effect.color.r,
        g: effect.color.g,
        b: effect.color.b,
        a: typeof effect.color.a === 'number' ? effect.color.a : 1,
      };
    }
    if (effect.offset) {
      item.offset = {
        x: effect.offset.x || 0,
        y: effect.offset.y || 0,
      };
    }
    if (effect.spread !== undefined) {
      item.spread = effect.spread;
    }
    return item;
  });
}

// Detect component semantic role from naming and structure
function detectRole(node) {
  const name = node.name.toLowerCase();
  
  if (name.match(/\b(button|btn|cta|primarybtn|secondarybtn|actionbutton|textbutton|imagebutton)\b/i) || name.includes('btn') || name.includes('button')) {
    return 'BUTTON';
  }
  if (name.match(/\b(input|textbox|textfield|search|searchbar|textinput|field|entry)\b/i) || name.includes('input') || name.includes('textfield')) {
    return 'INPUT';
  }
  if (name.match(/\b(icon|badge|avatar|symbol|logo|vector|graphic|illustration)\b/i)) {
    return 'ICON';
  }
  if (name.match(/\b(card|panel|modal|dialog|window|container|popup|frame)\b/i)) {
    return 'CARD';
  }
  return 'GENERIC';
}

// Recursively traverse and extract node data
async function exportNode(node) {
  const role = detectRole(node);
  const isVector = node.type === 'VECTOR' || node.type === 'BOOLEAN_OPERATION' || node.type === 'STAR' || node.type === 'POLYGON' || node.type === 'LINE' || node.type === 'ELLIPSE';
  
  const data = {
    id: node.id,
    name: node.name,
    type: node.type,
    role: role,
    isVector: isVector,
    isButton: role === 'BUTTON',
    isInput: role === 'INPUT',
    visible: node.visible !== false,
    opacity: typeof node.opacity === 'number' ? node.opacity : 1,
    x: node.x,
    y: node.y,
    width: node.width,
    height: node.height,
    absoluteBoundingBox: {
      x: node.absoluteTransform ? node.absoluteTransform[0][2] : node.x,
      y: node.absoluteTransform ? node.absoluteTransform[1][2] : node.y,
      width: node.width,
      height: node.height,
    },
  };

  // Background / Fills
  if (node.fills) {
    data.fills = serializePaints(node.fills);
  }
  if (node.backgroundColor) {
    data.backgroundColor = {
      r: node.backgroundColor.r,
      g: node.backgroundColor.g,
      b: node.backgroundColor.b,
      a: typeof node.backgroundColor.a === 'number' ? node.backgroundColor.a : 1,
    };
  }

  // Strokes / Borders
  if (node.strokes) {
    data.strokes = serializePaints(node.strokes);
    data.strokeWeight = node.strokeWeight || 0;
    data.strokeAlign = node.strokeAlign || 'INSIDE';
  }

  // Effects (Drop Shadows & Blurs)
  if (node.effects && node.effects.length > 0) {
    data.effects = serializeEffects(node.effects);
  }

  // Corner Radii
  if (typeof node.cornerRadius === 'number') {
    data.cornerRadius = node.cornerRadius;
  } else if (node.topLeftRadius !== undefined) {
    data.rectangleCornerRadii = [
      node.topLeftRadius || 0,
      node.topRightRadius || 0,
      node.bottomRightRadius || 0,
      node.bottomLeftRadius || 0,
    ];
  }

  // AutoLayout
  if (node.layoutMode && node.layoutMode !== 'NONE') {
    data.layoutMode = node.layoutMode; // "HORIZONTAL" or "VERTICAL"
    data.primaryAxisAlignItems = node.primaryAxisAlignItems || 'MIN';
    data.counterAxisAlignItems = node.counterAxisAlignItems || 'MIN';
    data.itemSpacing = node.itemSpacing || 0;
    data.paddingLeft = node.paddingLeft || 0;
    data.paddingRight = node.paddingRight || 0;
    data.paddingTop = node.paddingTop || 0;
    data.paddingBottom = node.paddingBottom || 0;
    data.layoutWrap = node.layoutWrap || 'NO_WRAP';
  }

  // Sizing mode (HUG / FIXED / FILL)
  if (node.layoutSizingHorizontal) {
    data.layoutSizingHorizontal = node.layoutSizingHorizontal; // "FIXED", "HUG", "FILL"
  }
  if (node.layoutSizingVertical) {
    data.layoutSizingVertical = node.layoutSizingVertical;
  }

  // Text Properties
  if (node.type === 'TEXT') {
    data.characters = node.characters;
    const fontName = typeof node.fontName === 'object' ? node.fontName : { family: 'Inter', style: 'Regular' };
    data.style = {
      fontFamily: fontName.family,
      fontWeight: fontName.style.includes('Bold') ? 700 : (fontName.style.includes('Medium') ? 500 : 400),
      fontSize: typeof node.fontSize === 'number' ? node.fontSize : 14,
      textAlignHorizontal: node.textAlignHorizontal || 'LEFT',
      textAlignVertical: node.textAlignVertical || 'CENTER',
      italic: fontName.style.includes('Italic'),
    };
  }

  // Export SVG content if it's a vector shape or icon
  if (isVector && typeof node.exportAsync === 'function') {
    try {
      const svgBytes = await node.exportAsync({ format: 'SVG_STRING' });
      if (svgBytes) {
        data.svg = svgBytes;
      }
    } catch (e) {
      // Fallback
    }
  }

  if (node.clipsContent !== undefined) {
    data.clipsContent = node.clipsContent;
  }

  // Children
  if (node.children && node.children.length > 0) {
    data.children = [];
    for (const child of node.children) {
      const childData = await exportNode(child);
      data.children.push(childData);
    }
  }

  return data;
}

// Listen for messages from UI
figma.ui.onmessage = async msg => {
  if (msg.type === 'export-selected') {
    const selection = figma.currentPage.selection;
    if (selection.length === 0) {
      figma.ui.postMessage({ type: 'error', message: 'Please select a Frame, Group, or Component in Figma first!' });
      return;
    }

    const rootNode = selection[0];
    const exportedData = await exportNode(rootNode);
    const jsonString = JSON.stringify(exportedData, null, 2);

    figma.ui.postMessage({
      type: 'success',
      json: jsonString,
      nodeName: rootNode.name,
      nodeCount: (exportedData.children ? exportedData.children.length : 0) + 1,
    });
  }
};
