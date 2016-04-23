/** @babel */

import { Utils, React } from 'nylas-exports';
import PGPKeyStore from './pgp-key-store';
import KeybaseUser from './keybase-user';
import kb from './keybase';
import _ from 'underscore';

class KeyManager extends React.Component {
  static displayName = 'KeyManager';

  static propTypes = {
    keys: React.PropTypes.array.isRequired,
  };

  render() {
    let { keys } = this.props;

    keys = keys.map((key) => {
      let uid = null;

      if (key.key) {
        uid = "key-manager-" + key.key.get_pgp_fingerprint().toString('hex');
      } else if (key.keybase_user) {
        uid = "key-manager-" + key.keybase_user.components.username.val;
      } else {
        uid = "key-manager-" + key.addresses.join('');
      }

      return (
        <KeybaseUser profile={key} key={uid} />
      );
    });

    if (keys.length < 1) {
      keys = (
        <span>No keys saved!</span>
      );
    }

    return (
      <div className="key-manager">
        {keys}
      </div>
    );
  }
}

export default KeyManager;
