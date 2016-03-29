_ = require 'underscore'
React = require 'react'
SwipeContainer = require './swipe-container'
{Utils} = require 'nylas-exports'

class ListTabularItem extends React.Component
  @displayName = 'ListTabularItem'
  @propTypes =
    metrics: React.PropTypes.object
    columns: React.PropTypes.arrayOf(React.PropTypes.object).isRequired
    item: React.PropTypes.object.isRequired
    itemProps: React.PropTypes.object
    onSelect: React.PropTypes.func
    onClick: React.PropTypes.func
    onDoubleClick: React.PropTypes.func

  # DO NOT DELETE unless you know what you're doing! This method cuts
  # React.Perf.wasted-time from ~300msec to 20msec by doing a deep
  # comparison of props before triggering a re-render.
  shouldComponentUpdate: (nextProps, nextState) =>
    if not Utils.isEqualReact(@props.item, nextProps.item) or @props.columns isnt nextProps.columns
      @_columnCache = null
      return true
    if not Utils.isEqualReact(Utils.fastOmit(@props, ['item']), Utils.fastOmit(nextProps, ['item']))
      return true
    false

  render: =>
    className = "list-item list-tabular-item #{@props.itemProps?.className}"
    props = Utils.fastOmit(@props.itemProps ? {}, ['className'])

    # It's expensive to compute the contents of columns (format timestamps, etc.)
    # We only do it if the item prop has changed.
    @_columnCache ?= @_columns()

    <SwipeContainer {...props} onClick={@_onClick} style={position:'absolute', top: @props.metrics.top, width:'100%', height:@props.metrics.height}>
      <div className={className} style={height:@props.metrics.height}>
        {@_columnCache}
      </div>
    </SwipeContainer>

  _columns: =>
    names = {}
    for column in (@props.columns ? [])
      if names[column.name]
        console.warn("ListTabular: Columns do not have distinct names, will cause React error! `#{column.name}` twice.")
      names[column.name] = true

      <div key={column.name}
           displayName={column.name}
           style={{flex: column.flex, width: column.width}}
           className="list-column list-column-#{column.name}">
        {column.resolver(@props.item, @)}
      </div>

  _onClick: (event) =>
    @props.onSelect?(@props.item, event)

    @props.onClick?(@props.item, event)
    if @_lastClickTime? and Date.now() - @_lastClickTime < 350
      @props.onDoubleClick?(@props.item, event)

    @_lastClickTime = Date.now()


module.exports = ListTabularItem
