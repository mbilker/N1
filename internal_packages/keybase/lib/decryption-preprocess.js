/** @babel */

import { MessageViewExtension } from 'nylas-exports';

import PGPKeyStore from './pgp-key-store';

class DecryptPGPExtension extends MessageViewExtension {
  formatMessageBody({ message }) {
    if (!PGPKeyStore.hasEncryptedComponent(message)) {
      return;
    }

    if (PGPKeyStore.isDecrypted(message)) {
      message.body = PGPKeyStore.getDecrypted(message);
    } else {
      // trigger a decryption
      PGPKeyStore.decrypt(message);
    }
  }
}

export default DecryptPGPExtension;
