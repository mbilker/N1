_ = require 'underscore'
DatabaseStore = require '../../src/flux/stores/database-store'
DatabaseTransaction = require '../../src/flux/stores/database-transaction'
ThreadCountsStore = require '../../src/flux/stores/thread-counts-store'
Thread = require '../../src/flux/models/thread'
Category = require '../../src/flux/models/category'
Matcher = require '../../src/flux/attributes/matcher'
WindowBridge = require '../../src/window-bridge'

category1 = new Category(id: "l1", name: "inbox", displayName: "Inbox")
category2 = new Category(id: "l2", name: "archive", displayName: "Archive")
category3 = new Category(id: "l3", displayName: "Happy Days")
category4 = new Category(id: "l4", displayName: "Sad Days")
category5 = new Category(id: "l5", name: 'all', displayName: "All Mail")
category6 = new Category(id: "l6", name: 'trash', displayName: "Trash")

# Values here are the "after" state. Below, the spy on the query returns the
# "current" state.
threadA = new Thread
  id: "A"
  unread: true
  categories: [category1, category4, category5]
  categoriesType: 'labels'
threadB = new Thread
  id: "B"
  unread: true
  categories: [category3, category5]
  categoriesType: 'labels'
threadC = new Thread
  id: "C"
  unread: false
  categories: [category1, category3, category5]
  categoriesType: 'labels'
threadD = new Thread
  id: "D"
  unread: true
  categories: [category6]
  categoriesType: 'labels'
threadE = new Thread
  id: "E"
  unread: true
  categories: [category1, category5]
  categoriesType: 'labels'


describe "ThreadCountsStore", ->
  describe "unreadCountForCategoryId", ->
    it "returns null if no count exists for the category id", ->
      expect(ThreadCountsStore.unreadCountForCategoryId('nan')).toBe(null)

    it "returns the count plus any unsaved deltas", ->
      ThreadCountsStore._counts =
        'b': 3
        'a': 5
      ThreadCountsStore._deltas =
        'a': -1
      expect(ThreadCountsStore.unreadCountForCategoryId('a')).toBe(4)
      expect(ThreadCountsStore.unreadCountForCategoryId('b')).toBe(3)

  describe "when the mutation observer reports count changes", ->
    describe "in the work window", ->
      beforeEach ->
        spyOn(NylasEnv, 'isWorkWindow').andReturn(true)

      it "should merge count deltas into existing count detlas", ->
        ThreadCountsStore._deltas =
          'l1': -1
          'l2': 2
        ThreadCountsStore._onCountsChanged({'l1': -1, 'l2': 1, 'l3': 2})
        expect(ThreadCountsStore._deltas).toEqual({
          'l1': -2,
          'l2': 3,
          'l3': 2
        })

      it "should queue a save of the counts", ->
        spyOn(ThreadCountsStore, '_saveCountsSoon')
        ThreadCountsStore._onCountsChanged({'l1': -1, 'l2': 1, 'l3': 2})
        expect(ThreadCountsStore._saveCountsSoon).toHaveBeenCalled()

    describe "in other windows", ->
      beforeEach ->
        spyOn(NylasEnv, 'isWorkWindow').andReturn(false)

      it "should use the WindowBridge to forward the invocation to the work window", ->
        spyOn(WindowBridge, 'runInWorkWindow')
        payload = {'l1': -1, 'l2': 1, 'l3': 2}
        ThreadCountsStore._onCountsChanged(payload)
        expect(WindowBridge.runInWorkWindow).toHaveBeenCalledWith('ThreadCountsStore', '_onCountsChanged', [payload])

  describe "when counts are persisted", ->
    it "should update it's _counts cache and trigger", ->
      newCounts = {
        'abc': 1
      }
      spyOn(ThreadCountsStore, 'trigger')
      ThreadCountsStore._onCountsBlobRead(newCounts)
      expect(ThreadCountsStore._counts).toEqual(newCounts)
      expect(ThreadCountsStore.trigger).toHaveBeenCalled()

  describe "_fetchCountsMissing", ->
    beforeEach ->
      ThreadCountsStore._categories = [
        new Category(id: "l1", name: "inbox", displayName: "Inbox", accountId: 'a1'),
        new Category(id: "l2", name: "archive", displayName: "Archive", accountId: 'a1'),
        new Category(id: "l3", displayName: "Happy Days", accountId: 'a1'),
        new Category(id: "l4", displayName: "Sad Days", accountId: 'a1')
      ]
      ThreadCountsStore._deltas =
        l1: 10
        l2: 0
        l3: 3
        l4: 12
      ThreadCountsStore._counts =
        l1: 10
        l2: 0

      @countResolve = null
      @countReject = null
      spyOn(ThreadCountsStore, '_fetchCountForCategory').andCallFake =>
        new Promise (resolve, reject) =>
          @countResolve = resolve
          @countReject = reject

    it "should call _fetchCountForCategory for the first category not already in the counts cache", ->
      ThreadCountsStore._fetchCountsMissing()
      calls = ThreadCountsStore._fetchCountForCategory.calls
      expect(calls.length).toBe(1)
      expect(calls[0].args[0]).toBe(ThreadCountsStore._categories[2])

    it "should set the _deltas for the category it's counting back to zero", ->
      ThreadCountsStore._fetchCountsMissing()
      expect(ThreadCountsStore._deltas.l3).toBe(0)

    describe "when the count promise finishes", ->
      it "should add it to the count cache", ->
        ThreadCountsStore._fetchCountsMissing()
        advanceClock()
        @countResolve(4)
        advanceClock()
        expect(ThreadCountsStore._counts.l3).toEqual(4)

      it "should call _fetchCountsMissing again to populate the next missing count", ->
        ThreadCountsStore._fetchCountsMissing()
        spyOn(ThreadCountsStore, '_fetchCountsMissing')
        advanceClock()
        @countResolve(4)
        advanceClock()
        advanceClock(10001)
        expect(ThreadCountsStore._fetchCountsMissing).toHaveBeenCalled()

      describe "when deltas appear during a count", ->
        it "should not set the count and count again in 10 seconds", ->
          ThreadCountsStore._fetchCountsMissing()
          spyOn(ThreadCountsStore, '_fetchCountsMissing')
          advanceClock()
          ThreadCountsStore._deltas.l3 = -1
          @countResolve(4)
          advanceClock()
          expect(ThreadCountsStore._counts.l3).toBeUndefined()
          expect(ThreadCountsStore._fetchCountsMissing).not.toHaveBeenCalled()
          advanceClock(10001)
          expect(ThreadCountsStore._fetchCountsMissing).toHaveBeenCalled()

      describe "when a count fails", ->
        it "should not immediately try to count any other categories", ->
          spyOn(console, "warn")
          ThreadCountsStore._fetchCountsMissing()
          spyOn(ThreadCountsStore, '_fetchCountsMissing')
          spyOn(console, 'error')
          advanceClock()
          @countReject(new Error("Oh man something really bad."))
          advanceClock()
          expect(console.warn).toHaveBeenCalled()
          expect(ThreadCountsStore._fetchCountsMissing).not.toHaveBeenCalled()

  describe "_fetchCountForCategory", ->
    it "should make the appropriate category database query", ->
      spyOn(DatabaseStore, 'count')
      Matcher.muid = 0
      ThreadCountsStore._fetchCountForCategory(new Category(id: 'l1', accountId: 'a1'))
      Matcher.muid = 0
      expect(DatabaseStore.count).toHaveBeenCalledWith(Thread, [
        Thread.attributes.categories.contains('l1'),
        Thread.attributes.accountId.equal('a1'),
        Thread.attributes.unread.equal(true),
      ])

  describe "_saveCounts", ->
    beforeEach ->
      ThreadCountsStore._counts =
        'b': 3
        'a': 5
      ThreadCountsStore._deltas =
        'a': -1
        'c': 2

    it "should merge the deltas into the counts and reset the deltas, ignoring any deltas for which the initial count has not been run", ->
      ThreadCountsStore._saveCounts()
      expect(ThreadCountsStore._counts).toEqual({
        'b': 3
        'a': 4
      })

    it "should persist the new counts to the database", ->
      spyOn(DatabaseTransaction.prototype, 'persistJSONBlob')
      runs =>
        ThreadCountsStore._saveCounts()
      waitsFor =>
        DatabaseTransaction.prototype.persistJSONBlob.callCount > 0
      runs =>
        expect(DatabaseTransaction.prototype.persistJSONBlob).toHaveBeenCalledWith(ThreadCountsStore.JSONBlobKey, ThreadCountsStore._counts)

describe "CategoryDatabaseMutationObserver", ->
  beforeEach ->
    @queryResolves = []
    @query = jasmine.createSpy('query').andCallFake =>
      new Promise (resolve, reject) =>
        @queryResolves.push(resolve)

    @countsDidChange = jasmine.createSpy('countsDidChange')
    @m = new ThreadCountsStore.CategoryDatabaseMutationObserver(@countsDidChange)

  describe "given a set of modifying models", ->
    scenarios = [
      {
        name: 'Persisting a three threads, two unread, all in all mail'
        type: 'persist',
        threads: [threadA, threadB, threadC],
        beforePersistQueryResults: [
          {id: threadA.id, catId: category1.id},
          {id: threadA.id, catId: category3.id},
          {id: threadA.id, catId: category5.id},
          {id: threadB.id, catId: category2.id},
          {id: threadB.id, catId: category5.id},
          {id: threadB.id, catId: category3.id},
          {id: threadC.id, catId: category5.id},
        ]
        beforePersistExpected: {
          l1: -1,
          l3: -2,
          l2: -1,
          l5: -3
        }
        afterPersistExpected: {
          l3: -1,
          l5: -1,
          l2: -1,
          l4: 1,
        }
      },
      {
        name: 'Unpersisting a normal set of threads, all in all mail'
        type: 'unpersist',
        threads: [threadA, threadB, threadC],
        beforePersistQueryResults: [
          {id: threadA.id, catId: category1.id},
          {id: threadA.id, catId: category3.id},
          {id: threadA.id, catId: category5.id},
          {id: threadB.id, catId: category2.id},
          {id: threadB.id, catId: category5.id},
          {id: threadB.id, catId: category3.id},
          {id: threadC.id, catId: category5.id},
        ]
        beforePersistExpected: {
          l1: -1,
          l3: -2,
          l2: -1,
          l5: -3
        }
        afterPersistExpected: {
          l1: -1,
          l5: -3,
          l3: -2,
          l2: -1
        }
      },
      {
        name: 'Thread D going from inbox to trash'
        type: 'persist',
        threads: [threadD],
        beforePersistQueryResults: [
          {id: threadD.id, catId: category1.id},
          {id: threadD.id, catId: category3.id},
          {id: threadD.id, catId: category4.id},
        ]
        beforePersistExpected: {
          l1: -1,
          l3: -1,
          l4: -1
        }
        afterPersistExpected: {
          l1: -1,
          l3: -1,
          l4: -1,
        }
      },
      {
        name: 'Thread E going from trash to inbox'
        type: 'persist',
        threads: [threadE],
        beforePersistQueryResults: [
        ]
        beforePersistExpected: {
        }
        afterPersistExpected: {
          l1: 1,
          l5: 1
        }
      },
    ]
    scenarios.forEach ({name, type, threads, beforePersistQueryResults, beforePersistExpected, afterPersistExpected}) ->
      it "should call countsDidChange with the category membership deltas (#{name})", ->
        beforePromise = @m.beforeDatabaseChange(@query, {
          type: type
          objects: threads,
          objectIds: _.pluck(threads, 'id'),
          objectClass: Thread.name
        })
        expect(@query.callCount).toBe(1)
        expect(@query.calls[0].args[0]).toEqual("SELECT `Thread`.id as id, `Thread-Category`.`value` as catId FROM `Thread` INNER JOIN `Thread-Category` ON `Thread`.`id` = `Thread-Category`.`id` WHERE `Thread`.id IN ('#{_.pluck(threads, 'id').join("','")}') AND `Thread`.unread = 1 AND `Thread`.in_all_mail = 1")
        @queryResolves[0](beforePersistQueryResults)

        waitsForPromise =>
          beforePromise.then (result) =>
            expect(result).toEqual({categories: beforePersistExpected})
            @m.afterDatabaseChange(@query, {
              type: type
              objects: threads,
              objectIds: _.pluck(threads, 'id'),
              objectClass: Thread.name
            }, result)
            expect(@countsDidChange).toHaveBeenCalledWith(afterPersistExpected)
