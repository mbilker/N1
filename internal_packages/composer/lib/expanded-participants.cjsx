_ = require 'underscore'
React = require 'react'
AccountContactField = require './account-contact-field'
ParticipantsTextField = require './participants-text-field'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

Fields = require './fields'

class ExpandedParticipants extends React.Component
  @displayName: "ExpandedParticipants"

  @propTypes:
    # Arrays of Contact objects.
    to: React.PropTypes.array
    cc: React.PropTypes.array
    bcc: React.PropTypes.array
    from: React.PropTypes.array

    # We need to know if the draft is ready so we can enable and disable
    # ParticipantTextFields.
    #
    # It's possible for a ParticipantTextField, before the draft is
    # ready, to start the request to `add`, `remove`, or `edit`. This
    # happens when there are multiple drafts rendering, each requesting
    # focus. A blur event gets fired before the draft is loaded, causing
    # logic to run that sets an empty field. These requests are
    # asynchronous. They may resolve after the draft is in fact ready.
    # This is bad because the desire to `remove` participants may have
    # been made with an empty, non-loaded draft, but executed on the new
    # draft that was loaded in the time it took the async request to
    # return.
    draftReady: React.PropTypes.bool

    # The account to which the current draft belongs
    accounts: React.PropTypes.array

    # The field that should be focused
    focusedField: React.PropTypes.string

    # An enum array of visible fields. Can be any constant in the `Fields`
    # dict.  We are passed these as props instead of holding it as state
    # since this component is frequently unmounted and re-mounted every
    # time it is displayed
    enabledFields: React.PropTypes.array

    # Callback for when a user changes which fields should be visible
    onAdjustEnabledFields: React.PropTypes.func

    # Callback for the participants change
    onChangeParticipants: React.PropTypes.func

    # Callback for the field focus changes
    onChangeFocusedField: React.PropTypes.func

  @defaultProps:
    to: []
    cc: []
    bcc: []
    from: []
    accounts: []
    draftReady: false
    enabledFields: []

  constructor: (@props={}) ->

  componentDidMount: =>
    @_applyFocusedField()

  componentDidUpdate: ->
    @_applyFocusedField()

  render: ->
    <div className="expanded-participants" ref="participantWrap">
      {@_renderFields()}
    </div>

  _applyFocusedField: ->
    if @props.focusedField
      return unless @refs[@props.focusedField]
      if @refs[@props.focusedField].focus
        @refs[@props.focusedField].focus()
      else
        React.findDOMNode(@refs[@props.focusedField]).focus()

  _renderFields: =>
    # Note: We need to physically add and remove these elements, not just hide them.
    # If they're hidden, shift-tab between fields breaks.
    fields = []
    fields.push(
      <ParticipantsTextField
        ref={Fields.To}
        key="to"
        field='to'
        change={@props.onChangeParticipants}
        className="composer-participant-field to-field"
        draftReady={@props.draftReady}
        onFocus={ => @props.onChangeFocusedField(Fields.To) }
        participants={to: @props['to'], cc: @props['cc'], bcc: @props['bcc']} />
    )

    if Fields.Cc in @props.enabledFields
      fields.push(
        <ParticipantsTextField
          ref={Fields.Cc}
          key="cc"
          field='cc'
          draftReady={@props.draftReady}
          change={@props.onChangeParticipants}
          onEmptied={ => @props.onAdjustEnabledFields(hide: [Fields.Cc]) }
          onFocus={ => @props.onChangeFocusedField(Fields.Cc) }
          className="composer-participant-field cc-field"
          participants={to: @props['to'], cc: @props['cc'], bcc: @props['bcc']} />
      )

    if Fields.Bcc in @props.enabledFields
      fields.push(
        <ParticipantsTextField
          ref={Fields.Bcc}
          key="bcc"
          field='bcc'
          draftReady={@props.draftReady}
          change={@props.onChangeParticipants}
          onEmptied={ => @props.onAdjustEnabledFields(hide: [Fields.Bcc]) }
          onFocus={ => @props.onChangeFocusedField(Fields.Bcc) }
          className="composer-participant-field bcc-field"
          participants={to: @props['to'], cc: @props['cc'], bcc: @props['bcc']} />
      )

    if Fields.From in @props.enabledFields
      fields.push(
        <AccountContactField
          key="from"
          ref={Fields.From}
          onChange={({from}) => @props.onChangeParticipants({from})}
          onFocus={ => @props.onChangeFocusedField(Fields.From) }
          accounts={@props.accounts}
          value={@props.from?[0]} />
      )

    fields

module.exports = ExpandedParticipants
