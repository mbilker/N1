React = require 'react'
ReactDOM = require 'react-dom'
{Utils} = require 'nylas-exports'
{InjectedComponentSet} = require 'nylas-component-kit'

class CollapsedParticipants extends React.Component
  @displayName: "CollapsedParticipants"

  @propTypes:
    # Arrays of Contact objects.
    to: React.PropTypes.array
    cc: React.PropTypes.array
    bcc: React.PropTypes.array

    # Notifies parent when the component has been clicked. This is usually
    # used to expand the participants field
    onClick: React.PropTypes.func

  @defaultProps:
    to: []
    cc: []
    bcc: []

  constructor: (@props={}) ->
    @_keyPrefix = Utils.generateTempId()
    @state =
      numToDisplay: 999
      numRemaining: 0
      numBccRemaining: 0

  componentDidMount: ->
    @_setNumHiddenParticipants()

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidUpdate: ->
    @_setNumHiddenParticipants()

  componentWillReceiveProps: ->
    # Always re-evaluate the hidden participant count when the participant set changes
    @setState({
      numToDisplay: 999
      numRemaining: 0
      numBccRemaining: 0
    })

  render: ->
    contacts = @props.to.concat(@props.cc).map(@_collapsedContact)
    bcc = @props.bcc.map(@_collapsedBccContact)
    toDisplay = contacts.concat(bcc)
    toDisplay = toDisplay[0...@state.numToDisplay]
    if toDisplay.length is 0 then toDisplay = "Recipients"
    <div onClick={ => @props.onClick?()}
         ref="participantsWrap"
         className="collapsed-composer-participants">
      {@_renderNumRemaining()}
      {toDisplay}
    </div>

  _renderNumRemaining: ->
    if @state.numRemaining is 0 and @state.numBccRemaining is 0
      return null
    else if @state.numRemaining > 0 and @state.numBccRemaining is 0
      str = "#{@state.numRemaining} more"
    else if @state.numRemaining is 0 and @state.numBccRemaining > 0
      str = "#{@state.numBccRemaining} Bcc"
    else if @state.numRemaining > 0 and @state.numBccRemaining > 0
      str = "#{@state.numRemaining + @state.numBccRemaining} more (#{@state.numBccRemaining} Bcc)"

    return <div className="num-remaining-wrap tokenizing-field"><div className="show-more-fade"></div><div className="num-remaining token">{str}</div></div>

  _collapsedContact: (contact) =>
    name = contact.displayName()
    key = @_keyPrefix + contact.email + contact.name
    <span key={key}
          className="collapsed-contact regular-contact">
      <InjectedComponentSet
        matching={role: "Composer:RecipientChip"}
        exposedProps={contact: contact}
        direction="column"
        inline={true}/>
      {name}
    </span>

  _collapsedBccContact: (contact, i) =>
    name = contact.displayName()
    key = @_keyPrefix + contact.email + contact.name
    if i is 0 then name = "Bcc: #{name}"
    <span key={key}
          className="collapsed-contact bcc-contact">{name}</span>

  _setNumHiddenParticipants: ->
    $wrap = ReactDOM.findDOMNode(@refs.participantsWrap)
    $regulars = $wrap.getElementsByClassName("regular-contact")
    $bccs = $wrap.getElementsByClassName("bcc-contact")

    availableSpace = $wrap.getBoundingClientRect().width
    numRemaining = @props.to.length + @props.cc.length
    numBccRemaining = @props.bcc.length
    numToDisplay = 0
    widthAccumulator = 0

    for $p in $regulars
      widthAccumulator += $p.getBoundingClientRect().width
      break if widthAccumulator >= availableSpace
      numRemaining -= 1
      numToDisplay += 1

    for $p in $bccs
      widthAccumulator += $p.getBoundingClientRect().width
      break if widthAccumulator >= availableSpace
      numBccRemaining -= 1
      numToDisplay += 1

    @setState {numToDisplay, numRemaining, numBccRemaining}

module.exports = CollapsedParticipants
