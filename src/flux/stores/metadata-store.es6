import _ from 'underscore';
import NylasStore from 'nylas-store';
import Actions from '../actions';
import DatabaseStore from './database-store';
import SyncbackMetadataTask from '../tasks/syncback-metadata-task';

class MetadataStore extends NylasStore {

  constructor() {
    super();
    this.listenTo(Actions.setMetadata, this._setMetadata);
  }

  _setMetadata(modelOrModels, pluginId, metadataValue) {
    const models = (modelOrModels instanceof Array) ? modelOrModels : [modelOrModels];
    const modelClass = models[0].constructor
    if (!models.every(m => m.constructor === modelClass)) {
      throw new Error('Actions.setMetadata - All models provided must be of the same type')
    }
    DatabaseStore.inTransaction((t)=> {
      // Get the latest version of the models from the datbaase before applying
      // metadata in case other plugins also saved metadata, and we don't want
      // to overwrite it
      return (
        t.modelify(modelClass, _.pluck(models, 'clientId'))
        .then((latestModels)=> {
          const updatedModels = _.compact(latestModels).map(m => m.applyPluginMetadata(pluginId, metadataValue));
          return (
            t.persistModels(updatedModels)
            .then(()=> Promise.resolve(updatedModels))
          )
        })
      )
    }).then((updatedModels)=> {
      updatedModels.forEach((updated)=> {
        if (updated.isSavedRemotely()) {
          const task = new SyncbackMetadataTask(updated.clientId, updated.constructor.name, pluginId);
          Actions.queueTask(task);
        }
      })
    });
  }
}

module.exports = new MetadataStore();
