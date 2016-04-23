/** @babel */

import { Utils, React, RegExpUtils } from 'nylas-exports';
import PGPKeyStore from './pgp-key-store';
import kb from './keybase';
import pgp from 'kbpgp';
import _ from 'underscore';

class KeyAdder extends React.Component {
  static displayName = 'KeyAdder';

  constructor(props) {
    super(props);

    this.state = {
      address: '',
      keyContents: '',
      passphrase: '',

      pubKey: false,
      privKey: false,
      generate: false,

      validAddress: false,
      validKeyBody: false,

      placeholder: 'Your generated public key will appear here. Share it with your friends!',
    };
  }

  _onPastePubButtonClick = () => {
    this.setState({
      pubKey: !this.state.pubKey,
      generate: false,
      privKey: false,
      address: '',
      keyContents: '',
    });
  };

  _onPastePrivButtonClick = () => {
    this.setState({
      pubKey: false,
      generate: false,
      privKey: !this.state.privKey,
      address: '',
      keyContents: '',
      passphrase: '',
    });
  };

  _onGenerateButtonClick = () => {
    this.setState({
      generate: !this.state.generate,
      pubKey: false,
      privKey: false,
      address: '',
      keyContents: '',
      passphrase: '',
    });
  };

  _renderAddButtons() {
    return (
      <div>
        Add a PGP Key:
        <button className="btn key-creation-button" title="Paste in a Public Key" onClick={this._onPastePubButtonClick}>Paste in a Public Key</button>
        <button className="btn key-creation-button" title="Paste in a Private Key" onClick={this._onPastePrivButtonClick}>Paste in a Private Key</button>
        <button className="btn key-creation-button" title="Generate a New Keypair" onClick={this._onGenerateButtonClick}>Generate a New Keypair</button>
      </div>
    );
  }

  _onInnerGenerateButtonClick = () => {
    this._generateKeypair();
  };

  _generateKeypair() {
    this.setState({ placeholder: "Generating your key now..." });
    pgp.KeyManager.generate_rsa({ userid : this.state.address }, (err, km) => {
      km.sign({}, (err2) => {
        if (err2) {
          console.warn(err);
        }

        // todo: add passphrase input
        km.export_pgp_private({ passphrase: this.state.passphrase }, (err, pgp_private) => {
          // Remove trailing whitespace, if necessary.
          // if pgp_private.charAt(pgp_private.length - 1) != '-'
          //   pgp_private = pgp_private.slice(0, -1)
          PGPKeyStore.saveNewKey(this.state.address, pgp_private, false);
        });
        km.export_pgp_public({}, (err, pgp_public) => {
          // Remove trailing whitespace, if necessary.
          // if pgp_public.charAt(pgp_public.length - 1) != '-'
          //   pgp_public = pgp_public.slice(0, -1)
          PGPKeyStore.saveNewKey(this.state.address, pgp_public, isPub = true)
          this.setState({
            keyContents: pgp_public,
            placeholder: 'Your generated public key will appear here. Share it with your friends!',
          });
        });
      });
    });
  }

  _saveNewPubKey = () => {
    PGPKeyStore.saveNewKey(this.state.address, this.state.keyContents, true);
  };

  _saveNewPrivKey = () => {
    PGPKeyStore.saveNewKey(this.state.address, this.state.keyContents, false);
  };

  _onAddressChange = (event) => {
    const address = event.target.value;
    let valid = false;
    if (address && address.length > 0 && RegExpUtils.emailRegex().test(address)) {
      valid = true;
    }

    this.setState({
      address: event.target.value,
      validAddress: valid,
    });
  };

  _onPassphraseChange = (event) => {
    this.setState({
      passphrase: event.target.value,
    });
  };

  _onKeyChange = (event) => {
    this.setState({
      keyContents: event.target.value,
    });

    pgp.KeyManager.import_from_armored_pgp({
      armored: event.target.value,
    }, (err, km) => {
      if (err) {
        console.warn(err);
        valid = false;
      } else {
        valid = true;
      }
      this.setState({
        validKeyBody: valid,
      });
    });
  };

  _renderPasteKey() {
    let passphraseInput = null;
    let privateButton = null;
    let publicButton = null;

    const publicButtonDisabled = !this.state.validAddress || !this.state.validKeyBody;
    const privateButtonDisabled = !this.state.validAddress || !this.state.validKeyBody;

    if (this.state.privKey) {
      passphraseInput = (
        <input
          type="text"
          className="key-passphrase-input"
          placeholder="Input a password for the private key."
          value={this.state.passphrase}
          onChange={this._onPassphraseChange}
        />
      );

      privateButton = (
        <button
          className="btn key-add-btn"
          title="Save"
          disabled={privateButtonDisabled}
          onClick={this._saveNewPrivKey}
        >
          Save
        </button>
      );
    }

    if (this.state.pubKey) {
      publicButton = (
        <button
          className="btn key-add-btn"
          title="Save"
          disabled={publicButtonDisabled}
          onClick={this._saveNewPubKey}
        >
          Save
        </button>
      );
    }

    return (
      <div className="key-adder">
        <div className="key-text">
          <textarea
            ref="key-input"
            value={this.state.keyContents || ""}
            onChange={this._onKeyChange}
            placeholder="Paste in your PGP key here!"
          />
        </div>
        <div>
          <input
            type="text"
            className="key-email-input"
            value={this.state.address}
            placeholder="Which email address is this key for?"
            onChange={this._onAddressChange}
          />
          {passphraseInput}
          {privateButton}
          {publicButton}
        </div>
      </div>
    )
  }

  _renderGenerateKey() {
    return (
      <div className="key-adder">
        <div>
          <input
            type="text"
            className="key-email-input"
            placeholder="Which email address is this key for?"
            value={this.state.address}
            onChange={this._onAddressChange}
          />
          <input
            type="text"
            className="key-passphrase-input"
            placeholder="Input a password for the private key."
            value={this.state.passphrase}
            onChange={this._onPassphraseChange}
          />
          <button
            className="btn key-add-btn"
            title="Generate"
            disabled={!this.state.validAddress}
            onClick={this._onInnerGenerateButtonClick}
          >
            Generate
          </button>
        </div>
        <div className="key-text">
          <textarea
            ref="key-output"
            value={this.state.keyContents || ''}
            placeholder={this.state.placeholder}
            disabled
          />
        </div>
      </div>
    );
  }

  render() {
    return (
      <div>
        {this._renderAddButtons()}
        {this.state.generate && this._renderGenerateKey()}
        {(this.state.pubKey || this.state.privKey) && this._renderPasteKey()}
      </div>
    );
  }
}

export default KeyAdder;
