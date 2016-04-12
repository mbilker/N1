_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
classNames = require 'classnames'
RetinaImg = require './retina-img'
EventedIFrame = require './evented-iframe'
{NylasSyncStatusStore,
 FocusedPerspectiveStore} = require 'nylas-exports'


INBOX_ZERO_ANIMATIONS = [
  'gem',
  'oasis',
  'tron',
  'airstrip',
  'galaxy',
]

class EmptyPerspectiveState extends React.Component
  @displayName: "EmptyPerspectiveState"

  @propTypes:
    perspective: React.PropTypes.object,
    messageOverride: React.PropTypes.string,

  render: ->
    {messageOverride, perspective} = @props
    name = perspective.categoriesSharedName()
    name = 'archive' if perspective.isArchive()
    name = perspective.name if not name
    name = name.toLowerCase() if name

    <div className="perspective-empty-state">
      {if name
        <RetinaImg
          name={"ic-emptystate-#{name}.png"}
          mode={RetinaImg.Mode.ContentIsMask}
        />
      }
      <div className="message">{messageOverride}</div>
    </div>

class EmptyInboxState extends React.Component
  @displayName: "EmptyInboxState"

  @propTypes:
    containerRect: React.PropTypes.object,

  _getScalingFactor: =>
    {width} = @props.containerRect
    return null unless width
    return null if width > 600
    return (width + 100) / 1000

  _getAnimationName: (now = new Date()) =>
    msInADay = 8.64e7
    msSinceEpoch = now.getTime() - (now.getTimezoneOffset() * 1000 * 60)
    daysSinceEpoch = Math.floor(msSinceEpoch / msInADay)
    idx = daysSinceEpoch  % INBOX_ZERO_ANIMATIONS.length
    return INBOX_ZERO_ANIMATIONS[idx]

  render: ->
    animationName = @_getAnimationName()
    factor = @_getScalingFactor()
    style = if factor
      {transform: "scale(#{factor})"}
    else
      {}

    <div className="inbox-zero-animation">
      <div className="animation-wrapper" style={style}>
        <iframe src={"animations/inbox-zero/#{animationName}/#{animationName}.html"}/>
        <div className="message">Hooray! You’re done.</div>
      </div>
    </div>


class EmptyListState extends React.Component
  @displayName = 'EmptyListState'
  @propTypes =
    visible: React.PropTypes.bool.isRequired

  constructor: (@props) ->
    @_mounted = false
    @state =
      syncing: NylasSyncStatusStore.busy()
      active: false
      rect: {}

  componentDidMount: ->
    @_mounted = true
    @_unlisteners = []
    @_unlisteners.push NylasSyncStatusStore.listen(@_onChange, @)
    window.addEventListener('resize', @_onResize)
    if @props.visible and not @state.active
      rect = @_getDimensions()
      @setState(active:true, rect: rect)

  shouldComponentUpdate: (nextProps, nextState) ->
    return true if nextProps.visible isnt @props.visible
    return not _.isEqual(nextState, @state)

  componentWillUnmount: ->
    @_mounted = false
    unlisten() for unlisten in @_unlisteners
    window.removeEventListener('resize', @_onResize)

  componentDidUpdate: ->
    if @props.visible and not @state.active
      rect = @_getDimensions()
      @setState(active:true, rect: rect)

  componentWillReceiveProps: (newProps) ->
    if newProps.visible is false
      @setState(active:false)

  render: ->
    return <span /> unless @props.visible
    ContentComponent = EmptyPerspectiveState
    current = FocusedPerspectiveStore.current()

    messageOverride = current.emptyMessage()
    if @state.syncing
      messageOverride = "Please wait while we prepare your mailbox."
    else if current.isInbox()
      ContentComponent = EmptyInboxState

    classes = classNames
      'empty-state': true
      'active': @state.active

    <div className={classes}>
      <ContentComponent
        perspective={current}
        containerRect={@state.rect}
        messageOverride={messageOverride}
      />
    </div>

  _getDimensions: =>
    return null unless @_mounted
    node = ReactDOM.findDOMNode(@)
    rect = node.getBoundingClientRect()
    return {width: rect.width, height: rect.height}

  _onResize: =>
    rect = @_getDimensions()
    if rect
      @setState({rect})

  _onChange: ->
    @setState
      syncing: NylasSyncStatusStore.busy()

module.exports = EmptyListState
