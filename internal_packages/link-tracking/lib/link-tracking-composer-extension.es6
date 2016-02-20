import {ComposerExtension, Actions, QuotedHTMLTransformer} from 'nylas-exports';
import plugin from '../package.json'

import uuid from 'node-uuid';

const LINK_REGEX = (/(<a\s.*?href\s*?=\s*?")([^"]*)("[^>]*>)|(<a\s.*?href\s*?=\s*?')([^']*)('[^>]*>)/g);
const PLUGIN_ID = plugin.appId;
const PLUGIN_URL = "n1-link-tracking.herokuapp.com";

class DraftBody {
  constructor(draft) {this._body = draft.body}
  get unquoted() {return QuotedHTMLTransformer.removeQuotedHTML(this._body);}
  set unquoted(text) {this._body = QuotedHTMLTransformer.appendQuotedHTML(text, this._body);}
  get body() {return this._body}
}

export default class LinkTrackingComposerExtension extends ComposerExtension {
  static finalizeSessionBeforeSending({session}) {
    const draft = session.draft();

    // grab message metadata, if any
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      const draftBody = new DraftBody(draft);
      const links = [];
      const messageUid = uuid.v4().replace(/-/g, "");

      // loop through all <a href> elements, replace with redirect links and save mappings
      draftBody.unquoted = draftBody.unquoted.replace(LINK_REGEX, (match, prefix, url, suffix) => {
        const encoded = encodeURIComponent(url);
        const redirectUrl = `http://${PLUGIN_URL}/${draft.accountId}/${messageUid}/${links.length}?redirect=${encoded}`;
        links.push({url: url, click_count: 0, click_data: []});
        return prefix + redirectUrl + suffix;
      });

      // save the draft
      session.changes.add({body: draftBody.body});
      session.changes.commit();

      // save the link info to draft metadata
      metadata.uid = messageUid;
      metadata.links = links;
      Actions.setMetadata(draft, PLUGIN_ID, metadata);
    }
  }
}
