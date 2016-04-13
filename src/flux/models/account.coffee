ModelWithMetadata = require './model-with-metadata'
Attributes = require '../attributes'
_ = require 'underscore'
CategoryStore = null
Contact = null

###
Public: The Account model represents a Account served by the Nylas Platform API.
Every object on the Nylas platform exists within a Account, which typically represents
an email account.

For more information about Accounts on the Nylas Platform, read the
[Account API Documentation](https://nylas.com/docs/api#Account)

## Attributes

`name`: {AttributeString} The name of the Account.

`provider`: {AttributeString} The Account's mail provider  (ie: `gmail`)

`emailAddress`: {AttributeString} The Account's email address
(ie: `ben@nylas.com`). Queryable.

`organizationUnit`: {AttributeString} Either "label" or "folder".
Depending on the provider, the account may be organized by folders or
labels.

This class also inherits attributes from {Model}

Section: Models
###
class Account extends ModelWithMetadata

  @SYNC_STATE_RUNNING = "running"
  @SYNC_STATE_STOPPED = "stopped"
  @SYNC_STATE_AUTH_FAILED = "invalid"
  @SYNC_STATE_ERROR = "sync_error"

  @attributes: _.extend {}, ModelWithMetadata.attributes,
    'name': Attributes.String
      modelKey: 'name'

    'provider': Attributes.String
      modelKey: 'provider'

    'emailAddress': Attributes.String
      queryable: true
      modelKey: 'emailAddress'
      jsonKey: 'email_address'

    'organizationUnit': Attributes.String
      modelKey: 'organizationUnit'
      jsonKey: 'organization_unit'

    'label': Attributes.String
      queryable: false
      modelKey: 'label'

    'aliases': Attributes.Object
      queryable: false
      modelKey: 'aliases'

    'defaultAlias': Attributes.Object
      queryable: false
      modelKey: 'defaultAlias'
      jsonKey: 'default_alias'

    'syncState': Attributes.String
      queryable: false
      modelKey: 'syncState'
      jsonKey: 'sync_state'

  constructor: ->
    super
    @aliases ||= []
    @label ||= @emailAddress
    @syncState ||= "running"

  fromJSON: (json) ->
    json["label"] ||= json[@constructor.attributes['emailAddress'].jsonKey]
    super

  # Returns a {Contact} model that represents the current user.
  me: ->
    Contact ?= require './contact'
    return new Contact
      accountId: @id
      name: @name
      email: @emailAddress

  meUsingAlias: (alias) ->
    Contact ?= require './contact'
    return @me() unless alias
    return Contact.fromString(alias, accountId: @id)

  defaultMe: ->
    if @defaultAlias
      return @meUsingAlias(@defaultAlias)
    else
      return @me()

  usesLabels: ->
    @organizationUnit is "label"

  usesFolders: ->
    @organizationUnit is "folder"

  categoryLabel: ->
    if @usesFolders()
      'Folders'
    else if @usesLabels()
      'Labels'
    else
      'Unknown'

  categoryCollection: ->
    "#{@organizationUnit}s"

  categoryIcon: ->
    if @usesFolders()
      'folder.png'
    else if @usesLabels()
      'tag.png'
    else
      'folder.png'

  # Public: Returns the localized, properly capitalized provider name,
  # like Gmail, Exchange, or Outlook 365
  displayProvider: ->
    if @provider is 'eas'
      return 'Exchange'
    else if @provider is 'gmail'
      return 'Gmail'
    else
      return @provider

  canArchiveThreads: ->
    CategoryStore ?= require '../stores/category-store'
    CategoryStore.getArchiveCategory(@)?

  canTrashThreads: ->
    CategoryStore ?= require '../stores/category-store'
    CategoryStore.getTrashCategory(@)?

  defaultFinishedCategory: ->
    CategoryStore ?= require '../stores/category-store'
    preferDelete = NylasEnv.config.get('core.reading.backspaceDelete')
    archiveCategory = CategoryStore.getArchiveCategory(@)
    trashCategory = CategoryStore.getTrashCategory(@)

    if preferDelete or not archiveCategory
      trashCategory
    else
      archiveCategory

  hasSyncStateError: ->
    # TODO: ignoring "stopped" until it's no longer overloaded on API
    return @syncState != Account.SYNC_STATE_RUNNING &&
        @syncState != Account.SYNC_STATE_STOPPED

module.exports = Account
