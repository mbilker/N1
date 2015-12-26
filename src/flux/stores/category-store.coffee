_ = require 'underscore'
Label = require '../models/label'
Folder = require '../models/folder'
NylasAPI = require '../nylas-api'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
Rx = require 'rx-lite'

class CategoryStore extends NylasStore
  constructor: ->
    @_categoryCache = {}
    @_standardCategories = []
    @_userCategories = []
    @_hiddenCategories = []

    NylasEnv.config.observe 'core.workspace.showImportant', => @_buildQuerySubscription()
    @_buildQuerySubscription()

  # We look for a few standard categories and display them in the Mailboxes
  # portion of the left sidebar. Note that these may not all be present on
  # a particular account.
  StandardCategoryNames: [
    "inbox"
    "important"
    "sent"
    "drafts"
    "all"
    "spam"
    "archive"
    "trash"
  ]

  LockedCategoryNames: [
    "sent"
  ]

  HiddenCategoryNames: [
    "sent"
    "drafts"
    "all"
    "archive"
    "starred"
    "important"
  ]

  AllMailName: "all"

  byId: (id) -> @_categoryCache[id]

  categoryLabel: ->
    account = AccountStore.current()
    return "Unknown" unless account

    if account.usesFolders()
      return "Folders"
    else if account.usesLabels()
      return "Labels"
    else
      return "Unknown"

  categoryIconName: ->
    account = AccountStore.current()
    return "folder.png" unless account

    if account.usesFolders()
      return "folder.png"
    else if account.usesLabels()
      return "tag.png"
    else
      return null


  # Public: Returns {Folder} or {Label}, depending on the current provider.
  #
  categoryClass: ->
    account = AccountStore.current()
    return null unless account
    return account.categoryClass()

  # Public: Returns an array of all the categories in the current account, both
  # standard and user generated. The items returned by this function will be
  # either {Folder} or {Label} objects.
  #
  getCategories: -> _.values @_categoryCache

  # Public: Returns the Folder or Label object for a standard category name.
  # ('inbox', 'drafts', etc.) It's possible for this to return `null`.
  # For example, Gmail likely doesn't have an `archive` label.
  #
  getStandardCategory: (name) ->
    if not name in @StandardCategoryNames
      throw new Error("'#{name}' is not a standard category")
    return _.findWhere @_categoryCache, {name}

  # Public: Returns the Folder or Label object that should be used for "Archive"
  # actions. On Gmail, this is the "all" label. On providers using folders, it
  # returns any available "Archive" folder, or null if no such folder exists.
  #
  getArchiveCategory: ->
    account = AccountStore.current()
    return null unless account
    if account.usesFolders()
      return @getStandardCategory("archive")
    else
      return @getStandardCategory("all")

  # Public: Returns the Folder or Label object taht should be used for
  # "Move to Trash", or null if no trash folder exists.
  #
  getTrashCategory: ->
    @getStandardCategory("trash")

  # Public: Returns all of the standard categories for the current account.
  #
  getStandardCategories: ->
    @_standardCategories

  getHiddenCategories: ->
    @_hiddenCategories

  # Public: Returns all of the categories that are not part of the standard
  # category set.
  #
  getUserCategories: ->
    @_userCategories

  _buildQuerySubscription: =>
    {Categories} = require 'nylas-observables'
    @_queryUnlisten?.dispose()
    @_queryUnlisten = Categories.forCurrentAccount().sort().subscribe(@_onCategoriesChanged)

  _onCategoriesChanged: (categories) =>
    return unless categories

    @_categoryCache = {}
    for category in categories
      @_categoryCache[category.id] = category

    # Compute user categories
    @_userCategories = _.compact _.reject categories, (cat) =>
      cat.name in @StandardCategoryNames or cat.name in @HiddenCategoryNames

    # Compute hidden categories
    @_hiddenCategories = _.filter categories, (cat) =>
      cat.name in @HiddenCategoryNames

    # Compute standard categories
    # Single pass to create lookup table, single pass to get ordered array
    byStandardName = {}
    for key, val of @_categoryCache
      byStandardName[val.name] = val

    if not NylasEnv.config.get('core.workspace.showImportant')
      delete byStandardName['important']

    @_standardCategories = _.compact @StandardCategoryNames.map (name) =>
      byStandardName[name]

    @trigger()

module.exports = new CategoryStore()
