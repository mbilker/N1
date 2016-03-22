/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Task from './task';
import Thread from '../models/thread';
import Message from '../models/message';
import NylasAPI from '../nylas-api';
import DatabaseStore from '../stores/database-store';
import {APIError} from '../errors';

// MapLimit is a small helper method that implements a promise version of
// Async.mapLimit. It runs the provided fn on each item in the `input` array,
// but only runs `numberInParallel` copies of `fn` at a time, resolving
// with an output array, or rejecting with an error if (any execution of)
// `fn` returns an error.
const mapLimit = (input, numberInParallel, fn) => {
  return new Promise((resolve, reject) => {
    let idx = 0;
    let inflight = 0;
    const output = [];
    let outputError = null;

    if (input.length === 0) {
      return resolve([]);
    }

    const startNext = () => {
      const startIdx = idx;
      idx += 1;
      inflight += 1;
      fn(input[startIdx]).then((result) => {
        output[startIdx] = result;
        if (outputError) {
          return;
        }

        inflight -= 1;
        if (idx < input.length) {
          startNext();
        } else if (inflight === 0) {
          resolve(output);
        }
      }).catch((err) => {
        outputError = err;
        reject(outputError);
      });
    };

    for (let i = 0; i < Math.min(numberInParallel, input.length); i ++) {
      startNext();
    }
  });
}

/*
Public: The ChangeMailTask is a base class for all tasks that modify sets
of threads or messages.

Subclasses implement {ChangeMailTask::changesToModel} and
{ChangeMailTask::requestBodyForModel} to define the specific transforms
they provide, and override {ChangeMailTask::performLocal} to perform
additional consistency checks.

ChangeMailTask aims to be fast and efficient. It does not write changes to
the database or make API requests for models that are unmodified by
{ChangeMailTask::changesToModel}

ChangeMailTask stores the previous values of all models it changes into
this._restoreValues and handles undo/redo. When undoing, it restores previous
values and calls {ChangeMailTask::requestBodyForModel} to make undo API
requests. It does not call {ChangeMailTask::changesToModel}.
*/
export default class ChangeMailTask extends Task {

  constructor({threads, thread, messages, message} = {}) {
    super();

    this.threads = threads || [];
    if (thread) {
      this.threads.push(thread);
    }
    this.messages = messages || [];
    if (message) {
      this.messages.push(message);
    }
  }

  // Functions for subclasses

  // Public: Override this method and return an object with key-value pairs
  // representing changed values. For example, if (your task sets unread:)
  // false, return {unread: false}.
  //
  // - `model` an individual {Thread} or {Message}
  //
  // Returns an object whos key-value pairs represent the desired changed
  // object.
  changesToModel(model) {
    throw new Error("You must override this method.");
  }

  // Public: Override this method and return an object that will be the
  // request body used for saving changes to `model`.
  //
  // - `model` an individual {Thread} or {Message}
  //
  // Returns an object that will be passed as the `body` to the actual API
  // `request` object
  requestBodyForModel(model) {
    throw new Error("You must override this method.");
  }

  // Public: Override to indicate whether actions need to be taken for all
  // messages of each thread.
  //
  // Generally, you cannot provide both messages and threads at the same
  // time. However, ChangeMailTask runs for provided threads first and then
  // messages. Override and return true, and you will receive
  // `changesToModel` for messages in changed threads, and any changes you
  // make will be written to the database and undone during undo.
  //
  // Note that API requests are only made for threads if (threads are)
  // present.
  processNestedMessages() {
    return false;
  }

  // Public: Returns categories that this task will add to the set of threads
  // Must be overriden
  categoriesToAdd() {
    return [];
  }

  // Public: Returns categories that this task will remove the set of threads
  // Must be overriden
  categoriesToRemove() {
    return [];
  }

  // Public: Subclasses should override `performLocal` and call super once
  // they've prepared the data they need and verified that requirements are
  // met.

  // See {Task::performLocal} for more usage info

  // Note: Currently, *ALL* subclasses must use `DatabaseStore.modelify`
  // to convert `threads` and `messages` from models or ids to models.
  performLocal() {
    if (this._isUndoTask && !this._restoreValues) {
      return Promise.reject(new Error("ChangeMailTask: No _restoreValues provided for undo task."))
    }
    // Lock the models with the optimistic change tracker so they aren't reverted
    // while the user is seeing our optimistic changes.
    if (!this._isReverting) {
      this._lockAll();
    }

    return this._performLocalThreads().then(() =>
      this._performLocalMessages()
    );
  }

  _performLocalThreads() {
    const changed = this._applyChanges(this.threads);
    const changedIds = _.pluck(changed, 'id');

    if (changed.length === 0) {
      return Promise.resolve();
    }

    return DatabaseStore.inTransaction((t) =>
      t.persistModels(changed)
    ).then(() => {
      if (!this.processNestedMessages()) {
        return Promise.resolve();
      }
      return DatabaseStore.findAll(Message).where(Message.attributes.threadId.in(changedIds)).then((messages) => {
        this.messages = [].concat(messages, this.messages);
        return Promise.resolve()
      })
    });
  }

  _performLocalMessages() {
    const changed = this._applyChanges(this.messages);

    if (changed.length === 0) {
      return Promise.resolve();
    }

    return DatabaseStore.inTransaction((t) =>
      t.persistModels(changed)
    );
  }

  _applyChanges(modelArray) {
    const changed = [];

    if (this._shouldChangeBackwards()) {
      modelArray.forEach((model, idx) => {
        if (this._restoreValues[model.id]) {
          const updated = _.extend(model.clone(), this._restoreValues[model.id]);
          modelArray[idx] = updated;
          changed.push(updated);
        }
      });
    } else {
      this._restoreValues = this._restoreValues || {};
      modelArray.forEach((model, idx) => {
        const fieldsNew = this.changesToModel(model);
        const fieldsCurrent = _.pick(model, Object.keys(fieldsNew));
        if (!_.isEqual(fieldsCurrent, fieldsNew)) {
          this._restoreValues[model.id] = fieldsCurrent;
          const updated = _.extend(model.clone(), fieldsNew);
          modelArray[idx] = updated;
          changed.push(updated);
        }
      });
    }

    return changed;
  }

  _shouldChangeBackwards() {
    return this._isReverting || this._isUndoTask;
  }

  performRemote() {
    return this._performRequests(this.objectClass(), this.objectArray()).then(() => {
      this._ensureLocksRemoved();
      return Promise.resolve(Task.Status.Success);
    })
    .catch(APIError, (err) => {
      if (!NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }
      this._isReverting = true;
      return this.performLocal().then(() => {
        this._ensureLocksRemoved();
        return Promise.resolve([Task.Status.Failed, err]);
      });
    });
  }

  _performRequests(klass, models) {
    return mapLimit(models, 5, (model) => {
      // Don't bother making a web request if (performLocal didn't modify this model)
      if (!this._restoreValues[model.id]) {
        return Promise.resolve();
      }

      const endpoint = (klass === Thread) ? 'threads' : 'messages';

      return NylasAPI.makeRequest({
        path: `/${endpoint}/${model.id}`,
        accountId: model.accountId,
        method: 'PUT',
        body: this.requestBodyForModel(model),
        returnsModel: true,
        beforeProcessing: (body) => {
          this._removeLock(model);
          return body;
        },
      })
      .catch((err) => {
        if (err instanceof APIError && err.statusCode === 404) {
          return Promise.resolve();
        }
        return Promise.reject(err);
      })
    });
  }

  // Task lifecycle

  canBeUndone() {
    return true;
  }

  isUndo() {
    return this._isUndoTask === true;
  }

  createUndoTask() {
    if (this._isUndoTask) {
      throw new Error("ChangeMailTask::createUndoTask Cannot create an undo task from an undo task.");
    }
    if (!this._restoreValues) {
      throw new Error("ChangeMailTask::createUndoTask Cannot undo a task which has not finished performLocal yet.");
    }

    const task = this.createIdenticalTask();
    task._restoreValues = this._restoreValues;
    task._isUndoTask = true;
    return task;
  }

  createIdenticalTask() {
    const task = new this.constructor(this);

    // Never give the undo task the Model objects - make it look them up!
    // This ensures that they never revert other fields
    const toIds = (arr) => _.map(arr, v => _.isString(v) ? v : v.id);
    task.threads = toIds(this.threads);
    task.messages = (this.threads.length > 0) ? [] : toIds(this.messages);
    return task;
  }

  objectIds() {
    return [].concat(this.threads, this.messages).map((v) =>
      _.isString(v) ? v : v.id
    );
  }

  objectClass() {
    return (this.threads && this.threads.length) ? Thread : Message;
  }

  objectArray() {
    return (this.threads && this.threads.length) ? this.threads : this.messages;
  }

  numberOfImpactedItems() {
    return this.objectArray().length;
  }

  // To ensure that complex offline actions are synced correctly, label/folder additions
  // and removals need to be applied in order. (For example, star many threads,
  // and then unstar one.)
  isDependentOnTask(other) {
    // Only wait on other tasks that are older and also involve the same threads
    if (!(other instanceof ChangeMailTask)) {
      return false;
    }
    const otherOlder = other.sequentialId < this.sequentialId;
    const otherSameObjs = _.intersection(other.objectIds(), this.objectIds()).length > 0;
    return otherOlder && otherSameObjs;
  }

  // Helpers used in subclasses

  _lockAll() {
    const klass = this.objectClass();
    this._locked = this._locked || {};
    for (const item of this.objectArray()) {
      this._locked[item.id] = this._locked[item.id] || 0;
      this._locked[item.id] += 1;
      NylasAPI.incrementRemoteChangeLock(klass, item.id);
    }
  }

  _removeLock(item) {
    const klass = this.objectClass();
    NylasAPI.decrementRemoteChangeLock(klass, item.id);
    this._locked[item.id] -= 1;
  }

  _ensureLocksRemoved() {
    const klass = this.objectClass()
    if (!this._locked) {
      return;
    }

    for (const id of Object.keys(this._locked)) {
      let count = this._locked[id];
      while (count > 0) {
        NylasAPI.decrementRemoteChangeLock(klass, id);
        count -= 1;
      }
    }
    this._locked = null;
  }
}
