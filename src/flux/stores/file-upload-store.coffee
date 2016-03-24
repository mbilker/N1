_ = require 'underscore'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
NylasStore = require 'nylas-store'
Actions = require '../actions'
Utils = require '../models/utils'
Message = require '../models/message'
DraftStore = require './draft-store'
DatabaseStore = require './database-store'

Promise.promisifyAll(fs)
mkdirpAsync = Promise.promisify(mkdirp)

UPLOAD_DIR = path.join(NylasEnv.getConfigDirPath(), 'uploads')

class Upload

  constructor: (@messageClientId, @originPath, @stats, @id, @uploadDir = UPLOAD_DIR) ->
    @id ?= Utils.generateTempId()
    @filename = path.basename(@originPath)
    @targetDir = path.join(@uploadDir, @messageClientId, @id)
    @targetPath = path.join(@targetDir, @filename)
    @size = @stats.size


class FileUploadStore extends NylasStore

  Upload: Upload

  constructor: ->
    @listenTo Actions.addAttachment, @_onAddAttachment
    @listenTo Actions.selectAttachment, @_onSelectAttachment
    @listenTo Actions.removeAttachment, @_onRemoveAttachment
    @listenTo DatabaseStore, @_onDataChanged

    mkdirp.sync(UPLOAD_DIR)
    if NylasEnv.isMainWindow() or NylasEnv.inSpecMode()
      @listenTo Actions.sendDraftSuccess, ({messageClientId}) =>
        @_deleteUploadsForClientId(messageClientId)

  # Handlers

  _onDataChanged: (change) =>
    return unless NylasEnv.isMainWindow()
    return unless change.objectClass is Message.name and change.type is 'unpersist'

    change.objects.forEach (message) =>
      @_deleteUploadsForClientId(message.clientId)

  _onSelectAttachment: ({messageClientId}) ->
    @_verifyId(messageClientId)

    # When the dialog closes, it triggers `Actions.addAttachment`
    NylasEnv.showOpenDialog {properties: ['openFile', 'multiSelections']}, (pathsToOpen) ->
      return unless pathsToOpen?
      pathsToOpen = [pathsToOpen] if _.isString(pathsToOpen)

      pathsToOpen.forEach (filePath) ->
        Actions.addAttachment({messageClientId, filePath})

  _onAddAttachment: ({messageClientId, filePath}) ->
    @_verifyId(messageClientId)
    @_getFileStats({messageClientId, filePath})
    .then(@_makeUpload)
    .then(@_verifyUpload)
    .then(@_prepareTargetDir)
    .then(@_copyUpload)
    .then (upload) =>
      @_applySessionChanges upload.messageClientId, (uploads) ->
        uploads.concat([upload])
    .catch(@_onAttachFileError)

  _onRemoveAttachment: (upload) ->
    return Promise.resolve() unless upload
    @_applySessionChanges upload.messageClientId, (uploads) ->
      _.reject(uploads, _.matcher({id: upload.id}))
    @_deleteUpload(upload)
    .catch(@_onAttachFileError)

  _onAttachFileError: (error) ->
    NylasEnv.showErrorDialog(error.message)

  # Helpers

  _verifyId: (messageClientId) ->
    unless messageClientId
      throw new Error "You need to pass the ID of the message (draft) this Action refers to"

  _getFileStats: ({messageClientId, filePath}) ->
    fs.statAsync(filePath).then (stats) =>
      Promise.resolve({messageClientId, filePath, stats})
    .catch (err) ->
      Promise.reject(new Error("#{filePath} could not be found, or has invalid file permissions."))

  _makeUpload: ({messageClientId, filePath, stats}) ->
    Promise.resolve(new Upload(messageClientId, filePath, stats))

  _verifyUpload: (upload) ->
    {filename, stats} = upload
    if stats.isDirectory()
      Promise.reject(new Error("#{filename} is a directory. Try compressing it and attaching it again."))
    else if stats.size > 25 * 1000000
      Promise.reject(new Error("#{filename} cannot be attached because it is larger than 25MB."))
    else
      Promise.resolve(upload)

  _prepareTargetDir: (upload) =>
    mkdirpAsync(upload.targetDir).thenReturn(upload)

  _copyUpload: (upload) ->
    return new Promise (resolve, reject) =>
      {originPath, targetPath} = upload
      readStream = fs.createReadStream(originPath)
      writeStream = fs.createWriteStream(targetPath)

      readStream.on 'error', ->
        reject(new Error("Could not read file at path: #{originPath}"))
      writeStream.on 'error', ->
        reject(new Error("Could not write #{upload.filename} to uploads directory."))
      readStream.on 'end', ->
        resolve(upload)
      readStream.pipe(writeStream)

  _deleteUpload: (upload) =>
    # Delete the upload file
    fs.unlinkAsync(upload.targetPath).then ->
      # Delete the containing folder
      fs.rmdirAsync(upload.targetDir).then ->
        # Try to remove the directory for the associated message if this was the
        # last upload
        fs.rmdir path.join(UPLOAD_DIR, upload.messageClientId), (err) ->
          # Will fail if it's not empty, which is fine.
        Promise.resolve(upload)
    .catch (err) ->
      Promise.reject(new Error("Error deleting file upload #{upload.filename}:\n\n#{err.message}"))

  _deleteUploadsForClientId: (messageClientId) =>
    rimraf = require('rimraf')
    rimraf path.join(UPLOAD_DIR, messageClientId), {disableGlob: true}, (err) =>
      console.warn(err) if err

  _applySessionChanges: (messageClientId, changeFunction) =>
    DraftStore.sessionForClientId(messageClientId).then (session) =>
      uploads = changeFunction(session.draft().uploads)
      session.changes.add({uploads})

      # In some scenarios (like dropping attachments on the dock icon), files
      # are added to drafts which may be open in another composer window.
      # Committing here ensures the files appear immediately, no matter where the
      # user is now viewing the draft.
      session.changes.commit()

module.exports = new FileUploadStore()
