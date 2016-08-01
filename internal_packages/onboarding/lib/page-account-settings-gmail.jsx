import React from 'react';
import {ipcRenderer, shell} from 'electron';
import {RetinaImg} from 'nylas-component-kit';

import {
  pollForGmailAccount,
  buildGmailSessionKey,
  buildGmailAuthURL,
} from './onboarding-helpers';

import OnboardingActions from './onboarding-actions';
import AccountTypes from './account-types';

const clipboard = require('electron').clipboard

export default class AccountSettingsPageGmail extends React.Component {
  static displayName = "AccountSettingsPageGmail";

  static propTypes = {
    accountInfo: React.PropTypes.object,
  };

  constructor() {
    super()
    this.state = {
      showAlternative: false,
    }
  }

  componentDidMount() {
    // Show the "Sign in to Gmail" prompt for a moment before actually bouncing
    // to Gmail. (400msec animation + 200msec to read)
    this._sessionKey = buildGmailSessionKey();
    this._pollTimer = null;
    this._gmailAuthUrl = buildGmailAuthURL(this._sessionKey)
    this._startTimer = setTimeout(() => {
      shell.openExternal(this._gmailAuthUrl);
      this.startPollingForResponse();
    }, 600);
    setTimeout(() => {
      this.setState({showAlternative: true})
    }, 1500);
  }

  componentWillUnmount() {
    if (this._startTimer) { clearTimeout(this._startTimer); }
    if (this._pollTimer) { clearTimeout(this._pollTimer); }
  }

  startPollingForResponse() {
    let delay = 1000;
    let onWindowFocused = null;
    let poll = null;

    onWindowFocused = () => {
      delay = 1000;
      if (this._pollTimer) {
        clearTimeout(this._pollTimer);
        this._pollTimer = setTimeout(poll, delay);
      }
    };

    poll = () => {
      pollForGmailAccount(this._sessionKey, (err, account) => {
        clearTimeout(this._pollTimer);
        if (account) {
          ipcRenderer.removeListener('browser-window-focus', onWindowFocused);
          OnboardingActions.accountJSONReceived(account);
        } else {
          delay = Math.min(delay * 1.2, 10000);
          this._pollTimer = setTimeout(poll, delay);
        }
      });
    }

    ipcRenderer.on('browser-window-focus', onWindowFocused);
    this._pollTimer = setTimeout(poll, 5000);
  }


  _renderAlternative() {
    let classnames = "input hidden"
    if (this.state.showAlternative) {
      classnames += " fadein"
    }

    return (
      <div className={classnames}>
        <p> Page didn't open?</p>
        <p>Paste into your browser:
          <input type="url" className="url-copy-target" value={this._gmailAuthUrl} />
          <div className="copy-to-clipboard" onClick={() => clipboard.writeText(this._gmailAuthUrl)} onMouseDown={() => this.setState({pressed: true})} onMouseUp={() => this.setState({pressed: false})}>
            <RetinaImg
              name="icon-copytoclipboard.png"
              mode={RetinaImg.Mode.ContentIsMask}
            />
          </div>
        </p>
      </div>
    )
  }


  render() {
    const {accountInfo} = this.props;
    const iconName = AccountTypes.find(a => a.type === accountInfo.type).headerIcon;

    return (
      <div className="page account-setup gmail">
        <div className="logo-container">
          <RetinaImg
            name={iconName}
            mode={RetinaImg.Mode.ContentPreserve}
            className="logo"
          />
        </div>
        <h2>
          Sign in to Google in<br />your browser.
        </h2>
        <div className="alternative-auth">
          {this._renderAlternative()}
        </div>
      </div>
    );
  }
}
