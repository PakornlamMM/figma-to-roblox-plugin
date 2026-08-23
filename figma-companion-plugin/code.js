// Figma to Roblox JSON Exporter - Plugin Code
figma.showUI(__html__, { width: 340, height: 260 });

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
          a: stop.color.a,
        },
      }));
    }
    return item;
  });
}

// Recursively traverse and extract node data
function exportNode(node) {
  const data = {
    id: node.id,
    name: node.name,
    type: node.type,
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

  if (node.clipsContent !== undefined) {
    data.clipsContent = node.clipsContent;
  }

  // Children
  if (node.children && node.children.length > 0) {
    data.children = node.children.map(child => exportNode(child));
  }

  return data;
}

// Listen for messages from UI
figma.ui.onmessage = msg => {
  if (msg.type === 'export-selected') {
    const selection = figma.currentPage.selection;
    if (selection.length === 0) {
      figma.ui.postMessage({ type: 'error', message: 'Please select a Frame, Group, or Component in Figma first!' });
      return;
    }

    const rootNode = selection[0];
    const exportedData = exportNode(rootNode);
    const jsonString = JSON.stringify(exportedData, null, 2);

    figma.ui.postMessage({
      type: 'success',
      json: jsonString,
      nodeName: rootNode.name,
      nodeCount: (exportedData.children ? exportedData.children.length : 0) + 1,
    });
  }
};
