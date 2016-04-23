/** @babel */

import { MessageStore, React, ReactDOM } from 'nylas-exports';
import PGPKeyStore from './pgp-key-store';
import pgp from 'kbpgp';

class DecryptMessageButton extends React.Component {
  static displayName = 'DecryptMessageButton';

  static propTypes = {
    message: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);

    this.state = this._getStateFromStores();
  }

  _getStateFromStores() {
    const { message } = this.props;
    return {
      isDecrypted: PGPKeyStore.isDecrypted(message),
      wasEncrypted: PGPKeyStore.hasEncryptedComponent(message),
      status: PGPKeyStore.msgStatus(message),
    };
  }

  componentDidMount() {
    this.unlistenKeystore = PGPKeyStore.listen(this._onKeystoreChange, this);
  }

  componentWillUnmount() {
    this.unlistenKeystore();
  }

  _onKeystoreChange() {
    this.setState(this._getStateFromStores());

    // every time a new key gets unlocked/fetched, try to decrypt this message
    if (!this.state.isDecrypted) {
      PGPKeyStore.decrypt(this.props.message);
    }
  }

  _onClick = () => {
    const { message } = this.props;
    const passphrase = ReactDOM.findDOMNode(this.refs.passphrase).value;

    for (let recipient of message.to) {
      // right now, just try to unlock all possible keys
      // (many will fail - TODO?)
      const privateKeys = PGPKeyStore.privKeys({ address: recipient.email, timed: false });
      for (let privateKey of privateKeys) {
        PGPKeyStore.getKeyContents({ key: privateKey, passphrase: passphrase });
      }
    }
  };

  render() {
    if (this.state.wasEncrypted && !this.state.isDecrypted) {
      return (
        <div className="n1-keybase">
          <input type="password" ref="passphrase" />
          <button className="btn btn-toolbar pull-right" title="Decrypt email body" onClick={this._onClick} ref="button">
            Decrypt
          </button>
          <div className="message" ref="message">{this.state.status}</div>
        </div>
      );
    } else if (this.state.wasEncrypted && this.state.isDecrypted) {
      // TODO a message saying "this was decrypted with the key for ___@___.com"
      return (
        <div className="n1-keybase">
          <div className="decrypted" ref="decrypted">{this.state.status}</div>
        </div>
      );
    } else {
      // TODO inform user of errors/etc. instead of failing without showing it
      return (
        <div className="n1-keybase">
        </div>
      );
    }
  }
}

export default DecryptMessageButton;
