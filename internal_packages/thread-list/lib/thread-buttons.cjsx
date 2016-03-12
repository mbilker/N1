_ = require 'underscore'
React = require "react/addons"
classNames = require 'classnames'
ThreadListStore = require './thread-list-store'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
 TaskFactory,
 AccountStore,
 CategoryStore,
 FocusedContentStore,
 FocusedPerspectiveStore} = require "nylas-exports"

class ThreadBulkArchiveButton extends React.Component
  @displayName: 'ThreadBulkArchiveButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    canArchiveThreads = FocusedPerspectiveStore.current().canArchiveThreads(@props.selection.items())
    return <span /> unless canArchiveThreads

    <button style={order:-107}
            className="btn btn-toolbar"
            title="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onArchive: =>
    tasks = TaskFactory.tasksForArchiving
      threads: @props.selection.items()
    Actions.queueTasks(tasks)
    return

class ThreadBulkTrashButton extends React.Component
  @displayName: 'ThreadBulkTrashButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    canTrashThreads = FocusedPerspectiveStore.current().canTrashThreads(@props.selection.items())
    return <span /> unless canTrashThreads

    <button style={order:-106}
            className="btn btn-toolbar"
            title="Move to Trash"
            onClick={@_onRemove}>
      <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onRemove: =>
    tasks = TaskFactory.tasksForMovingToTrash
      threads: @props.selection.items()
    Actions.queueTasks(tasks)
    return


class ThreadBulkStarButton extends React.Component
  @displayName: 'ThreadBulkStarButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: ->
    postClickStarredState = _.every @props.selection.items(), (t) -> t.starred is false
    title = "Remove stars from all"
    imageName = "toolbar-star-selected.png"

    if postClickStarredState
      title = "Star all"
      imageName = "toolbar-star.png"

    <button style={order:-104}
            className="btn btn-toolbar"
            title={title}
            onClick={@_onStar}>
      <RetinaImg name={imageName} mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onStar: =>
    task = TaskFactory.taskForInvertingStarred(threads: @props.selection.items())
    Actions.queueTask(task)
    return


class ThreadBulkToggleUnreadButton extends React.Component
  @displayName: 'ThreadBulkToggleUnreadButton'
  @containerRequired: false

  @propTypes:
    selection: React.PropTypes.object.isRequired

  render: =>
    postClickUnreadState = _.every @props.selection.items(), (t) -> _.isMatch(t, {unread: false})
    fragment = if postClickUnreadState then "unread" else "read"

    <button style={order:-105}
            className="btn btn-toolbar"
            title="Mark as #{fragment}"
            onClick={@_onClick}>
      <RetinaImg name="toolbar-markas#{fragment}.png"
                 mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onClick: =>
    task = TaskFactory.taskForInvertingUnread(threads: @props.selection.items())
    Actions.queueTask(task)
    return


ThreadNavButtonMixin =
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_unsubscribe = ThreadListStore.listen @_onStoreChange
    @_unsubscribe_focus = FocusedContentStore.listen @_onStoreChange

  isFirstThread: ->
    selectedId = FocusedContentStore.focusedId('thread')
    ThreadListStore.dataSource().get(0)?.id is selectedId

  isLastThread: ->
    selectedId = FocusedContentStore.focusedId('thread')

    lastIndex = ThreadListStore.dataSource().count() - 1
    ThreadListStore.dataSource().get(lastIndex)?.id is selectedId

  componentWillUnmount: ->
    @_unsubscribe()
    @_unsubscribe_focus()

  _onStoreChange: ->
    @setState @_getStateFromStores()


DownButton = React.createClass
  displayName: 'DownButton'
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick} title="Next thread">
      <RetinaImg name="toolbar-down-arrow.png" mode={RetinaImg.Mode.ContentIsMask} />
    </div>

  _classSet: ->
    classNames
      "btn-icon": true
      "message-toolbar-arrow": true
      "down": true
      "disabled": @state.disabled

  _onClick: ->
    return if @state.disabled
    NylasEnv.commands.dispatch(document.body, 'core:next-item')
    return

  _getStateFromStores: ->
    disabled: @isLastThread()

UpButton = React.createClass
  displayName: 'UpButton'
  mixins: [ThreadNavButtonMixin]

  render: ->
    <div className={@_classSet()} onClick={@_onClick} title="Previous thread">
      <RetinaImg name="toolbar-up-arrow.png" mode={RetinaImg.Mode.ContentIsMask} />
    </div>

  _classSet: ->
    classNames
      "btn-icon": true
      "message-toolbar-arrow": true
      "up": true
      "disabled": @state.disabled

  _onClick: ->
    return if @state.disabled
    NylasEnv.commands.dispatch(document.body, 'core:previous-item')
    return

  _getStateFromStores: ->
    disabled: @isFirstThread()

UpButton.containerRequired = false
DownButton.containerRequired = false

module.exports = {
  DownButton,
  UpButton,
  ThreadBulkArchiveButton,
  ThreadBulkTrashButton,
  ThreadBulkStarButton,
  ThreadBulkToggleUnreadButton
}
