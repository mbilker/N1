React = require 'react'
ReactDOM = require 'react-dom'
{Utils} = require 'nylas-exports'
_ = require 'underscore'

###
Public: Renders a component provided via the `component` prop, and ensures that
failures in the component's code do not cause state inconsistencies elsewhere in
the application. This component is used by {InjectedComponent} and
{InjectedComponentSet} to isolate third party code that could be buggy.

Occasionally, having your component wrapped in {UnsafeComponent} can cause style
issues. For example, in a Flexbox, the `div.unsafe-component-wrapper` will cause
your `flex` and `order` values to be one level too deep. For these scenarios,
UnsafeComponent looks for `containerStyles` on your React component and attaches
them to the wrapper div:

```coffee
class MyComponent extends React.Component
  @displayName: 'MyComponent'
  @containerStyles:
    flex: 1
    order: 2
```

Section: Component Kit
###
class UnsafeComponent extends React.Component
  @displayName: 'UnsafeComponent'

  ###
  Public: React `props` supported by UnsafeComponent:

   - `component` The {React.Component} to display. All other props will be
     passed on to this component.
  ###
  @propTypes:
    component: React.PropTypes.func.isRequired
    onComponentDidRender: React.PropTypes.func

  @defaultProps:
    onComponentDidRender: ->

  componentDidMount: =>
    @renderInjected()

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidUpdate: =>
    @renderInjected()

  componentWillUnmount: =>
    @unmountInjected()

  render: =>
    <div name="unsafe-component-wrapper" style={@props.component?.containerStyles}></div>

  renderInjected: =>
    node = ReactDOM.findDOMNode(@)
    element = null
    try
      props = Utils.fastOmit(@props, Object.keys(@constructor.propTypes))
      component = @props.component
      element = <component key={name} {...props} />
      @injected = ReactDOM.render(element, node, @props.onComponentDidRender)
    catch err
      if NylasEnv.inDevMode()
        stack = err.stack
        stackEnd = stack.indexOf('react/lib/')
        if stackEnd > 0
          stackEnd = stack.lastIndexOf('\n', stackEnd)
          stack = stack.substr(0,stackEnd)

        element = (
          <div className="unsafe-component-exception">
            <div className="message">{@props.component.displayName} could not be displayed.</div>
            <div className="trace">{stack}</div>
          </div>
        )
      else
        ## TODO
        # Add some sort of notification code here that lets us know when
        # production builds are having issues!
        #
        element = <div></div>

        @injected = ReactDOM.render(element, node)
      NylasEnv.reportError(err)

  unmountInjected: =>
    try
      node = ReactDOM.findDOMNode(@)
      ReactDOM.unmountComponentAtNode(node)
    catch err

  focus: =>
    @_runInjectedDOMMethod('focus')

  blur: =>
    @_runInjectedDOMMethod('blur')

  # Private: Attempts to run the DOM method, ie 'focus', on
  # 1. Any implementation provided by the inner component
  # 2. Any native implementation provided by the DOM
  # 3. Ourselves, so that the method always has /some/ effect.
  #
  _runInjectedDOMMethod: (method) =>
    target = null
    if @injected and @injected[method]
      target = @injected
    else if @injected
      target = ReactDOM.findDOMNode(@injected)
    else
      target = ReactDOM.findDOMNode(@)

    target[method]?()

module.exports = UnsafeComponent
