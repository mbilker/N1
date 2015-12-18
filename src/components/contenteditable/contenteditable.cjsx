_ = require 'underscore'
React = require 'react'

{Utils, DOMUtils} = require 'nylas-exports'
{KeyCommandsRegion} = require 'nylas-component-kit'
ClipboardService = require './clipboard-service'
FloatingToolbarContainer = require './floating-toolbar-container'

ListManager = require './list-manager'

###
Public: A modern, well-behaved, React-compatible contenteditable

This <Contenteditable /> component is fully React-compatible and behaves
like a standard controlled input.

```javascript
getInitialState: function() {
  return {value: '<strong>Hello!</strong>'};
},
handleChange: function(event) {
  this.setState({value: event.target.value});
},
render: function() {
  var value = this.state.value;
  return <Contenteditable type="text" value={value} onChange={this.handleChange} />;
}
```
###
class Contenteditable extends React.Component
  @displayName: "Contenteditable"

  @propTypes:

    # The current html state, as a string, of the contenteditable.
    value: React.PropTypes.string

    # Initial content selection that was previously saved
    initialSelectionSnapshot: React.PropTypes.object,

    # Handlers
    onChange: React.PropTypes.func.isRequired
    onFilePaste: React.PropTypes.func

    # A list of objects that extend {ContenteditableExtension}
    extensions: React.PropTypes.array

    spellcheck: React.PropTypes.bool

    floatingToolbar: React.PropTypes.bool

  @defaultProps:
    extensions: []
    spellcheck: true
    floatingToolbar: true

  coreExtensions: [ListManager]

  # We allow extensions to read, and mutate the:
  #
  # 1. DOM of the contenteditable
  # 2. The Selection
  # 3. The innerState of the component
  # 4. The context menu (onShowContextMenu)
  #
  # We treat mutations as a single atomic change (even if multiple actual
  # mutations happened).
  atomicEdit: (editingFunction, extraArgs...) =>
    @_teardownListeners()
    args = [@_editableNode(), document.getSelection(), extraArgs...]
    editingFunction.apply(null, args)
    @_setupListeners()
    @_onDOMMutated()

  constructor: (@props) ->
    @innerState = {}
    @_setupServices(@props)

  _setupServices: (props) ->
    @clipboardService = new ClipboardService
      onFilePaste: props.onFilePaste

  setInnerState: (innerState={}) ->
    @innerState = _.extend @innerState, innerState
    @refs["toolbarController"]?.componentWillReceiveInnerProps(innerState)

  componentDidMount: =>
    @_mutationObserver = new MutationObserver(@_onDOMMutated)
    @_setupListeners()
    @_setupGlobalMouseListener()
    @_cleanHTML()
    @setInnerState editableNode: @_editableNode()

  # When we have a composition event in progress, we should not update
  # because otherwise our composition event will be blown away.
  shouldComponentUpdate: (nextProps, nextState) ->
    not @_inCompositionEvent and
    (not Utils.isEqualReact(nextProps, @props) or
     not Utils.isEqualReact(nextState, @state))

  componentWillUnmount: =>
    @_teardownListeners()
    @_teardownGlobalMouseListener()

  componentWillReceiveProps: (nextProps) =>
    @_setupServices(nextProps)
    if nextProps.initialSelectionSnapshot?
      @_setSelectionSnapshot(nextProps.initialSelectionSnapshot)

  componentDidUpdate: =>
    @_cleanHTML()
    @_restoreSelection()

    editableNode = @_editableNode()

    # On a given update the actual DOM node might be a different object on
    # the heap. We need to refresh the mutation listeners.
    @_teardownListeners()
    @_setupListeners()

    @setInnerState
      links: editableNode.querySelectorAll("*[href]")
      editableNode: editableNode

  _renderFloatingToolbar: ->
    return unless @props.floatingToolbar
    <FloatingToolbarContainer
        ref="toolbarController"
        atomicEdit={@atomicEdit}
        onSaveUrl={@_onSaveUrl} />

  render: =>
    <KeyCommandsRegion className="contenteditable-container"
                       localHandlers={@_keymapHandlers()}>
      {@_renderFloatingToolbar()}

      <div className="contenteditable"
           ref="contenteditable"
           contentEditable
           spellCheck={false}
           dangerouslySetInnerHTML={__html: @props.value}
           {...@_eventHandlers()}></div>
    </KeyCommandsRegion>

  _keymapHandlers: ->
    atomicEditWrap = (command) => (event) =>
      @atomicEdit((-> document.execCommand(command)), event)

    keymapHandlers = {
      'contenteditable:bold': atomicEditWrap("bold")
      'contenteditable:italic': atomicEditWrap("italic")
      'contenteditable:indent': atomicEditWrap("indent")
      'contenteditable:outdent': atomicEditWrap("outdent")
      'contenteditable:underline': atomicEditWrap("underline")
      'contenteditable:numbered-list': atomicEditWrap("insertOrderedList")
      'contenteditable:bulleted-list': atomicEditWrap("insertUnorderedList")
    }

    return keymapHandlers

  _eventHandlers: =>
    onBlur: @_onBlur
    onFocus: @_onFocus
    onClick: @_onClick
    onPaste: @clipboardService.onPaste
    onKeyDown: @_onKeyDown
    onCompositionEnd: @_onCompositionEnd
    onCompositionStart: @_onCompositionStart

  focus: =>
    @_editableNode().focus()

  selectEnd: =>
    range = document.createRange()
    range.selectNodeContents(@_editableNode())
    range.collapse(false)
    @_editableNode().focus()
    selection = window.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)

  _onClick: (event) ->
    # We handle mouseDown, mouseMove, mouseUp, but we want to stop propagation
    # of `click` to make it clear that we've handled the event.
    # Note: Related to composer-view#_onClickComposeBody
    event.stopPropagation()

  # We must set the `inCompositionEvent` flag in addition to tearing down
  # the selecton listeners. While the composition event is in progress, we
  # want to ignore any input events we get.
  #
  # It is also possible for a composition event to end and then
  # immediately start a new composition event. This happens when two
  # composition event-triggering characters are pressed twice in a row.
  # When the first composition event ends, the `_onDOMMutated` method fires (as
  # it's supposed to) and sends off an asynchronous update request when we
  # `_saveNewHtml`. Before that comes back via new props, the 2nd
  # composition event starts. Without the `_inCompositionEvent` flag
  # stopping the re-render, the asynchronous update request will cause us
  # to re-render and blow away our newly started 2nd composition event.
  _onCompositionStart: =>
    @_inCompositionEvent = true
    @_teardownListeners()

  _onCompositionEnd: =>
    @_inCompositionEvent = false
    @_setupListeners()
    @_onDOMMutated()

  _runCallbackOnExtensions: (method, args...) =>
    for extension in @props.extensions.concat(@coreExtensions)
      @_runExtensionMethod(extension, method, args...)

  # Will execute the event handlers on each of the registerd and core
  # extensions In this context, event.preventDefault and
  # event.stopPropagation don't refer to stopping default DOM behavior or
  # prevent event bubbling through the DOM, but rather prevent our own
  # Contenteditable default behavior, and preventing other extensions from
  # being called. If any of the extensions calls event.preventDefault()
  # it will prevent the default behavior for the Contenteditable, which
  # basically means preventing the core extension handlers from being
  # called.  If any of the extensions calls event.stopPropagation(), it
  # will prevent any other extension handlers from being called.
  _runEventCallbackOnExtensions: (method, event, args...) =>
    for extension in @props.extensions
      break if event?.isPropagationStopped()
      @_runExtensionMethod(extension, method, event, args...)

    return if event?.defaultPrevented or event?.isPropagationStopped()
    for extension in @coreExtensions
      break if event?.isPropagationStopped()
      @_runExtensionMethod(extension, method, event, args...)

  _runExtensionMethod: (extension, method, args...) =>
    return if not extension[method]?
    editingFunction = extension[method].bind(extension)
    @atomicEdit(editingFunction, args...)

  _onKeyDown: (event) =>
    @_runEventCallbackOnExtensions("onKeyDown", event)

    # This is a special case where we don't want to bubble up the event to the
    # keymap manager if the extension prevented the default behavior
    if event.defaultPrevented
      event.stopPropagation()
      return

    if event.key is "Tab"
      @_onTabDownDefaultBehavior(event)
      return

  # Every time the contents of the contenteditable DOM node change, the
  # `_onDOMMutated` event gets fired.
  #
  # If we are in the middle of an `atomic` change transaction, we ignore
  # those changes.
  #
  # At all other times we take the change, apply various filters to the
  # new content, then notify our parent that the content has been updated.
  _onDOMMutated: (mutations) =>
    return if @_ignoreInputChanges
    return unless mutations and mutations.length > 0
    @_ignoreInputChanges = true
    @_resetInnerStateOnInput()

    @_runCallbackOnExtensions("onContentChanged", mutations)

    @_normalize()

    @_saveSelectionState()

    @_notifyParentOfChange()

    @_ignoreInputChanges = false
    return

  _resetInnerStateOnInput: ->
    @_autoCreatedListFromText = false
    @setInnerState dragging: false if @innerState.dragging
    @setInnerState doubleDown: false if @innerState.doubleDown

  _notifyParentOfChange: ->
    @props.onChange(target: {value: @_editableNode().innerHTML})

  _onTabDownDefaultBehavior: (event) ->
    selection = document.getSelection()
    if selection?.isCollapsed
      if event.shiftKey
        if DOMUtils.isAtTabChar(selection)
          @_removeLastCharacter(selection)
        else if DOMUtils.isAtBeginningOfDocument(@_editableNode(), selection)
          return # Don't stop propagation
      else
        document.execCommand("insertText", false, "\t")
    else
      if event.shiftKey
        document.execCommand("insertText", false, "")
      else
        document.execCommand("insertText", false, "\t")
    event.preventDefault()
    event.stopPropagation()

  _removeLastCharacter: (selection) ->
    if DOMUtils.isSelectionInTextNode(selection)
      node = selection.anchorNode
      offset = selection.anchorOffset
      @_teardownListeners()
      selection.setBaseAndExtent(node, offset - 1, node, offset)
      document.execCommand("delete")
      @_setupListeners()

  # This component works by re-rendering on every change and restoring the
  # selection. This is also how standard React controlled inputs work too.
  #
  # Since the contents of the contenteditable are complex, nested DOM
  # structures, a simple replacement of the DOM is not easy. There are a
  # variety of edge cases that we need to correct for and prepare both the
  # HTML and the selection to be serialized without error.
  _normalize: ->
    @_cleanHTML()
    @_cleanSelection()

  # We need to clean the HTML on input to fix several edge cases that
  # arise when we go to save the selection state and restore it on the
  # next render.
  _cleanHTML: ->
    return unless @_editableNode()

    # One issue is that we need to pre-normalize the HTML so it looks the
    # same after it gets re-inserted. If we key selection markers off of an
    # non normalized DOM, then they won't match up when the HTML gets reset.
    #
    # The Node.normalize() method puts the specified node and all of its
    # sub-tree into a "normalized" form. In a normalized sub-tree, no text
    # nodes in the sub-tree are empty and there are no adjacent text
    # nodes.
    @_editableNode().normalize()

    @_collapseAdjacentLists()

    @_fixLeadingBRCondition()

  # An issue arises from <br/> tags immediately inside of divs. In this
  # case the cursor's anchor node will not be the <br/> tag, but rather
  # the entire enclosing element. Sometimes, that enclosing element is the
  # container wrapping all of the content. The browser has a native
  # built-in feature that will automatically scroll the page to the bottom
  # of the current element that the cursor is in if the cursor is off the
  # screen. In the given case, that element is the whole div. The net
  # effect is that the browser will scroll erroneously to the bottom of
  # the whole content div, which is likely NOT where the cursor is or the
  # user wants. The solution to this is to replace this particular case
  # with <span></span> tags and place the cursor in there.
  _fixLeadingBRCondition: ->
    treeWalker = document.createTreeWalker @_editableNode()
    while treeWalker.nextNode()
      currentNode = treeWalker.currentNode
      if @_hasLeadingBRCondition(currentNode)
        newNode = document.createElement("div")
        newNode.appendChild(document.createElement("br"))
        currentNode.replaceChild(newNode, currentNode.childNodes[0])
    return

  _hasLeadingBRCondition: (node) ->
    childNodes = node.childNodes
    return childNodes.length >= 2 and childNodes[0].nodeName is "BR"

  # If users ended up with two <ul> lists adjacent to each other, we
  # collapse them into one. We leave adjacent <ol> lists intact in case
  # the user wanted to restart the numbering sequence
  _collapseAdjacentLists: ->
    els = @_editableNode().querySelectorAll('ul')

    # This mutates the DOM in place.
    DOMUtils.Mutating.collapseAdjacentElements(els)

  # After an input, the selection can sometimes get itself into a state
  # that either can't be restored properly, or will cause undersirable
  # native behavior. This method, in combination with `_cleanHTML`, fixes
  # each of those scenarios before we save and later restore the
  # selection.
  _cleanSelection: ->
    selection = document.getSelection()
    return unless selection.anchorNode? and selection.focusNode?

    # The _unselectableNode case only is valid when it's at the very top
    # (offset 0) of the node. If the offsets are > 0 that means we're
    # trying to select somewhere within some sort of containing element.
    # This is okay to do. The odd case only arises at the top of
    # unselectable elements.
    return if selection.anchorOffset > 0 or selection.focusOffset > 0

    if selection.isCollapsed and @_unselectableNode(selection.focusNode)
      @_teardownListeners()
      treeWalker = document.createTreeWalker(selection.focusNode)
      while treeWalker.nextNode()
        currentNode = treeWalker.currentNode
        if @_unselectableNode(currentNode)
          selection.setBaseAndExtent(currentNode, 0, currentNode, 0)
          break
      @_setupListeners()
    return

  _unselectableNode: (node) ->
    return true if not node
    if node.nodeType is Node.TEXT_NODE and DOMUtils.isBlankTextNode(node)
      return true
    else if node.nodeType is Node.ELEMENT_NODE
      child = node.firstChild
      return true if not child
      hasText = (child.nodeType is Node.TEXT_NODE and not DOMUtils.isBlankTextNode(node))
      hasBr = (child.nodeType is Node.ELEMENT_NODE and node.nodeName is "BR")
      return not hasText and not hasBr

    else return false

  _onBlur: (event) =>
    @setInnerState dragging: false
    return if @_editableNode().parentElement.contains event.relatedTarget
    @_runEventCallbackOnExtensions("onBlur", event)
    @setInnerState editableFocused: false

  _onFocus: (event) =>
    @setInnerState editableFocused: true
    @_runEventCallbackOnExtensions("onFocus", event)

  _editableNode: =>
    React.findDOMNode(@refs.contenteditable)

  ######### SELECTION MANAGEMENT ##########
  #
  # Saving and restoring a selection is difficult with React.
  #
  # React only handles Input and Textarea elements:
  # https://github.com/facebook/react/blob/master/src/browser/ui/ReactInputSelection.js
  # This is because they expose a very convenient `selectionStart` and
  # `selectionEnd` integer.
  #
  # Contenteditable regions are trickier. They require the more
  # sophisticated `Range` and `Selection` APIs.
  #
  # Range docs:
  # http://www.w3.org/TR/DOM-Level-2-Traversal-Range/ranges.html
  #
  # Selection API docs:
  # http://www.w3.org/TR/selection-api/#dfn-range
  #
  # A Contenteditable region can have arbitrary html inside of it. This
  # means that a selection start point can be some node (the `anchorNode`)
  # and its end point can be a completely different node (the `focusNode`)
  #
  # When React re-renders, all of the DOM nodes may change. They may
  # look exactly the same, but have different object references.
  #
  # This means that your old references to `anchorNode` and `focusNode`
  # may be bad and no longer in scope or painted.
  #
  # In order to restore the selection properly we need to re-find the
  # equivalent `anchorNode` and `focusNode`. Luckily we can use the
  # `isEqualNode` method to get a shallow comparison of the nodes.
  #
  # Unfortunately it's possible for `isEqualNode` to match more than one
  # node since two nodes may look very similar.
  #
  # To fix this we need to keep track of the original indices to determine
  # which node is most likely the matching one.

  # http://www.w3.org/TR/selection-api/#selectstart-event
  _setupListeners: =>
    @_ignoreInputChanges = false
    @_mutationObserver.observe(@_editableNode(), @_mutationConfig())
    document.addEventListener("selectionchange", @_saveSelectionState)
    @_editableNode().addEventListener('contextmenu', @_onShowContextMenu)

  # https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver
  _mutationConfig: ->
    subtree: true
    childList: true
    attributes: true
    characterData: true
    attributeOldValue: true
    characterDataOldValue: true

  _teardownListeners: =>
    document.removeEventListener("selectionchange", @_saveSelectionState)
    @_mutationObserver.disconnect()
    @_ignoreInputChanges = true
    @_editableNode().removeEventListener('contextmenu', @_onShowContextMenu)

  getCurrentSelection: => _.clone(@_selection ? {})
  getPreviousSelection: => _.clone(@_previousSelection ? {})

  # Every time the cursor changes we need to preserve its location and
  # state.
  #
  # We can't use React's `state` variable because cursor position is not
  # naturally supported in the virtual DOM.
  #
  # We also need to make sure that node references are cloned so they
  # don't change out from underneath us.
  #
  # We also need to keep references to the previous selection state in
  # order for undo/redo to work properly.
  #
  # We need to be sure to deeply `cloneNode`. This is because sometimes
  # our anchorNodes are divs with nested <br> tags. If we don't do a deep
  # clone then when `isEqualNode` is run it will erroneously return false
  # and our selection restoration will fail.
  #
  # The Selection API has the concept of an `anchorNode` and a
  # `focusNode`. The `anchorNode` is where the selection started from and
  # does not move. The `focusNode` is where the end of the selection
  # currently is and may move. A "caret" is simply a selection whose
  # anchorNode == focusNode and anchorOffset == focusOffset.
  #
  # An `anchorNode` is also known as a `startNode`, or `baseNode`. We use
  # the alias `startNode` since I think it makes more intuitive sense.
  #
  # A `focusNode` is also known as an `endNode` or `focusNode`. I use the
  # `endNode` alias since it makes more inuitive sense.
  #
  # When we restore the selection later, we need to find a node that looks
  # the same as the one we saved (since they're different object
  # references). Unfortunately there many be many nodes that "look" the
  # same (match the `isEqualNode`) test. For example, say I have a bunch
  # of lines with the TEXT_NODE "Foo". All of those will match
  # `isEqualNode`. To fix this we assume there will be multiple matches
  # and keep track of the index of the match. e.g. all "Foo" TEXT_NODEs
  # may look alike, but I know I want the Nth "Foo" TEXT_NODE. We store
  # this information in the `startNodeIndex` and `endNodeIndex` fields via
  # the `DOMUtils.getNodeIndex` method.
  _saveSelectionState: =>
    selection = document.getSelection()
    context = @_editableNode()
    return if DOMUtils.isSameSelection(selection, @_selection, context)
    return unless selection.anchorNode? and selection.focusNode?
    return unless DOMUtils.selectionInScope(selection, context)

    @_previousSelection = @_selection

    @_selection =
      startNode: selection.anchorNode.cloneNode(true)
      startOffset: selection.anchorOffset
      startNodeIndex: DOMUtils.getNodeIndex(context, selection.anchorNode)
      endNode: selection.focusNode.cloneNode(true)
      endOffset: selection.focusOffset
      endNodeIndex: DOMUtils.getNodeIndex(context, selection.focusNode)
      isCollapsed: selection.isCollapsed

    @_onSelectionChanged(selection)

    @setInnerState
      selection: @_selection
      editableFocused: true

    return @_selection

  _setSelectionSnapshot: (selection) =>
    @_previousSelection = @_selection
    @_selection = selection
    @setInnerState
      selection: @_selection
      editableFocused: true

  _onSelectionChanged: (selection) ->
    @props.onSelectionChanged(selection, @_editableNode())
    # The bounding client rect has changed
    @setInnerState editableNode: @_editableNode()

  # We use global listeners to determine whether or not dragging is
  # happening. This is because dragging may stop outside the scope of
  # this element. Note that the `dragstart` and `dragend` events don't
  # detect text selection. They are for drag & drop.
  _setupGlobalMouseListener: =>
    @__onMouseDown = _.bind(@_onMouseDown, @)
    @__onMouseMove = _.bind(@_onMouseMove, @)
    @__onMouseUp = _.bind(@_onMouseUp, @)
    window.addEventListener("mousedown", @__onMouseDown)
    window.addEventListener("mouseup", @__onMouseUp)

  _teardownGlobalMouseListener: =>
    window.removeEventListener("mousedown", @__onMouseDown)
    window.removeEventListener("mouseup", @__onMouseUp)

  _onShowContextMenu: (event) =>
    @refs["toolbarController"]?.forceClose()
    event.preventDefault()

    remote = require('remote')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')

    menu = new Menu()

    @_runEventCallbackOnExtensions("onShowContextMenu", event, menu)
    menu.append(new MenuItem({ label: 'Cut', role: 'cut'}))
    menu.append(new MenuItem({ label: 'Copy', role: 'copy'}))
    menu.append(new MenuItem({ label: 'Paste', role: 'paste'}))
    menu.append(new MenuItem({ label: 'Paste and Match Style', click: =>
      NylasEnv.getCurrentWindow().webContents.pasteAndMatchStyle()
    }))
    menu.popup(remote.getCurrentWindow())

  _onMouseDown: (event) =>
    @_mouseDownEvent = event
    @_mouseHasMoved = false
    window.addEventListener("mousemove", @__onMouseMove)

    # We can't use the native double click event because that only fires
    # on the second up-stroke
    if Date.now() - (@_lastMouseDown ? 0) < 250
      @_onDoubleDown(event)
      @_lastMouseDown = 0 # to prevent triple down
    else
      @_lastMouseDown = Date.now()

  _onDoubleDown: (event) =>
    editable = @_editableNode()
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @setInnerState doubleDown: true

  _onMouseMove: (event) =>
    if not @_mouseHasMoved
      @_onDragStart(@_mouseDownEvent)
      @_mouseHasMoved = true

  _onMouseUp: (event) =>
    window.removeEventListener("mousemove", @__onMouseMove)

    if @innerState.doubleDown
      @setInnerState doubleDown: false

    if @_mouseHasMoved
      @_mouseHasMoved = false
      @_onDragEnd(event)

    editableNode = @_editableNode()
    selection = document.getSelection()
    return event unless DOMUtils.selectionInScope(selection, editableNode)

    @_runEventCallbackOnExtensions("onClick", event)
    return event

  _onDragStart: (event) =>
    editable = @_editableNode()
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @setInnerState dragging: true

  _onDragEnd: (event) =>
    if @innerState.dragging
      @setInnerState dragging: false
    return event

  # We restore the Selection via the `setBaseAndExtent` property of the
  # `Selection` API
  #
  # See http://w3c.github.io/selection-api/#widl-Selection-setBaseAndExtent-void-Node-anchorNode-unsigned-long-anchorOffset-Node-focusNode-unsigned-long-focusOffset
  #
  # Since the last time we saved the `@_selection`, the DOM may have
  # completely changed due to a re-render. To the user it may look
  # identical, but the newly rendered region may be comprised of
  # completely new DOM nodes. Our old node references may not exist
  # anymore. As such, we have the task of re-finding the nodes again and
  # creating a new selection that matches as accurately as possible.
  #
  # There are multiple ways of setting a new selection with the Selection
  # API. One very common one is to create a new Range object and then call
  # `addRange` on a selection instance. This does NOT work for us because
  # `Range` objects are direction-less. A Selection's start node (aka
  # anchor node aka base node) can be "after" a selection's end node (aka
  # focus node aka extent node).
  #
  # force - when set to true it will not care whether or not the selection
  #         is already in the box. Normally we only restore when the
  #         contenteditable is in focus
  # collapse - Can either be "end" or "start". When we reset the
  #            selection, we'll collapse the range into a single caret
  #            position
  _restoreSelection: ({force, collapse}={}) =>
    return if @innerState.dragging
    return if not @_selection?
    return if document.activeElement isnt @_editableNode() and not force
    return if not @_selection.startNode? or not @_selection.endNode?

    editable = @_editableNode()
    newStartNode = DOMUtils.findSimilarNodes(editable, @_selection.startNode)[@_selection.startNodeIndex]
    newEndNode = DOMUtils.findSimilarNodes(editable, @_selection.endNode)[@_selection.endNodeIndex]
    return if not newStartNode? or not newEndNode?

    @_teardownListeners()
    selection = document.getSelection()
    selection.setBaseAndExtent(newStartNode,
                               @_selection.startOffset,
                               newEndNode,
                               @_selection.endOffset)

    @_onSelectionChanged(selection)
    @_setupListeners()

  # This needs to be in the contenteditable area because we need to first
  # restore the selection before calling the `execCommand`
  #
  # If the url is empty, that means we want to remove the url.
  #
  # TODO: Move this into floating-toolbar-container once we do a refactor
  # pass on the Selection object.
  _onSaveUrl: (url, linkToModify) =>
    if linkToModify?
      linkToModify = DOMUtils.findSimilarNodes(@_editableNode(), linkToModify)?[0]?.childNodes[0]

      return unless linkToModify?
      return if linkToModify.getAttribute?('href').trim() is url.trim()

      range =
        anchorNode: linkToModify
        anchorOffset: 0
        focusNode: linkToModify
        focusOffset: linkToModify.length

      if url.trim().length is 0
        @_execCommand ["unlink", false], range
      else @_execCommand ["createLink", false, url], range

    else
      @_restoreSelection(force: true)
      if not document.getSelection().isCollapsed
        if url.trim().length is 0
          @_execCommand ["unlink", false]
        else @_execCommand ["createLink", false, url]
        @_restoreSelection(force: true, collapse: "end")

    return

  _execCommand: (commandArgs=[], selectionRange={}) =>
    {anchorNode, anchorOffset, focusNode, focusOffset} = selectionRange
    @_teardownListeners()
    if anchorNode and focusNode
      selection = document.getSelection()
      selection.setBaseAndExtent(anchorNode, anchorOffset, focusNode, focusOffset)
    document.execCommand.apply(document, commandArgs)
    @_setupListeners()
    @_onDOMMutated()

module.exports = Contenteditable
