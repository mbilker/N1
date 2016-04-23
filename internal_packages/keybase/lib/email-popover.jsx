/** @babel */

import { Actions, React } from 'nylas-exports';
import { ParticipantsTextField } from 'nylas-component-kit';
import _ from 'underscore';

class EmailPopover extends React.Component {
  constructor() {
    super();

    this.state = {
      to: [],
      cc: [],
      bcc: [],
    };
  }

  _onRecipientFieldChange = (contacts) => {
    this.setState(contacts);
  };

  _onDone = () => {
    this.props.onPopoverDone(_.pluck(this.state.to, 'email'));
    Actions.closePopover();
  };

  render() {
    const participants = this.state;

    return (
      <div className="keybase-import-popover">
        <span className="title">
          Associate Emails with Key
        </span>
        <ParticipantsTextField
          field="to"
          className="keybase-participant-field"
          participants={participants}
          change={this._onRecipientFieldChange}
        />
        <button className="btn btn-toolbar" onClick={this._onDone}>Done</button>
      </div>
    );
  }
}

export default EmailPopover;
