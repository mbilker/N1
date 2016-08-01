{DestroyCategoryTask,
 NylasAPI,
 Task,
 Category,
 AccountStore,
 APIError,
 Category,
 DatabaseStore,
 DatabaseTransaction} = require "nylas-exports"

describe "DestroyCategoryTask", ->
  pathOf = (fn) ->
    fn.calls[0].args[0].path

  methodOf = (fn) ->
    fn.calls[0].args[0].method

  accountIdOf = (fn) ->
    fn.calls[0].args[0].accountId

  nameOf = (fn) ->
    fn.calls[0].args[0].body.display_name

  makeAccount = ({usesFolders, usesLabels} = {}) ->
    spyOn(AccountStore, "accountForId").andReturn {
      usesFolders: -> usesFolders
      usesLabels: -> usesLabels
    }
  makeTask = ->
    category = new Category
      displayName: "important emails"
      accountId: "account 123"
      serverId: "server-444"
    new DestroyCategoryTask
      category: category

  beforeEach ->
    spyOn(DatabaseTransaction.prototype, 'unpersistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseTransaction.prototype, 'persistModel').andCallFake -> Promise.resolve()

  describe "performLocal", ->
    it "sets an `isDeleted` flag and persists the category", ->
      task = makeTask()
      runs =>
        task.performLocal()
      waitsFor =>
        DatabaseTransaction.prototype.unpersistModel.callCount > 0
      runs =>
        model = DatabaseTransaction.prototype.unpersistModel.calls[0].args[0]
        expect(model.serverId).toEqual "server-444"

  describe "performRemote", ->
    it "throws error when no category present", ->
      waitsForPromise ->
        task = makeTask()
        task.category = null
        task.performRemote()
        .then ->
          throw new Error('The promise should reject')
        .catch Error, (err) ->
          expect(err).toBeDefined()

    it "throws error when category does not have a serverId", ->
      waitsForPromise ->
        task = makeTask()
        task.category.serverId = undefined
        task.performRemote()
        .then ->
          throw new Error('The promise should reject')
        .catch Error, (err) ->
          expect(err).toBeDefined()

    describe "when request succeeds", ->
      beforeEach ->
        spyOn(NylasAPI, "makeRequest").andCallFake -> Promise.resolve("null")
        spyOn(NylasAPI, "incrementRemoteChangeLock")

      it "blocks other remote changes to that category", ->
        makeAccount()
        task = makeTask()
        task.performRemote()
        expect(NylasAPI.incrementRemoteChangeLock).toHaveBeenCalled()
      it "sends API req to /labels if user uses labels", ->
        makeAccount(usesLabels: true)
        task = makeTask()
        task.performRemote()
        expect(pathOf(NylasAPI.makeRequest)).toBe "/labels/server-444"

      it "sends API req to /folders if user uses folders", ->
        makeAccount(usesFolders: true)
        task = makeTask()
        task.performRemote()
        expect(pathOf(NylasAPI.makeRequest)).toBe "/folders/server-444"

      it "sends DELETE request", ->
        makeAccount()
        task = makeTask()
        task.performRemote()
        expect(methodOf(NylasAPI.makeRequest)).toBe "DELETE"

      it "sends the account id", ->
        makeAccount()
        task = makeTask()
        task.performRemote()
        expect(accountIdOf(NylasAPI.makeRequest)).toBe "account 123"

    describe "when request fails", ->
      beforeEach ->
        makeAccount()
        spyOn(NylasAPI, 'decrementRemoteChangeLock')
        spyOn(NylasEnv, 'reportError')
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          Promise.reject(new APIError({statusCode: 403}))

      it "persists the category and notifies error", ->
        waitsForPromise ->
          task = makeTask()
          spyOn(task, "_notifyUserOfError")

          task.performRemote().then (status) ->
            expect(status).toEqual Task.Status.Failed
            expect(task._notifyUserOfError).toHaveBeenCalled()
            expect(NylasEnv.reportError).toHaveBeenCalled()
            expect(DatabaseTransaction.prototype.persistModel).toHaveBeenCalled()
            model = DatabaseTransaction.prototype.persistModel.calls[0].args[0]
            expect(model.serverId).toEqual "server-444"
            expect(NylasAPI.decrementRemoteChangeLock).toHaveBeenCalled

      describe "_notifyUserOfError", ->
        it "should present an error dialog", ->
          spyOn(NylasEnv, 'showErrorDialog')
          task = makeTask()
          task._notifyUserOfError(task.category)
          expect(NylasEnv.showErrorDialog).toHaveBeenCalled()
