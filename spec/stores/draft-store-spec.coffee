{File,
 Utils,
 Thread,
 Actions,
 Contact,
 Message,
 Account,
 DraftStore,
 AccountStore,
 DatabaseStore,
 SoundRegistry,
 SendDraftTask,
 ChangeMailTask,
 DestroyDraftTask,
 ComposerExtension,
 ExtensionRegistry,
 FocusedContentStore,
 DatabaseTransaction,
 SanitizeTransformer,
 SyncbackDraftFilesTask,
 InlineStyleTransformer} = require 'nylas-exports'

ModelQuery = require '../../src/flux/models/query'

_ = require 'underscore'
{ipcRenderer} = require 'electron'

msgFromMe = null
fakeThread = null
fakeMessages = null
fakeMessage1 = null
fakeMessage2 = null
msgWithReplyTo = null
messageWithStyleTags = null
fakeMessageWithFiles = null
msgWithReplyToDuplicates = null
account = null

class TestExtension extends ComposerExtension
  @prepareNewDraft: ({draft}) ->
    draft.body = "Edited by TestExtension!" + draft.body

describe "DraftStore", ->
  beforeEach ->
    spyOn(NylasEnv, 'newWindow').andCallFake ->
    for id, session of DraftStore._draftSessions
      if session.teardown
        DraftStore._doneWithSession(session)
    DraftStore._draftSessions = {}

  describe "creating drafts", ->
    beforeEach ->
      spyOn(DraftStore, "_prepareBodyForQuoting").andCallFake (body) ->
        Promise.resolve(body)
      spyOn(ipcRenderer, "send").andCallFake (message, body) ->
        if message is "inline-style-parse"
          # There needs to be a defer block in here so the promise
          # responsible for handling the `inline-style-parse` can be
          # properly set. If the whole path is synchronous instead of
          # asynchrounous, the promise is not cleared properly. Doing this
          # requires us to add `advanceClock` blocks.
          _.defer -> DraftStore._onInlineStylesResult({}, body)

      account = AccountStore.accounts()[0]

      fakeThread = new Thread
        id: 'fake-thread-id'
        accountId: account.id
        subject: 'Fake Subject'

      fakeMessage1 = new Message
        id: 'fake-message-1'
        accountId: account.id
        to: [new Contact(email: 'ben@nylas.com'), new Contact(email: 'evan@nylas.com')]
        cc: [new Contact(email: 'mg@nylas.com'), account.me()]
        bcc: [new Contact(email: 'recruiting@nylas.com')]
        from: [new Contact(email: 'customer@example.com', name: 'Customer')]
        threadId: 'fake-thread-id'
        body: 'Fake Message 1'
        subject: 'Fake Subject'
        date: new Date(1415814587)

      fakeMessage2 = new Message
        id: 'fake-message-2'
        accountId: account.id
        to: [new Contact(email: 'customer@example.com')]
        from: [new Contact(email: 'ben@nylas.com')]
        threadId: 'fake-thread-id'
        body: 'Fake Message 2'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      fakeMessageWithFiles = new Message
        id: 'fake-message-with-files'
        accountId: account.id
        to: [new Contact(email: 'ben@nylas.com'), new Contact(email: 'evan@nylas.com')]
        cc: [new Contact(email: 'mg@nylas.com'), account.me()]
        bcc: [new Contact(email: 'recruiting@nylas.com')]
        from: [new Contact(email: 'customer@example.com', name: 'Customer')]
        files: [new File(filename: "test.jpg"), new File(filename: "test.pdj")]
        threadId: 'fake-thread-id'
        body: 'Fake Message 1'
        subject: 'Fake Subject'
        date: new Date(1415814587)

      msgFromMe = new Message
        id: 'fake-message-3'
        accountId: account.id
        to: [new Contact(email: '1@1.com'), new Contact(email: '2@2.com')]
        cc: [new Contact(email: '3@3.com'), new Contact(email: '4@4.com')]
        bcc: [new Contact(email: '5@5.com'), new Contact(email: '6@6.com')]
        from: [account.me()]
        threadId: 'fake-thread-id'
        body: 'Fake Message 2'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      msgWithReplyTo = new Message
        id: 'fake-message-reply-to'
        accountId: account.id
        to: [new Contact(email: '1@1.com'), new Contact(email: '2@2.com')]
        cc: [new Contact(email: '3@3.com'), new Contact(email: '4@4.com')]
        bcc: [new Contact(email: '5@5.com'), new Contact(email: '6@6.com')]
        replyTo: [new Contact(email: 'reply-to@5.com'), new Contact(email: 'reply-to@6.com')]
        from: [new Contact(email: 'from@5.com')]
        threadId: 'fake-thread-id'
        body: 'Fake Message 2'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      msgWithReplyToDuplicates = new Message
        id: 'fake-message-reply-to-duplicates'
        accountId: account.id
        to: [new Contact(email: '1@1.com'), new Contact(email: '2@2.com')]
        cc: [new Contact(email: '1@1.com'), new Contact(email: '4@4.com')]
        from: [new Contact(email: 'reply-to@5.com')]
        replyTo: [new Contact(email: 'reply-to@5.com')]
        threadId: 'fake-thread-id'
        body: 'Fake Message Duplicates'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      messageWithStyleTags = new Message
        id: 'message-with-style-tags'
        accountId: account.id
        to: [new Contact(email: 'ben@nylas.com'), new Contact(email: 'evan@nylas.com')]
        cc: [new Contact(email: 'mg@nylas.com'), account.me()]
        bcc: [new Contact(email: 'recruiting@nylas.com')]
        from: [new Contact(email: 'customer@example.com', name: 'Customer')]
        threadId: 'fake-thread-id'
        body: '<style>div {color: red;}</style><div>Fake Message 1</div>'
        subject: 'Fake Subject'
        date: new Date(1415814587)

      fakeMessages =
        'fake-message-1': fakeMessage1
        'fake-message-3': msgFromMe
        'fake-message-2': fakeMessage2
        'fake-message-reply-to': msgWithReplyTo
        'fake-message-with-files': fakeMessageWithFiles
        'fake-message-reply-to-duplicates': msgWithReplyToDuplicates
        'message-with-style-tags': messageWithStyleTags

      spyOn(DatabaseStore, 'find').andCallFake (klass, id) ->
        query = new ModelQuery(klass, {id})
        spyOn(query, 'then').andCallFake (fn) ->
          return fn(fakeThread) if klass is Thread
          return fn(fakeMessages[id]) if klass is Message
          return fn(new Error('Not Stubbed'))
        query

      spyOn(DatabaseStore, 'run').andCallFake (query) ->
        return Promise.resolve(fakeMessage2) if query._klass is Message
        return Promise.reject(new Error('Not Stubbed'))

      spyOn(DatabaseTransaction.prototype, 'persistModel').andCallFake -> Promise.resolve()

    afterEach ->
      # Have to cleanup the DraftStoreProxy objects or we'll get a memory
      # leak error
      for id, session of DraftStore._draftSessions
        DraftStore._doneWithSession(session)

    describe "onComposeReply", ->
      beforeEach ->
        runs ->
          DraftStore._onComposeReply({threadId: fakeThread.id, messageId: fakeMessage1.id})
        waitsFor ->
          DatabaseTransaction.prototype.persistModel.callCount > 0
        runs ->
          @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]

      it "should include quoted text", ->
        expect(@model.body.indexOf('blockquote') > 0).toBe(true)
        expect(@model.body.indexOf(fakeMessage1.body) > 0).toBe(true)

      it "should address the message to the previous message's sender", ->
        expect(@model.to).toEqual(fakeMessage1.from)

      it "should set the replyToMessageId to the previous message's ids", ->
        expect(@model.replyToMessageId).toEqual(fakeMessage1.id)

      it "should sanitize the HTML", ->
        expect(DraftStore._prepareBodyForQuoting).toHaveBeenCalled()

    describe "onComposeReply", ->
      describe "when the message provided as context has one or more 'ReplyTo' recipients", ->
        it "addresses the draft to all of the message's 'ReplyTo' recipients", ->
          runs ->
            DraftStore._onComposeReply({threadId: fakeThread.id, messageId: msgWithReplyTo.id})
          waitsFor ->
            DatabaseTransaction.prototype.persistModel.callCount > 0
          runs ->
            @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
            expect(@model.to).toEqual(msgWithReplyTo.replyTo)
            expect(@model.cc.length).toBe 0
            expect(@model.bcc.length).toBe 0

    describe "onComposeReply", ->
      describe "when the message provided as context was sent by the current user", ->
        it "addresses the draft to all of the last messages's 'To' recipients", ->
          runs ->
            DraftStore._onComposeReply({threadId: fakeThread.id, messageId: msgFromMe.id})
          waitsFor ->
            DatabaseTransaction.prototype.persistModel.callCount > 0
          runs ->
            @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
            expect(@model.to).toEqual(msgFromMe.to)
            expect(@model.cc.length).toBe 0
            expect(@model.bcc.length).toBe 0

    describe "onComposeReplyAll", ->
      beforeEach ->
        runs ->
          DraftStore._onComposeReplyAll({threadId: fakeThread.id, messageId: fakeMessage1.id})
        waitsFor ->
          DatabaseTransaction.prototype.persistModel.callCount > 0
        runs ->
          @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]

      it "should include quoted text", ->
        expect(@model.body.indexOf('blockquote') > 0).toBe(true)
        expect(@model.body.indexOf(fakeMessage1.body) > 0).toBe(true)

      it "should address the message to the previous message's sender", ->
        expect(@model.to).toEqual(fakeMessage1.from)

      it "should cc everyone who was on the previous message in to or cc", ->
        ccEmails = @model.cc.map (cc) -> cc.email
        expect(ccEmails.sort()).toEqual([ 'ben@nylas.com', 'evan@nylas.com', 'mg@nylas.com'])

      it "should not include people who were bcc'd on the previous message", ->
        expect(@model.bcc).toEqual([])
        expect(@model.cc.indexOf(fakeMessage1.bcc[0])).toEqual(-1)

      it "should not include you when you were cc'd on the previous message", ->
        ccEmails = @model.cc.map (cc) -> cc.email
        expect(ccEmails.indexOf(account.me().email)).toEqual(-1)

      it "should set the replyToMessageId to the previous message's ids", ->
        expect(@model.replyToMessageId).toEqual(fakeMessage1.id)

      it "should sanitize the HTML", ->
        expect(DraftStore._prepareBodyForQuoting).toHaveBeenCalled()

    describe "onComposeReplyAll", ->
      describe "when the message provided as context has one or more 'ReplyTo' recipients", ->
        beforeEach ->
          runs ->
            DraftStore._onComposeReply({threadId: fakeThread.id, messageId: msgWithReplyTo.id})
          waitsFor ->
            DatabaseTransaction.prototype.persistModel.callCount > 0
          runs ->
            @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]

        it "addresses the draft to all of the message's 'ReplyTo' recipients", ->
          expect(@model.to).toEqual(msgWithReplyTo.replyTo)

        it "should not include the message's 'From' recipient in any field", ->
          all = [].concat(@model.to, @model.cc, @model.bcc)
          match = _.find all, (c) -> c.email is msgWithReplyTo.from[0].email
          expect(match).toEqual(undefined)

    describe "onComposeReplyAll", ->
      describe "when the message provided has one or more 'ReplyTo' recipients and duplicates in the To/Cc fields", ->
        it "should unique the to/cc fields", ->
          runs ->
            DraftStore._onComposeReplyAll({threadId: fakeThread.id, messageId: msgWithReplyToDuplicates.id})
          waitsFor ->
            DatabaseTransaction.prototype.persistModel.callCount > 0
          runs ->
            model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
            ccEmails = model.cc.map (cc) -> cc.email
            expect(ccEmails.sort()).toEqual(['1@1.com', '2@2.com', '4@4.com'])
            toEmails = model.to.map (to) -> to.email
            expect(toEmails.sort()).toEqual(['reply-to@5.com'])

    describe "onComposeReplyAll", ->
      describe "when the message provided as context was sent by the current user", ->
        it "addresses the draft to all of the last messages's recipients", ->
          runs ->
            DraftStore._onComposeReplyAll({threadId: fakeThread.id, messageId: msgFromMe.id})
          waitsFor ->
            DatabaseTransaction.prototype.persistModel.callCount > 0
          runs ->
            @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
            expect(@model.to).toEqual(msgFromMe.to)
            expect(@model.cc).toEqual(msgFromMe.cc)
            expect(@model.bcc.length).toBe 0

    describe "forwarding with attachments", ->
      it "should include the attached files", ->
        runs ->
          DraftStore._onComposeForward({threadId: fakeThread.id, messageId: fakeMessageWithFiles.id})
        waitsFor ->
          DatabaseTransaction.prototype.persistModel.callCount > 0
        runs ->
          @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
          expect(@model.files.length).toBe 2
          expect(@model.files[0].filename).toBe "test.jpg"

    describe "onComposeForward", ->
      beforeEach ->
        runs ->
          DraftStore._onComposeForward({threadId: fakeThread.id, messageId: fakeMessage1.id})
        waitsFor ->
          DatabaseTransaction.prototype.persistModel.callCount > 0
        runs ->
          @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]

      it "should include quoted text, but in a div rather than a blockquote", ->
        expect(@model.body.indexOf('gmail_quote') > 0).toBe(true)
        expect(@model.body.indexOf('blockquote') > 0).toBe(false)
        expect(@model.body.indexOf(fakeMessage1.body) > 0).toBe(true)

      it "should not address the message to anyone", ->
        expect(@model.to).toEqual([])
        expect(@model.cc).toEqual([])
        expect(@model.bcc).toEqual([])

      it "should not set the replyToMessageId", ->
        expect(@model.replyToMessageId).toEqual(undefined)

      it "should sanitize the HTML", ->
        expect(DraftStore._prepareBodyForQuoting).toHaveBeenCalled()

    describe "popout drafts", ->
      beforeEach ->
        spyOn(Actions, "composePopoutDraft")

      it "can popout a reply", ->
        runs ->
          DraftStore._onComposeReply({threadId: fakeThread.id, messageId: fakeMessage1.id, popout: true}).catch (error) -> throw new Error (error)
        waitsFor ->
          DatabaseTransaction.prototype.persistModel.callCount > 0
        runs ->
          @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
          expect(Actions.composePopoutDraft).toHaveBeenCalledWith(@model.clientId)

      it "can popout a forward", ->
        runs ->
          DraftStore._onComposeForward({threadId: fakeThread.id, messageId: fakeMessage1.id, popout: true}).catch (error) -> throw new Error (error)
        waitsFor ->
          DatabaseTransaction.prototype.persistModel.callCount > 0
        runs ->
          @model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
          expect(Actions.composePopoutDraft).toHaveBeenCalledWith(@model.clientId)

    describe "_newMessageWithContext", ->
      beforeEach ->
        # A helper method that makes it easy to test _newMessageWithContext, which
        # is asynchronous and whose output is a model persisted to the database.
        @_callNewMessageWithContext = (context, attributesCallback, modelCallback) ->
          waitsForPromise ->
            DraftStore._newMessageWithContext(context, attributesCallback).then ->
              model = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
              modelCallback(model) if modelCallback

      it "should create a new message", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          {}
        , (model) ->
          expect(model.constructor).toBe(Message)

      it "should setup a draft session for the draftClientId, so that a subsequent request for the session's draft resolves immediately.", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          {}
        , (model) ->
          session = DraftStore.sessionForClientId(model.id).value()
          expect(session.draft()).toBe(model)

      it "should set the subject of the new message automatically", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          {}
        , (model) ->
          expect(model.subject).toEqual("Re: Fake Subject")

      it "should apply attributes provided by the attributesCallback", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          subject: "Fwd: Fake subject"
          to: [new Contact(email: 'weird@example.com')]
        , (model) ->
          expect(model.subject).toEqual("Fwd: Fake subject")

      describe "extensions", ->
        beforeEach ->
          ExtensionRegistry.Composer.register(TestExtension)
        afterEach ->
          ExtensionRegistry.Composer.unregister(TestExtension)

        it "should give extensions a chance to customize the draft via ext.prepareNewDraft", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            {}
          , (model) ->
            expect(model.body.indexOf("Edited by TestExtension!")).toBe(0)

      describe "context", ->
        it "should accept `thread` or look up a thread when given `threadId`", ->
          @_callNewMessageWithContext {thread: fakeThread}
          , (thread, message) ->
            expect(thread).toBe(fakeThread)
            expect(DatabaseStore.find).not.toHaveBeenCalled()
            {}
          , (model) ->

          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            expect(thread).toBe(fakeThread)
            expect(DatabaseStore.find).toHaveBeenCalled()
            {}
          , (model) ->

        it "should accept `message` or look up a message when given `messageId`", ->
          @_callNewMessageWithContext {thread: fakeThread, message: fakeMessage1}
          , (thread, message) ->
            expect(message).toBe(fakeMessage1)
            expect(DatabaseStore.find).not.toHaveBeenCalled()
            {}
          , (model) ->

          @_callNewMessageWithContext {thread: fakeThread, messageId: fakeMessage1.id}
          , (thread, message) ->
            expect(message).toBe(fakeMessage1)
            expect(DatabaseStore.find).toHaveBeenCalled()
            {}
          , (model) ->


      describe "when a reply-to message is provided by the attributesCallback", ->
        it "should include quoted text in the new message", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.body.indexOf('gmail_quote') > 0).toBe(true)
            expect(model.body.indexOf('Fake Message 1') > 0).toBe(true)

        it "should include the `On ... wrote:` line", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.body.search(/On .+, at .+, Customer &lt;customer@example.com&gt; wrote/) > 0).toBe(true)

        it "should make the subject the subject of the message, not the thread", ->
          fakeMessage1.subject = "OLD SUBJECT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Re: OLD SUBJECT")

        it "should change the subject from Fwd: back to Re: if necessary", ->
          fakeMessage1.subject = "Fwd: This is my DRAFT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Re: This is my DRAFT")

        it "should only include the sender's name if it was available", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage2
          , (model) ->
            expect(model.body.search(/On .+, at .+, ben@nylas.com wrote:/) > 0).toBe(true)

      describe "when a forward message is provided by the attributesCallback", ->
        it "should include quoted text in the new message", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.body.indexOf('gmail_quote') > 0).toBe(true)
            expect(model.body.indexOf('Fake Message 1') > 0).toBe(true)

        it "should include the `---------- Forwarded message ---------:` line", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.body.indexOf('---------- Forwarded message ---------') > 0).toBe(true)

        it "should make the subject the subject of the message, not the thread", ->
          fakeMessage1.subject = "OLD SUBJECT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Fwd: OLD SUBJECT")

        it "should change the subject from Re: back to Fwd: if necessary", ->
          fakeMessage1.subject = "Re: This is my DRAFT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Fwd: This is my DRAFT")

        it "should print the headers of the original message", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage2
          , (model) ->
            expect(model.body.indexOf('From: ben@nylas.com') > 0).toBe(true)
            expect(model.body.indexOf('Subject: Re: Fake Subject') > 0).toBe(true)
            expect(model.body.indexOf('To: customer@example.com') > 0).toBe(true)

      describe "attributesCallback", ->
        describe "when a threadId is provided", ->
          it "should receive the thread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id}
            , (thread, message) ->
              expect(thread).toEqual(fakeThread)
              {}

          it "should receive the last message in the fakeThread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id}
            , (thread, message) ->
              expect(message).toEqual(fakeMessage2)
              {}

        describe "when a threadId and messageId are provided", ->
          it "should receive the thread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id, messageId: fakeMessage1.id}
            , (thread, message) ->
              expect(thread).toEqual(fakeThread)
              {}

          it "should receive the desired message in the thread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id, messageId: fakeMessage1.id}
            , (thread, message) ->
              expect(message).toEqual(fakeMessage1)
              {}

  describe "sanitizing draft bodies", ->
    it "should transform inline styles and sanitize unsafe html", ->
      spyOn(InlineStyleTransformer, 'run').andCallFake (input) => Promise.resolve(input)
      spyOn(SanitizeTransformer, 'run').andCallFake (input) => Promise.resolve(input)

      input = "test 123"
      DraftStore._prepareBodyForQuoting(input)
      expect(InlineStyleTransformer.run).toHaveBeenCalledWith(input)
      advanceClock()
      expect(SanitizeTransformer.run).toHaveBeenCalledWith(input, SanitizeTransformer.Preset.UnsafeOnly)

  describe "onDestroyDraft", ->
    beforeEach ->
      @draftSessionTeardown = jasmine.createSpy('draft teardown')
      @session =
        draft: ->
          pristine: false
        changes:
          commit: -> Promise.resolve()
          teardown: ->
        teardown: @draftSessionTeardown
      DraftStore._draftSessions = {"abc": @session}
      spyOn(Actions, 'queueTask')

    it "should teardown the draft session, ensuring no more saves are made", ->
      DraftStore._onDestroyDraft('abc')
      expect(@draftSessionTeardown).toHaveBeenCalled()

    it "should not throw if the draft session is not in the window", ->
      expect ->
        DraftStore._onDestroyDraft('other')
      .not.toThrow()

    it "should queue a destroy draft task", ->
      DraftStore._onDestroyDraft('abc')
      expect(Actions.queueTask).toHaveBeenCalled()
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true)

    it "should clean up the draft session", ->
      spyOn(DraftStore, '_doneWithSession')
      DraftStore._onDestroyDraft('abc')
      expect(DraftStore._doneWithSession).toHaveBeenCalledWith(@session)

    it "should close the window if it's a popout", ->
      spyOn(NylasEnv, "close")
      spyOn(DraftStore, "_isPopout").andReturn true
      DraftStore._onDestroyDraft('abc')
      expect(NylasEnv.close).toHaveBeenCalled()

    it "should NOT close the window if isn't a popout", ->
      spyOn(NylasEnv, "close")
      spyOn(DraftStore, "_isPopout").andReturn false
      DraftStore._onDestroyDraft('abc')
      expect(NylasEnv.close).not.toHaveBeenCalled()

  describe "before unloading", ->
    it "should destroy pristine drafts", ->
      DraftStore._draftSessions = {"abc": {
        changes: {}
        draft: ->
          pristine: true
      }}

      spyOn(Actions, 'queueTask')
      DraftStore._onBeforeUnload()
      expect(Actions.queueTask).toHaveBeenCalled()
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true)

    describe "when drafts return unresolved commit promises", ->
      beforeEach ->
        @resolve = null
        DraftStore._draftSessions = {"abc": {
          changes:
            commit: => new Promise (resolve, reject) => @resolve = resolve
          draft: ->
            pristine: false
        }}

      it "should return false and call window.close itself", ->
        callback = jasmine.createSpy('callback')
        expect(DraftStore._onBeforeUnload(callback)).toBe(false)
        expect(callback).not.toHaveBeenCalled()
        @resolve()
        advanceClock(1000)
        expect(callback).toHaveBeenCalled()

    describe "when drafts return immediately fulfilled commit promises", ->
      beforeEach ->
        DraftStore._draftSessions = {"abc": {
          changes:
            commit: => Promise.resolve()
          draft: ->
            pristine: false
        }}

      it "should still wait one tick before firing NylasEnv.close again", ->
        callback = jasmine.createSpy('callback')
        expect(DraftStore._onBeforeUnload(callback)).toBe(false)
        expect(callback).not.toHaveBeenCalled()
        advanceClock()
        expect(callback).toHaveBeenCalled()

    describe "when there are no drafts", ->
      beforeEach ->
        DraftStore._draftSessions = {}

      it "should return true and allow the window to close", ->
        expect(DraftStore._onBeforeUnload()).toBe(true)

  describe "sending a draft", ->
    beforeEach ->
      @draft = new Message
        clientId: "local-123",
        threadId: "thread-123",
        replyToMessageId: "message-123"
        uploads: ['stub']
      DraftStore._draftSessions = {}
      DraftStore._draftsSending = {}
      @forceCommit = false
      proxy =
        prepare: -> Promise.resolve(proxy)
        teardown: ->
        draft: => @draft
        changes:
          commit: ({force}={}) =>
            @forceCommit = force
            Promise.resolve()

      DraftStore._draftSessions[@draft.clientId] = proxy
      spyOn(DraftStore, "_doneWithSession").andCallThrough()
      spyOn(DraftStore, "_prepareForSyncback").andReturn(Promise.resolve())
      spyOn(DraftStore, "trigger")
      spyOn(SoundRegistry, "playSound")
      spyOn(Actions, "queueTask")

    it "plays a sound immediately when sending draft", ->
      spyOn(NylasEnv.config, "get").andReturn true
      DraftStore._onSendDraft(@draft.clientId)
      advanceClock()
      expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds")
      expect(SoundRegistry.playSound).toHaveBeenCalledWith("hit-send")

    it "doesn't plays a sound if the setting is off", ->
      spyOn(NylasEnv.config, "get").andReturn false
      DraftStore._onSendDraft(@draft.clientId)
      advanceClock()
      expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds")
      expect(SoundRegistry.playSound).not.toHaveBeenCalled()

    it "sets the sending state when sending", ->
      spyOn(NylasEnv, "isMainWindow").andReturn true
      DraftStore._onSendDraft(@draft.clientId)
      advanceClock()
      expect(DraftStore.isSendingDraft(@draft.clientId)).toBe true

    # Since all changes haven't been applied yet, we want to ensure that
    # no view of the draft renders the draft as if its sending, but with
    # the wrong text.
    it "does NOT trigger until the latest changes have been applied", ->
      spyOn(NylasEnv, "isMainWindow").andReturn true
      runs ->
        DraftStore._onSendDraft(@draft.clientId)
        expect(DraftStore.trigger).not.toHaveBeenCalled()
      waitsFor ->
        Actions.queueTask.calls.length > 0
      runs ->
        # Normally, the session.changes.commit will persist to the
        # Database. Since that's stubbed out, we need to manually invoke
        # to database update event to get the trigger (which we want to
        # test) to fire
        DraftStore._onDataChanged
          objectClass: "Message"
          objects: [draft: true]
        expect(DraftStore.isSendingDraft(@draft.clientId)).toBe true
        expect(DraftStore.trigger).toHaveBeenCalled()
        expect(DraftStore.trigger.calls.length).toBe 1

    it "returns false if the draft hasn't been seen", ->
      spyOn(NylasEnv, "isMainWindow").andReturn true
      expect(DraftStore.isSendingDraft(@draft.clientId)).toBe false

    it "closes the window if it's a popout", ->
      spyOn(NylasEnv, "getWindowType").andReturn "composer"
      spyOn(NylasEnv, "isMainWindow").andReturn false
      spyOn(NylasEnv, "close")
      runs ->
        DraftStore._onSendDraft(@draft.clientId)
      waitsFor "N1 to close", ->
        NylasEnv.close.calls.length > 0

    it "doesn't close the window if it's inline", ->
      spyOn(NylasEnv, "getWindowType").andReturn "other"
      spyOn(NylasEnv, "isMainWindow").andReturn false
      spyOn(NylasEnv, "close")
      spyOn(DraftStore, "_isPopout").andCallThrough()
      runs ->
        DraftStore._onSendDraft(@draft.clientId)
      waitsFor ->
        DraftStore._isPopout.calls.length > 0
      runs ->
        expect(NylasEnv.close).not.toHaveBeenCalled()

    it "queues tasks to upload files and send the draft", ->
      runs ->
        DraftStore._onSendDraft(@draft.clientId)
      waitsFor ->
        DraftStore._doneWithSession.calls.length > 0
      runs ->
        expect(Actions.queueTask).toHaveBeenCalled()
        saveAttachments = Actions.queueTask.calls[0].args[0]
        expect(saveAttachments instanceof SyncbackDraftFilesTask).toBe true
        expect(saveAttachments.draftClientId).toBe(@draft.clientId)
        sendDraft = Actions.queueTask.calls[1].args[0]
        expect(sendDraft instanceof SendDraftTask).toBe true
        expect(sendDraft.draftClientId).toBe(@draft.clientId)

    it "resets the sending state if there's an error", ->
      spyOn(NylasEnv, "isMainWindow").andReturn false
      DraftStore._draftsSending[@draft.clientId] = true
      Actions.draftSendingFailed({errorMessage: "boohoo", draftClientId: @draft.clientId})
      expect(DraftStore.isSendingDraft(@draft.clientId)).toBe false
      expect(DraftStore.trigger).toHaveBeenCalledWith(@draft.clientId)

    it "displays a popup in the main window if there's an error", ->
      spyOn(NylasEnv, "isMainWindow").andReturn true
      spyOn(FocusedContentStore, "focused").andReturn(id: "t1")
      {remote} = require('electron')
      spyOn(remote.dialog, "showMessageBox")
      spyOn(Actions, "composePopoutDraft")
      DraftStore._draftsSending[@draft.clientId] = true
      Actions.draftSendingFailed({threadId: 't1', errorMessage: "boohoo", draftClientId: @draft.clientId})
      advanceClock(200)
      expect(DraftStore.isSendingDraft(@draft.clientId)).toBe false
      expect(DraftStore.trigger).toHaveBeenCalledWith(@draft.clientId)
      expect(remote.dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = remote.dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.detail).toEqual("boohoo")
      expect(Actions.composePopoutDraft).not.toHaveBeenCalled

    it "re-opens the draft if you're not looking at the thread", ->
      spyOn(NylasEnv, "isMainWindow").andReturn true
      spyOn(FocusedContentStore, "focused").andReturn(id: "t1")
      spyOn(Actions, "composePopoutDraft")
      DraftStore._draftsSending[@draft.clientId] = true
      Actions.draftSendingFailed({threadId: 't2', errorMessage: "boohoo", draftClientId: @draft.clientId})
      advanceClock(200)
      expect(Actions.composePopoutDraft).toHaveBeenCalled
      call = Actions.composePopoutDraft.calls[0]
      expect(call.args[0]).toBe @draft.clientId
      expect(call.args[1]).toEqual {errorMessage: "boohoo"}

    it "re-opens the draft if there is no thread id", ->
      spyOn(NylasEnv, "isMainWindow").andReturn true
      spyOn(Actions, "composePopoutDraft")
      DraftStore._draftsSending[@draft.clientId] = true
      spyOn(FocusedContentStore, "focused").andReturn(null)
      Actions.draftSendingFailed({errorMessage: "boohoo", draftClientId: @draft.clientId})
      advanceClock(200)
      expect(Actions.composePopoutDraft).toHaveBeenCalled
      call = Actions.composePopoutDraft.calls[0]
      expect(call.args[0]).toBe @draft.clientId
      expect(call.args[1]).toEqual {errorMessage: "boohoo"}

  describe "session teardown", ->
    beforeEach ->
      spyOn(NylasEnv, 'isMainWindow').andReturn true
      @draftTeardown = jasmine.createSpy('draft teardown')
      @session =
        draftClientId: "abc"
        draft: ->
          pristine: false
        changes:
          commit: -> Promise.resolve()
          reset: ->
        teardown: @draftTeardown
      DraftStore._draftSessions = {"abc": @session}
      DraftStore._doneWithSession(@session)

    it "removes from the list of draftSessions", ->
      expect(DraftStore._draftSessions["abc"]).toBeUndefined()

    it "Calls teardown on the session", ->
      expect(@draftTeardown).toHaveBeenCalled

  describe "mailto handling", ->
    beforeEach ->
      spyOn(NylasEnv, 'isMainWindow').andReturn true

    describe "extensions", ->
      beforeEach ->
        ExtensionRegistry.Composer.register(TestExtension)
      afterEach ->
        ExtensionRegistry.Composer.unregister(TestExtension)

      it "should give extensions a chance to customize the draft via ext.prepareNewDraft", ->
        received = null
        spyOn(DatabaseTransaction.prototype, 'persistModel').andCallFake (draft) ->
          received = draft
          Promise.resolve()
        waitsForPromise ->
          DraftStore._onHandleMailtoLink({}, 'mailto:bengotow@gmail.com').then ->
            expect(received.body.indexOf("Edited by TestExtension!")).toBe(0)

    describe "when testing subject keys", ->
      beforeEach ->
        spyOn(DraftStore, '_finalizeAndPersistNewMessage').andCallFake (draft) ->
          Promise.resolve({draftClientId: 123})

        @expected = "EmailSubjectLOLOL"

      it "works for lowercase", ->
        waitsForPromise =>
          DraftStore._onHandleMailtoLink({}, 'mailto:asdf@asdf.com?subject=' + @expected).then =>
            received = DraftStore._finalizeAndPersistNewMessage.mostRecentCall.args[0]
            expect(received.subject).toBe(@expected)

      it "works for title case", ->
        waitsForPromise =>
          DraftStore._onHandleMailtoLink({}, 'mailto:asdf@asdf.com?Subject=' + @expected).then =>
            received = DraftStore._finalizeAndPersistNewMessage.mostRecentCall.args[0]
            expect(received.subject).toBe(@expected)

      it "works for uppercase", ->
        waitsForPromise =>
          DraftStore._onHandleMailtoLink({}, 'mailto:asdf@asdf.com?SUBJECT=' + @expected).then =>
            received = DraftStore._finalizeAndPersistNewMessage.mostRecentCall.args[0]
            expect(received.subject).toBe(@expected)

    describe "should correctly instantiate drafts for a wide range of mailto URLs", ->
      beforeEach ->
        spyOn(DatabaseTransaction.prototype, 'persistModel').andCallFake (draft) ->
          Promise.resolve()

      links = [
        'mailto:'
        'mailto://bengotow@gmail.com'
        'mailto:bengotow@gmail.com'
        'mailto:mg%40nylas.com'
        'mailto:?subject=%1z2a', # fails uriDecode
        'mailto:?subject=%52z2a', # passes uriDecode
        'mailto:?subject=Martha Stewart',
        'mailto:?subject=Martha Stewart&cc=cc@nylas.com',
        'mailto:bengotow@gmail.com&subject=Martha Stewart&cc=cc@nylas.com',
        'mailto:bengotow@gmail.com?subject=Martha%20Stewart&cc=cc@nylas.com&bcc=bcc@nylas.com',
        'mailto:bengotow@gmail.com?subject=Martha%20Stewart&cc=cc@nylas.com&bcc=Ben <bcc@nylas.com>',
        'mailto:Ben Gotow <bengotow@gmail.com>,Shawn <shawn@nylas.com>?subject=Yes this is really valid',
        'mailto:Ben%20Gotow%20<bengotow@gmail.com>,Shawn%20<shawn@nylas.com>?subject=Yes%20this%20is%20really%20valid',
        'mailto:Reply <d+AORGpRdj0KXKUPBE1LoI0a30F10Ahj3wu3olS-aDk5_7K5Wu6WqqqG8t1HxxhlZ4KEEw3WmrSdtobgUq57SkwsYAH6tG57IrNqcQR0K6XaqLM2nGNZ22D2k@docs.google.com>?subject=Nilas%20Message%20to%20Customers',
        'mailto:email@address.com?&subject=test&body=type%20your%0Amessage%20here'
        'mailto:?body=type%20your%0D%0Amessage%0D%0Ahere'
        'mailto:?subject=Issues%20%C2%B7%20atom/electron%20%C2%B7%20GitHub&body=https://github.com/atom/electron/issues?utf8=&q=is%253Aissue+is%253Aopen+123%0A%0A'
      ]
      expected = [
        new Message(),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')]
        ),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')]
        ),
        new Message(
          to: [new Contact(name: 'mg@nylas.com', email: 'mg@nylas.com')]
        ),
        new Message(
          subject: '%1z2a'
        ),
        new Message(
          subject: 'Rz2a'
        ),
        new Message(
          subject: 'Martha Stewart'
        ),
        new Message(
          cc: [new Contact(name: 'cc@nylas.com', email: 'cc@nylas.com')],
          subject: 'Martha Stewart'
        ),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')],
          cc: [new Contact(name: 'cc@nylas.com', email: 'cc@nylas.com')],
          subject: 'Martha Stewart'
        ),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')],
          cc: [new Contact(name: 'cc@nylas.com', email: 'cc@nylas.com')],
          bcc: [new Contact(name: 'bcc@nylas.com', email: 'bcc@nylas.com')],
          subject: 'Martha Stewart'
        ),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')],
          cc: [new Contact(name: 'cc@nylas.com', email: 'cc@nylas.com')],
          bcc: [new Contact(name: 'Ben', email: 'bcc@nylas.com')],
          subject: 'Martha Stewart'
        ),
        new Message(
          to: [new Contact(name: 'Ben Gotow', email: 'bengotow@gmail.com'), new Contact(name: 'Shawn', email: 'shawn@nylas.com')],
          subject: 'Yes this is really valid'
        ),
        new Message(
          to: [new Contact(name: 'Ben Gotow', email: 'bengotow@gmail.com'), new Contact(name: 'Shawn', email: 'shawn@nylas.com')],
          subject: 'Yes this is really valid'
        ),
        new Message(
          to: [new Contact(name: 'Reply', email: 'd+AORGpRdj0KXKUPBE1LoI0a30F10Ahj3wu3olS-aDk5_7K5Wu6WqqqG8t1HxxhlZ4KEEw3WmrSdtobgUq57SkwsYAH6tG57IrNqcQR0K6XaqLM2nGNZ22D2k@docs.google.com')],
          subject: 'Nilas Message to Customers'
        ),
        new Message(
          to: [new Contact(name: 'email@address.com', email: 'email@address.com')],
          subject: 'test'
          body: 'type your\nmessage here'
        ),
        new Message(
          to: [],
          body: 'type your\r\nmessage\r\nhere'
        ),
        new Message(
          to: [],
          subject: 'Issues · atom/electron · GitHub'
          body: 'https://github.com/atom/electron/issues?utf8=&q=is%3Aissue+is%3Aopen+123\n\n'
        )
      ]

      links.forEach (link, idx) ->
        it "works for #{link}", ->
          waitsForPromise ->
            DraftStore._onHandleMailtoLink({}, link).then ->
              expectedDraft = expected[idx]
              received = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0]
              expect(received['subject']).toEqual(expectedDraft['subject'])
              expect(received['body']).toEqual(expectedDraft['body']) if expectedDraft['body']
              ['to', 'cc', 'bcc'].forEach (attr) ->
                expectedDraft[attr].forEach (expected, jdx) ->
                  actual = received[attr][jdx]
                  expect(actual instanceof Contact).toBe(true)
                  expect(actual.email).toEqual(expected.email)
                  expect(actual.name).toEqual(expected.name)

  describe "mailfiles handling", ->
    it "should popout a new draft", ->
      defaultMe = new Contact()
      spyOn(DraftStore, '_onPopoutDraftClientId')
      spyOn(DatabaseTransaction.prototype, 'persistModel')
      spyOn(Account.prototype, 'defaultMe').andReturn(defaultMe)
      spyOn(Actions, 'addAttachment')
      DraftStore._onHandleMailFiles({}, ['/Users/ben/file1.png', '/Users/ben/file2.png'])
      waitsFor ->
        DatabaseTransaction.prototype.persistModel.callCount > 0
      runs ->
        {body, subject, from} = DatabaseTransaction.prototype.persistModel.calls[0].args[0]
        expect({body, subject, from}).toEqual({body:'', subject:'', from: [defaultMe]})
        expect(DraftStore._onPopoutDraftClientId).toHaveBeenCalled()

    it "should call addAttachment for each provided file path", ->
      spyOn(Actions, 'addAttachment')
      DraftStore._onHandleMailFiles({}, ['/Users/ben/file1.png', '/Users/ben/file2.png'])
      waitsFor ->
        Actions.addAttachment.callCount is 2
      runs ->
        expect(Actions.addAttachment.calls[0].args[0].filePath).toEqual('/Users/ben/file1.png')
        expect(Actions.addAttachment.calls[1].args[0].filePath).toEqual('/Users/ben/file2.png')
