kb = require '../lib/keybase'

describe "keybase lib", ->
  # TODO stub keybase calls?
  it "should be able to fetch an account by username", ->
    @err = null
    @them = null
    runs( =>
      kb.getUser('dakota', 'usernames', (err, them) =>
        console.log err
        @err = err
        @them = them
      )
    )
    waitsFor((=> @them? or @err?), 2000)
    runs( =>
      expect(@err).toEqual(null)
      expect(@them?[0].components.username.val).toEqual("dakota")
    )

  it "should be able to fetch an account by key fingerprint", ->
    @err = null
    @them = null
    runs( =>
      kb.getUser('7FA5A43BBF2BAD1845C8D0E8145FCCD989968E3B', 'key_fingerprint', (err, them) =>
        @err = err
        @them = them
      )
    )
    waitsFor((=> @them? or @err?), 2000)
    runs( =>
      expect(@err).toEqual(null)
      expect(@them?[0].components.username.val).toEqual("dakota")
    )

  it "should be able to fetch a user's key", ->
    @err = null
    @key = null
    runs( =>
      kb.getKey('dakota', (err, key) =>
        @err = err
        @key = key
      )
    )
    waitsFor((=> @key? or @err?), 2000)
    runs( =>
      expect(@err).toEqual(null)
      expect(@key?.startsWith('-----BEGIN PGP PUBLIC KEY BLOCK-----'))
    )

  it "should be able to return an autocomplete query", ->
    @err = null
    @completions = null
    runs( =>
      kb.autocomplete('dakota', (err, completions) =>
        @err = err
        @completions = completions
      )
    )
    waitsFor((=> @completions? or @err?), 2000)
    runs( =>
      expect(@err).toEqual(null)
      expect(@completions[0].components.username.val).toEqual("dakota")
    )
