Model = require './model'
Contact = require './contact'
Attributes = require '../attributes'
_ = require 'underscore'
moment = require('moment')

class Event extends Model

  @attributes: _.extend {}, Model.attributes,
    'calendarId': Attributes.String
      queryable: true
      modelKey: 'calendarId'
      jsonKey: 'calendar_id'

    'title': Attributes.String
      modelKey: 'title'
      jsonKey: 'title'

    'description': Attributes.String
      modelKey: 'description'
      jsonKey: 'description'

    # Can Have 1 of 4 types of subobjects. The Type can be:
    #
    # time
    #   object: "time"
    #   time: (unix timestamp)
    #
    # timestamp
    #   object: "timestamp"
    #   start_time: (unix timestamp)
    #   end_time: (unix timestamp)
    #
    # date
    #   object: "date"
    #   date: (ISO 8601 date format. i.e. 1912-06-23)
    #
    # datespan
    #   object: "datespan"
    #   start_date: (ISO 8601 date)
    #   end_date: (ISO 8601 date)
    'when': Attributes.Object
      modelKey: 'when'

    'location': Attributes.String
      modelKey: 'location'
      jsonKey: 'location'

    'owner': Attributes.String
      modelKey: 'owner'
      jsonKey: 'owner'

    ## Subobject:
    # name (string) - The participant's full name (optional)
    # email (string) - The participant's email address
    # status (string) - Attendance status. Allowed values are yes, maybe,
    #                   no and noreply. Defaults is noreply
    # comment (string) - A comment by the participant (optional)
    'participants': Attributes.Object
      modelKey: 'participants'
      jsonKey: 'participants'

    'status': Attributes.String
      modelKey: 'status'
      jsonKey: 'status'

    'readOnly': Attributes.Boolean
      modelKey: 'readOnly'
      jsonKey: 'read_only'

    'busy': Attributes.Boolean
      modelKey: 'busy'
      jsonKey: 'busy'

    # Has a sub object of the form:
    # rrule: (array) - Array of recurrence rule (RRULE) strings. See RFC-2445
    # timezone: (string) - IANA time zone database formatted string
    #                      (e.g. America/New_York)
    'recurrence': Attributes.Object
      modelKey: 'recurrence'
      jsonKey: 'recurrence'

    ################ EXTRACTED ATTRIBUTES ##############

    # The "object" type of the "when" object. Can be either "time",
    # "timestamp", "date", or "datespan"
    'type': Attributes.String
      modelKey: 'type'
      jsonKey: '_type'

    # The calculated Unix start time. See the implementation for how we
    # treat each type of "when" attribute.
    'start': Attributes.Number
      queryable: true
      modelKey: 'start'
      jsonKey: '_start'

    # The calculated Unix end time. See the implementation for how we
    # treat each type of "when" attribute.
    'end': Attributes.Number
      queryable: true
      modelKey: 'end'
      jsonKey: '_end'

  # We use moment to parse the date so we can more easily pick up the
  # current timezone of the current locale.
  #
  # We also create a start and end times that span the full day without
  # bleeding into the next.
  _unixRangeForDatespan: (start_date, end_date) ->
    return {
      start: moment(start_date).unix()
      end: moment(end_date).add(1, 'day').subtract(1, 'second').unix()
    }

  fromJSON: (json) ->
    super(json)

    return @ unless @when

    if @when.time
      {@start, @end} = {start: @when.time, end: @when.time}
    else if @when.start_time and @when.end_time
      {@start, @end} = {start: @when.start_time, end: @when.end_time}
    else if @when.date
      {@start, @end} = @_unixRangeForDatespan(@when.date, @when.date)
    else if @when.start_date and @when.end_date
      {@start, @end} = @_unixRangeForDatespan(@when.start_date, @when.end_date)

    return @

  fromDraft: (draft) ->
    if !@title? or @title.length is 0
      @title = draft.subject

    if !@participants? or @participants.length is 0
      @participants = draft.participants().map (contact) ->
        name: contact.name
        email: contact.email
        status: "noreply"

    return @

  isAllDay: ->
    daySpan = 86400 - 1
    (@end - @start) >= daySpan

  participantForMe: =>
    for p in @participants
      if (new Contact(email: p.email)).isMe()
        return p
    return null

module.exports = Event
