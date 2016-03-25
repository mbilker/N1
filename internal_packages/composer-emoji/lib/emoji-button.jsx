import React from 'react';
import {Actions} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

import EmojiButtonPopover from './emoji-button-popover';


class EmojiButton extends React.Component {
  static displayName = 'EmojiButton';

  constructor() {
    super();
  }

  onClick = ()=> {
    const buttonRect = React.findDOMNode(this).getBoundingClientRect();
    Actions.openPopover(
      <EmojiButtonPopover />,
      {originRect: buttonRect, direction: 'up'}
    )
  }

  render() {
    return (
      <button className="btn btn-toolbar" title="Insert emoji…" onClick={this.onClick}>
        <RetinaImg name="icon-composer-emoji.png" mode={RetinaImg.Mode.ContentIsMask}/>
      </button>
    );
  }
}

EmojiButton.containerStyles = {
  order: 2,
};

export default EmojiButton;
