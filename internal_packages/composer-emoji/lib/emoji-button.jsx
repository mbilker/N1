import {Actions, React, ReactDOM} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

import EmojiButtonPopover from './emoji-button-popover';

class EmojiButton extends React.Component {
  static displayName = 'EmojiButton';

  onClick = () => {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect();
    Actions.openPopover(
      <EmojiButtonPopover />,
      {originRect: buttonRect, direction: 'up'}
    );
  }

  render() {
    return (
      <button tabIndex={-1} className="btn btn-toolbar btn-emoji" title="Insert emoji…" onClick={this.onClick}>
        <RetinaImg name="icon-composer-emoji.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}

export default EmojiButton;
