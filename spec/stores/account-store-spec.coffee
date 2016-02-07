_ = require 'underscore'
AccountStore = require '../../src/flux/stores/account-store'
Account = require '../../src/flux/models/account'
Actions = require '../../src/flux/actions'

describe "AccountStore", ->
  beforeEach ->
    @instance = null
    @constructor = AccountStore.constructor

  afterEach ->
    @instance.stopListeningToAll()

  it "should initialize using data saved in config", ->
    accounts =
      [{
        "id": "123",
        "client_id" : 'local-4f9d476a-c173',
        "server_id" : '123',
        "email_address":"bengotow@gmail.com",
        "object":"account"
        "organization_unit": "label"
      },{
        "id": "1234",
        "client_id" : 'local-4f9d476a-c175',
        "server_id" : '1234',
        "email_address":"ben@nylas.com",
        "object":"account"
        "organization_unit": "label"
      }]

    spyOn(NylasEnv.config, 'get').andCallFake (key) ->
      return accounts if key is 'nylas.accounts'
      return null
    @instance = new @constructor

    expect(@instance.accounts()).toEqual([
      (new Account).fromJSON(accounts[0]),
      (new Account).fromJSON(accounts[1])
    ])

  describe "accountForEmail", ->
    beforeEach ->
      @instance = new @constructor
      @ac1 = new Account emailAddress: 'juan@nylas.com', aliases: []
      @ac2 = new Account emailAddress: 'juan@gmail.com', aliases: ['Juan <juanchis@gmail.com>']
      @ac3 = new Account emailAddress: 'jackie@columbia.edu', aliases: ['Jackie Luo <jacqueline.luo@columbia.edu>']
      @instance._accounts = [@ac1, @ac2, @ac3]

    it 'returns correct account when no alises present', ->
      expect(@instance.accountForEmail('juan@nylas.com')).toEqual @ac1

    it 'returns correct account when alias is used', ->
      expect(@instance.accountForEmail('juanchis@gmail.com')).toEqual @ac2
      expect(@instance.accountForEmail('jacqueline.luo@columbia.edu')).toEqual @ac3

  describe "adding account from json", ->
    beforeEach ->
      spyOn(NylasEnv.config, "set")
      @json =
        "id": "1234",
        "client_id" : 'local-4f9d476a-c175',
        "server_id" : '1234',
        "email_address":"ben@nylas.com",
        "provider":"gmail",
        "object":"account"
        "auth_token": "auth-123"
        "organization_unit": "label"
      @instance = new @constructor
      spyOn(Actions, 'focusDefaultMailboxPerspectiveForAccounts')
      spyOn(@instance, "trigger")
      @instance.addAccountFromJSON(@json)

    it "sets the tokens", ->
      expect(@instance._tokens["1234"]).toBe "auth-123"

    it "sets the accounts", ->
      account = (new Account).fromJSON(@json)
      expect(@instance._accounts.length).toBe 1
      expect(@instance._accounts[0]).toEqual account

    it "saves the config", ->
      expect(NylasEnv.config.save).toHaveBeenCalled()
      expect(NylasEnv.config.set.calls.length).toBe 2

    it "selects the account", ->
      expect(Actions.focusDefaultMailboxPerspectiveForAccounts).toHaveBeenCalledWith(["1234"])

    it "triggers", ->
      expect(@instance.trigger).toHaveBeenCalled()
