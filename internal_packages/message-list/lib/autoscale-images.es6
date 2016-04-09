
function _getDimension(node, dim) {
  const raw = node.style[dim] || node[dim];
  if (!raw) {
    return [null, ''];
  }
  const valueRegexp = /(\d*)(.*)/;
  const match = valueRegexp.exec(raw);
  if (!match) {
    return [null, ''];
  }

  const value = match[1];
  const units = match[2] || 'px';
  return [value / 1, units];
}

function _runOnImageNode(node) {
  const [width, widthUnits] = _getDimension(node, 'width');
  const [height, heightUnits] = _getDimension(node, 'height');

  if (node.style.maxWidth || node.style.maxHeight) {
    return;
  }
  // VW is like %, but always basd on the iframe width, regardless of whether
  // a container is position: relative.
  // https://web-design-weekly.com/2014/11/18/viewport-units-vw-vh-vmin-vmax/
  if (width && height && (widthUnits === heightUnits)) {
    node.style.maxWidth = '100vw';
    node.style.maxHeight = `${100 * height / width}vw`;
  } else if (!height) {
    node.style.maxWidth = '100vw';
  } else {
    // If your image has a width and height in different units, or a height and
    // no width, we don't want to screw with it because it would change the
    // aspect ratio.
  }
}

export function autoscaleImages(doc) {
  // Traverse the new DOM tree and make things that look like links clickable,
  // and ensure anything with an href has a title attribute.
  const imgTagWalker = document.createTreeWalker(doc.body, NodeFilter.SHOW_ELEMENT, {
    acceptNode: (node) => {
      if (node.nodeName === 'IMG') {
        return NodeFilter.FILTER_ACCEPT;
      }
      return NodeFilter.FILTER_SKIP;
    },
  });

  while (imgTagWalker.nextNode()) {
    _runOnImageNode(imgTagWalker.currentNode);
  }
}
