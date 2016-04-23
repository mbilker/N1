/** @babel */

import { React } from 'nylas-exports';
import PGPKeyStore from './pgp-key-store';
import pgp from 'kbpgp';
import _ from 'underscore';

class EncryptMessageButton extends React.Component {
  static displayName = 'EncryptMessageButton';

  // require that we have a draft object available
  static propTypes = {
    draft: React.PropTypes.object.isRequired,
    session: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);

    // plaintext: store the message's plaintext in case the user wants to edit
    // further after hitting the "encrypt" button (i.e. so we can "undo" the
    // encryption)

    // cryptotext: store the message's body here, for comparison purposes (so
    // that if the user edits an encrypted message, we can revert it)
    this.state = {
      plaintext: '',
      cryptotext: '',
      currentlyEncrypted: false,
    };
  }

  componentDidMount() {
    this.unlistenKeystore = PGPKeyStore.listen(this._onKeystoreChange, this);
  }

  componentWillReceiveProps(nextProps) {
    const { currentlyEncrypted, cryptotext } = this.state;

    if (currentlyEncrypted && nextProps.draft.body !== this.props.draft.body && nextProps.draft.body !== cryptotext) {
      // A) we're encrypted
      // B) someone changed something
      // C) the change was AWAY from the "correct" cryptotext
      const body = cryptotext;
      this.props.session.changes.add({ body });
    }
  }

  componentWillUnmount() {
    this.unlistenKeystore();
  }

  _getKeys() {
    const keys = [];
    for (const recipient of this.props.draft.participants({ includeFrom: false, includeBcc: true })) {
      const publicKeys = PGPKeyStore.pubKeys(recipient.email);
      if (publicKeys.length < 1) {
        // no key for this user:
        // push a null so that @_encrypt can line this array up with the
        // array of recipients
        keys.push({ address: recipient.email, key: null });
      } else {
        // note: this, by default, encrypts using every public key associated
        // with the address
        for (const publicKey of publicKeys) {
          if (!publicKey.key) {
            PGPKeyStore.getKeyContents({ key: publicKey });
          } else {
            keys.push(publicKey);
          }
        }
      }
    }

    return keys;
  }

  _onKeystoreChange() {
    // if something changes with the keys, check to make sure the recipients
    // haven't changed (thus invalidating our encrypted message)
    if (this.state.currentlyEncrypted) {
      const newKeys = _.flatten(_.map(this.props.draft.participants(), (participant) =>
        PGPKeyStore.pubKeys(participant.email)
      ));

      const oldKeys = _.flatten(_.map(this.props.draft.participants(), (participant) =>
        PGPKeyStore.pubKeys(participant.email)
      ));

      if (newKeys.length !== oldKeys.length) {
        // someone added/removed a key - our encrypted body is now out of date
        this._toggleCrypt();
      }
    }
  }

  _toggleCrypt() {
    // if decrypted, encrypt, and vice versa
    // addresses which don't have a key
    if (this.state.currentlyEncrypted) {
      // if the message is already encrypted, place the stored plaintext back
      // in the draft (i.e. un-encrypt)
      this.props.session.changes.add({ body: this.state.plaintext });
      this.setState({ currentlyEncrypted: false });
    } else {
      // if not encrypted, save the plaintext, then encrypt
      const plaintext = this.props.draft.body;
      const keys = this._getKeys();

      this._encrypt(plaintext, keys, (err, cryptotext) => {
        if (err) {
          console.warn(err);
          NylasEnv.showErrorDialog(err);
        } else if (cryptotext) {
          this.setState({
            currentlyEncrypted: true,
            plaintext: plaintext,
            cryptotext: cryptotext,
          });
          this.props.session.changes.add({ body: cryptotext });
        }
      });
    }
  }

  _onClick = () => {
    this._toggleCrypt();
  };

  _encrypt(text, keys, cb) {
    // addresses which don't have a key
    const nullAddrs = _.pluck(_.filter(keys, (key) => !key.key), 'address');

    // don't need this, because the message below already says the recipient won't be able to decrypt it
    // if keys.length < 1 or nullAddrs.length == keys.length
    //   NylasEnv.showErrorDialog('This message is being encrypted with no keys - nobody will be able to decrypt it!')

    if (nullAddrs.length > 0) {
      const missingAddrs = nullAddrs.join('\n- ');
      // TODO this message is annoying, needs some work
      // - link to preferences page
      // - formatting, probably an error dialog is the wrong way to do this
      // - potentially an option to disable this warning in the pref. page?
      NylasEnv.showErrorDialog(`At least one key is missing - the following recipients won't be able to decrypt the message:
- ${missingAddrs}

You can add keys for them from the preferences page.`);
    }

    // get the actual key objects
    // and remove the nulls
    const kms = _.compact(_.pluck(keys, 'key'));
    const params = {
      encrypt_for: kms,
      msg: text,
    };
    pgp.box(params, cb);
  }

  render() {
    return (
      <div className="n1-keybase">
        <button title="Encrypt email body" className="btn btn-toolbar" onClick={this._onClick} ref="button">
          Encrypt
        </button>
      </div>
    );
  }
}

export default EncryptMessageButton;
