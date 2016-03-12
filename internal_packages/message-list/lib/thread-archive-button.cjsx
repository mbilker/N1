{RetinaImg} = require 'nylas-component-kit'
{Actions,
 React,
 TaskFactory,
 DOMUtils,
 AccountStore,
 FocusedPerspectiveStore} = require 'nylas-exports'

class ThreadArchiveButton extends React.Component
  @displayName: "ThreadArchiveButton"
  @containerRequired: false

  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    canArchiveThreads = FocusedPerspectiveStore.current().canArchiveThreads([@props.thread])
    return <span /> unless canArchiveThreads

    <button className="btn btn-toolbar btn-archive"
            style={order: -107}
            title="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onArchive: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    tasks = TaskFactory.tasksForArchiving
      threads: [@props.thread]
    Actions.queueTasks(tasks)
    Actions.popSheet()
    e.stopPropagation()

module.exports = ThreadArchiveButton
