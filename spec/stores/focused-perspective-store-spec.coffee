_ = require 'underscore'

Actions = require '../../src/flux/actions'
Category = require '../../src/flux/models/category'
MailboxPerspective = require '../../src/mailbox-perspective'

CategoryStore = require '../../src/flux/stores/category-store'
AccountStore = require '../../src/flux/stores/account-store'
FocusedPerspectiveStore = require '../../src/flux/stores/focused-perspective-store'

describe "FocusedPerspectiveStore", ->
  beforeEach ->
    spyOn(FocusedPerspectiveStore, 'trigger')
    FocusedPerspectiveStore._perspective = null
    @account = AccountStore.accounts()[0]

    @inboxCategory = new Category(id: 'id-123', name: 'inbox', displayName: "INBOX", accountId: @account.id)
    @inboxPerspective = MailboxPerspective.forCategory(@inboxCategory)
    @userCategory = new Category(id: 'id-456', name: null, displayName: "MyCategory", accountId: @account.id)
    @userPerspective = MailboxPerspective.forCategory(@userCategory)

    spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory
    spyOn(CategoryStore, "byId").andCallFake (id) =>
      return @inboxCategory if id is @inboxCategory.id
      return @userCategory if id is @userCategory.id
      return null

  describe "_loadSavedPerspective", ->
    beforeEach ->
      @default = 'default'
      @accounts = [{id: 1}, {id: 2}]
      spyOn(MailboxPerspective, 'fromJSON').andCallFake (json) -> json
      spyOn(FocusedPerspectiveStore, '_defaultPerspective').andReturn @default

    it "uses default perspective when no perspective has been saved", ->
      current = FocusedPerspectiveStore._loadSavedPerspective(undefined, @accounts)
      expect(current).toEqual @default

    it "uses default if saved perspective has more account ids not present in current accounts", ->
      saved = {accountIds: [1,2,3]}
      current = FocusedPerspectiveStore._loadSavedPerspective(saved, @accounts)
      expect(current).toEqual @default

      saved = {accountIds: [3]}
      current = FocusedPerspectiveStore._loadSavedPerspective(saved, @accounts)
      expect(current).toEqual @default

    it "uses saved perspective if all accounts in saved perspective are present in the current accounts", ->
      saved = {accountIds: [1,2]}
      current = FocusedPerspectiveStore._loadSavedPerspective(saved, @accounts)
      expect(current).toEqual saved

      saved = {accountIds: [1]}
      current = FocusedPerspectiveStore._loadSavedPerspective(saved, @accounts)
      expect(current).toEqual saved

  describe "_onCategoryStoreChanged", ->
    it "should load the saved perspective if the perspective has not been initialized", ->
      spyOn(FocusedPerspectiveStore, '_loadSavedPerspective').andReturn(@inboxPerspective)
      FocusedPerspectiveStore._onCategoryStoreChanged()
      expect(FocusedPerspectiveStore.current()).toEqual(@inboxPerspective)

    it "should set the current category to default when the current category no longer exists in the CategoryStore", ->
      defaultPerspective = @inboxPerspective
      spyOn(FocusedPerspectiveStore, '_defaultPerspective').andReturn(defaultPerspective)
      otherAccountInbox = @inboxCategory.clone()
      otherAccountInbox.serverId = 'other-id'
      FocusedPerspectiveStore._current = MailboxPerspective.forCategory(otherAccountInbox)
      FocusedPerspectiveStore._onCategoryStoreChanged()
      expect(FocusedPerspectiveStore.current()).toEqual(defaultPerspective)

  describe "_onFocusPerspective", ->
    it "should focus the category and trigger", ->
      FocusedPerspectiveStore._onFocusPerspective(@userPerspective)
      expect(FocusedPerspectiveStore.trigger).toHaveBeenCalled()
      expect(FocusedPerspectiveStore.current().categories()).toEqual([@userCategory])

    it "should do nothing if the category is already focused", ->
      FocusedPerspectiveStore._onFocusPerspective(@inboxPerspective)
      spyOn(FocusedPerspectiveStore, '_setPerspective')
      FocusedPerspectiveStore._onFocusPerspective(@inboxPerspective)
      expect(FocusedPerspectiveStore._setPerspective).not.toHaveBeenCalled()
