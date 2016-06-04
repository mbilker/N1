import Task from './task';
import {APIError} from '../errors';
import NylasAPI from '../nylas-api';
import {RegExpUtils} from 'nylas-exports';


export default class MultiSendToIndividualTask extends Task {
  constructor(opts = {}) {
    super(opts);
    this.message = opts.message;
    this.recipient = opts.recipient;
  }

  performRemote() {
    return NylasAPI.makeRequest({
      method: "POST",
      timeout: 1000 * 60 * 5, // We cannot hang up a send - won't know if it sent
      path: `/send-multiple/${this.message.id}`,
      accountId: this.message.accountId,
      body: {
        send_to: {
          email: this.recipient.email,
          name: this.recipient.name,
        },
        body: this._customizeTrackingForRecipient(this.message.body),
      },
    })
    .then(() => {
      return Promise.resolve(Task.Status.Success);
    })
    .catch((err) => {
      const errorMessage = `We had trouble sending this message to all recipients. ${this.recipient.displayName()} may not have received this email.\n\n${err.message}`;
      if (err instanceof APIError) {
        if (NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
          NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true});
          return Promise.resolve([Task.Status.Failed, err]);
        }
        return Promise.resolve(Task.Status.Retry);
      }
      NylasEnv.reportError(err);
      NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true});
      return Promise.resolve([Task.Status.Failed, err]);
    });
  }

  _customizeTrackingForRecipient(text) {
    const encodedEmail = btoa(this.recipient.email)
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
    let body = text.replace(/<img class="n1-open"[^<]+src="([a-zA-Z0-9-_:\/.]*)">/g, (match, url) => {
      return `<img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" src="${url}?r=${encodedEmail}">`;
    });
    body = body.replace(RegExpUtils.urlLinkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
      return `${prefix}${url}&r=${encodedEmail}${suffix}${content}${closingTag}`;
    });
    return body;
  }
}
