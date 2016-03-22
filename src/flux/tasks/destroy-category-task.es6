import DatabaseStore from '../stores/database-store';
import AccountStore from '../stores/account-store';
import Task from './task';
import ChangeFolderTask from './change-folder-task';
import ChangeLabelTask from './change-labels-task';
import SyncbackCategoryTask from './syncback-category-task';
import NylasAPI from '../nylas-api';
import {APIError} from '../errors';

export default class DestroyCategoryTask extends Task {

  constructor({category} = {}) {
    super();
    this.category = category;
  }

  label() {
    return `Deleting ${this.category.displayType()} ${this.category.displayName}...`
  }

  isDependentOnTask(other) {
    return (other instanceof ChangeFolderTask) ||
           (other instanceof ChangeLabelTask) ||
           (other instanceof SyncbackCategoryTask)
  }

  performLocal() {
    if (!this.category) {
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performLocal without this.category."));
    }

    this.category.isDeleted = true;
    return DatabaseStore.inTransaction((t) =>
      t.persistModel(this.category)
    );
  }

  performRemote() {
    if (!this.category) {
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performRemote without this.category."));
    }
    if (!this.category.serverId) {
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performRemote without this.category.serverId."));
    }

    const {serverId, accountId} = this.category;
    const account = AccountStore.accountForId(accountId);
    const path = account.usesLabels() ? `/labels/${serverId}` : `/folders/${serverId}`;

    return NylasAPI.makeRequest({
      accountId,
      path,
      method: 'DELETE',
      returnsModel: false,
    })
    .thenReturn(Task.Status.Success)
    .catch(APIError, (err) => {
      if (!NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }

      // Revert isDeleted flag
      this.category.isDeleted = false;
      return DatabaseStore.inTransaction((t) =>
        t.persistModel(this.category)
      ).then(() => {
        NylasEnv.reportError(
          new Error(`Deleting category responded with ${err.statusCode}!`)
        );
        this._notifyUserOfError(this.category);
        return Promise.resolve(Task.Status.Failed);
      });
    })
  }

  _notifyUserOfError(category) {
    const displayName = category.displayName;
    const displayType = category.displayType();

    let msg = `The ${displayType} ${displayName} could not be deleted.`;
    if (displayType === 'folder') {
      msg += " Make sure the folder you want to delete is empty before deleting it.";
    }

    NylasEnv.showErrorDialog(msg);
  }
}
