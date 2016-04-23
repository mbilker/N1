import React from 'react'
import { EditableTable, RetinaImg } from 'nylas-component-kit'
import {DataTransferTypes} from './mail-merge-constants'

function Input({isHeader, colIdx, onDragStart, ...props}) {
  if (!isHeader) {
    return <input {...props} />
  }
  const _onDragStart = event => onDragStart(event, colIdx)

  return (
    <div draggable className="header-cell" onDragStart={_onDragStart}>
      <div className="header-token">
        <RetinaImg name="icon-composer-overflow.png" mode={RetinaImg.Mode.ContentIsMask}/>
        <input {...props} />
      </div>
    </div>
  )
}

Input.propTypes = {
  isHeader: React.PropTypes.bool,
  colIdx: React.PropTypes.number,
  onDragStart: React.PropTypes.func.isRequired,
};

class MailMergeTable extends React.Component {
  static propTypes = {
    draftClientId: React.PropTypes.string,
    tableData: EditableTable.propTypes.tableData,
    selection: React.PropTypes.object,
    onShiftSelection: React.PropTypes.func,
  }

  onDragColumn(event, colIdx) {
    const {draftClientId} = this.props
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dragEffect = "move"
    event.dataTransfer.setData(DataTransferTypes.DraftId, draftClientId)
    event.dataTransfer.setData(DataTransferTypes.ColIdx, colIdx)
  }

  render() {
    return (
      <div className="mail-merge-table">
        <EditableTable
          {...this.props}
          displayHeader
          displayNumbers
          inputProps={{onDragStart: ::this.onDragColumn}}
          InputRenderer={Input}
        />
      </div>
    )
  }
}

export default MailMergeTable
