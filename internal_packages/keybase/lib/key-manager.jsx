/** @babel */

import { React } from 'nylas-exports';
import KeybaseUser from './keybase-user';
import PGPKeyStore from './pgp-key-store';
import _ from 'underscore';

class KeyManager extends React.Component {
  static displayName = 'KeyManager';

  static propTypes = {
    keys: React.PropTypes.array.isRequired,
  };

  _matchKeys = (targetIdentity, keys) => {
    // given a single key to match, and an array of keys to match from, returns
    // a key from the array with the same fingerprint as the target key, or null
    if (!targetIdentity.key) {
      return null;
    }

    const key = _.find(keys, (theKey) => {
      return theKey.key && theKey.fingerprint() === targetIdentity.fingerprint();
    });

    if (!key) {
      return null;
    } 

    return key;
  }

  _delete = (email, identity) => {
    // delete a locally saved key
    const keys = PGPKeyStore.pubKeys(email);
    const key = this._matchKeys(identity, keys);
    if (key) {
      PGPKeyStore.deleteKey(key);
    } else {
      console.error(`Unable to fetch key for ${email}`);
      NylasEnv.showErrorDialog(`Unable to fetch key for ${email}.`);
    }
  }

  render() {
    let { keys } = this.props;

    keys = keys.map((identity) => {
      const onClick = this._delete(identity.addresses[0], identity);
      const deleteButton = (
        <button title="Delete" className="btn btn-toolbar btn-danger" onClick={onClick} ref="button">
          Delete Key
        </button>
      )
      return <KeybaseUser profile={identity} key={identity.clientId} actionButton={deleteButton} />
    });

    if (keys.length < 1) {
      // keys = (<span>No keys saved!</span>)
      keys = null;
    }

    return (
      <div className="key-manager">
        {keys}
      </div>
    );
  }
}

export default KeyManager;
