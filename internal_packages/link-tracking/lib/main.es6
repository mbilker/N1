import {ComponentRegistry, DatabaseStore, Message, ExtensionRegistry, Actions} from 'nylas-exports';
import LinkTrackingButton from './link-tracking-button';
import LinkTrackingIcon from './link-tracking-icon';
import LinkTrackingComposerExtension from './link-tracking-composer-extension';
import LinkTrackingPanel from './link-tracking-panel';
import plugin from '../package.json'

import request from 'request';

const post = Promise.promisify(request.post, {multiArgs: true});
const PLUGIN_ID = plugin.appId;
const PLUGIN_URL = "n1-link-tracking.herokuapp.com";

function afterDraftSend({draftClientId}) {
  // only run this handler in the main window
  if (!NylasEnv.isMainWindow()) return;

  // query for the message
  DatabaseStore.findBy(Message, {clientId: draftClientId}).then((message) => {
    // grab message metadata, if any
    const metadata = message.metadataForPluginId(PLUGIN_ID);
    // get the uid from the metadata, if present
    if (metadata) {
      const uid = metadata.uid;

      // post the uid and message id pair to the plugin server
      const data = {uid: uid, message_id: message.id};
      const serverUrl = `http://${PLUGIN_URL}/register-message`;
      return post({
        url: serverUrl,
        body: JSON.stringify(data),
      }).then( ([response, responseBody]) => {
        if (response.statusCode !== 200) {
          throw new Error();
        }
        return responseBody;
      }).catch(error => {
        NylasEnv.showErrorDialog("There was a problem contacting the Link Tracking server! This message will not have link tracking");
        Promise.reject(error);
      });
    }
  });
}

export function activate() {
  ComponentRegistry.register(LinkTrackingButton, {role: 'Composer:ActionButton'});
  ComponentRegistry.register(LinkTrackingIcon, {role: 'ThreadListIcon'});
  ComponentRegistry.register(LinkTrackingPanel, {role: 'message:BodyHeader'});
  ExtensionRegistry.Composer.register(LinkTrackingComposerExtension);
  this._unlistenSendDraftSuccess = Actions.sendDraftSuccess.listen(afterDraftSend);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(LinkTrackingButton);
  ComponentRegistry.unregister(LinkTrackingIcon);
  ComponentRegistry.unregister(LinkTrackingPanel);
  ExtensionRegistry.Composer.unregister(LinkTrackingComposerExtension);
  this._unlistenSendDraftSuccess()
}
