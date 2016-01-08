Rx = require 'rx-lite'
_ = require 'underscore'
QuerySubscriptionPool = require '../flux/models/query-subscription-pool'
AccountStore = require '../flux/stores/account-store'
DatabaseStore = require '../flux/stores/database-store'

AccountOperators = {}

AccountObservables =
  forCurrentId: ->
    observable = Rx.Observable
      .fromStore(AccountStore)
      .map -> AccountStore.current()?.id
      .distinctUntilChanged()
    _.extend(observable, AccountOperators)
    observable

CategoryOperators =
  sort: ->
    @.map (categories) ->
      return categories.sort (catA, catB) ->
        nameA = catA.displayName
        nameB = catB.displayName

        # Categories that begin with [, like [Mailbox]/For Later
        # should appear at the bottom, because they're likely autogenerated.
        nameA = "ZZZ"+nameA if nameA[0] is '['
        nameB = "ZZZ"+nameB if nameB[0] is '['

        nameA.localeCompare(nameB)

CategoryObservables =
  forCurrentAccount: ->
    observable = Rx.Observable.fromStore(AccountStore).flatMapLatest ->
      return CategoryObservables.forAccount(AccountStore.current())
    _.extend(observable, CategoryOperators)
    observable

  forAllAccounts: =>
    observable = Rx.Observable.fromStore(AccountStore).flatMapLatest ->
      observables = for account in AccountStore.items()
        categoryClass = account.categoryClass() if account
        if categoryClass
          Rx.Observable.fromQuery(DatabaseStore.findAll(categoryClass))
        else
          Rx.Observable.from([])
      Rx.Observable.concat(observables)
    _.extend(observable, CategoryOperators)
    observable

  forAccount: (account) =>
    if account
      categoryClass = account.categoryClass()
      observable = Rx.Observable.fromQuery(DatabaseStore.findAll(categoryClass).where(categoryClass.attributes.accountId.equal(account.id)))
    else
      observable = Rx.Observable.from([])
    _.extend(observable, CategoryOperators)
    observable

module.exports =
  Categories: CategoryObservables
  Accounts: AccountObservables

# Attach a few global helpers

Rx.Observable.fromStore = (store) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = store.listen =>
      observer.onNext(store)
    observer.onNext(store)
    return Rx.Disposable.create(unsubscribe)

Rx.Observable.fromQuery = (query, options) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = QuerySubscriptionPool.add query, options, (result) =>
      observer.onNext(result)
    return Rx.Disposable.create(unsubscribe)
