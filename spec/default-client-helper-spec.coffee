_ = require 'underscore'
proxyquire = require 'proxyquire'

stubDefaultsJSON = null
execHitory = []

ChildProcess =
  exec: (command, callback) ->
    execHitory.push(arguments)
    callback(null, '', null)

fs =
  exists: (path, callback) ->
    callback(true)
  readFile: (path, callback) ->
    callback(null, JSON.stringify(stubDefaultsJSON))
  readFileSync: (path) ->
    JSON.stringify(stubDefaultsJSON)
  writeFileSync: (path) ->
    null
  unlink: (path, callback) ->
    callback(null) if callback

DefaultClientHelper = proxyquire "../src/default-client-helper",
  "child_process": ChildProcess
  "fs": fs

describe "DefaultClientHelper", ->
  beforeEach ->
    stubDefaultsJSON = [
      {
          LSHandlerRoleAll: 'com.apple.dt.xcode',
          LSHandlerURLScheme: 'xcdoc'
      },
      {
          LSHandlerRoleAll: 'com.fournova.tower',
          LSHandlerURLScheme: 'github-mac'
      },
      {
          LSHandlerRoleAll: 'com.fournova.tower',
          LSHandlerURLScheme: 'sourcetree'
      },
      {
          LSHandlerRoleAll: 'com.google.chrome',
          LSHandlerURLScheme: 'http'
      },
      {
          LSHandlerRoleAll: 'com.google.chrome',
          LSHandlerURLScheme: 'https'
      },
      {
          LSHandlerContentType: 'public.html',
          LSHandlerRoleViewer: 'com.google.chrome'
      },
      {
          LSHandlerContentType: 'public.url',
          LSHandlerRoleViewer: 'com.google.chrome'
      },
      {
          LSHandlerContentType: 'com.apple.ical.backup',
          LSHandlerRoleAll: 'com.apple.ical'
      },
      {
          LSHandlerContentTag: 'icalevent',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.apple.ical'
      },
      {
          LSHandlerContentTag: 'icaltodo',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.apple.reminders'
      },
      {
          LSHandlerRoleAll: 'com.apple.ical',
          LSHandlerURLScheme: 'webcal'
      },
      {
          LSHandlerContentTag: 'coffee',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.sublimetext.2'
      },
      {
          LSHandlerRoleAll: 'com.apple.facetime',
          LSHandlerURLScheme: 'facetime'
      },
      {
          LSHandlerRoleAll: 'com.apple.dt.xcode',
          LSHandlerURLScheme: 'xcdevice'
      },
      {
          LSHandlerContentType: 'public.png',
          LSHandlerRoleAll: 'com.macromedia.fireworks'
      },
      {
          LSHandlerRoleAll: 'com.apple.dt.xcode',
          LSHandlerURLScheme: 'xcbot'
      },
      {
          LSHandlerRoleAll: 'com.microsoft.rdc.mac',
          LSHandlerURLScheme: 'rdp'
      },
      {
          LSHandlerContentTag: 'rdp',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.microsoft.rdc.mac'
      },
      {
          LSHandlerContentType: 'public.json',
          LSHandlerRoleAll: 'com.sublimetext.2'
      },
      {
          LSHandlerContentTag: 'cson',
          LSHandlerContentTagClass: 'public.filename-extension',
          LSHandlerRoleAll: 'com.sublimetext.2'
      },
      {
          LSHandlerRoleAll: 'com.apple.mail',
          LSHandlerURLScheme: 'mailto'
      }
    ]


  describe "DefaultClientHelperMac", ->
    beforeEach ->
      execHitory = []
      @helper = new DefaultClientHelper.Mac()

    describe "available", ->
      it "should return true", ->
        expect(@helper.available()).toEqual(true)

    describe "readDefaults", ->

    describe "writeDefaults", ->
      it "should `lsregister` to reload defaults after saving them", ->
        callback = jasmine.createSpy('callback')
        @helper.writeDefaults(stubDefaultsJSON, callback)
        callback.callCount is 1
        command = execHitory[2][0]
        expect(command).toBe("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user")

    describe "isRegisteredForURLScheme", ->
      it "should require a callback is provided", ->
        expect( -> @helper.isRegisteredForURLScheme('mailto')).toThrow()

      it "should return true if a matching `LSHandlerURLScheme` record exists for the bundle identifier", ->
        spyOn(@helper, 'readDefaults').andCallFake (callback) ->
          callback([{
            "LSHandlerRoleAll": "com.apple.dt.xcode",
            "LSHandlerURLScheme": "xcdoc"
          }, {
            "LSHandlerContentTag": "cson",
            "LSHandlerContentTagClass": "public.filename-extension",
            "LSHandlerRoleAll": "com.sublimetext.2"
          }, {
            "LSHandlerRoleAll": "com.nylas.nylas-mail",
            "LSHandlerURLScheme": "mailto"
          }])
        @helper.isRegisteredForURLScheme 'mailto', (registered) ->
          expect(registered).toBe(true)

      it "should return false when other records exist for the bundle identifier but do not match", ->
        spyOn(@helper, 'readDefaults').andCallFake (callback) ->
          callback([{
            LSHandlerRoleAll: "com.apple.dt.xcode",
            LSHandlerURLScheme: "xcdoc"
          },{
            LSHandlerContentTag: "cson",
            LSHandlerContentTagClass: "public.filename-extension",
            LSHandlerRoleAll: "com.sublimetext.2"
          },{
            LSHandlerRoleAll: "com.nylas.nylas-mail",
            LSHandlerURLScheme: "atom"
          }])
        @helper.isRegisteredForURLScheme 'mailto', (registered) ->
          expect(registered).toBe(false)

      it "should return false if another bundle identifier is registered for the `LSHandlerURLScheme`", ->
        spyOn(@helper, 'readDefaults').andCallFake (callback) ->
          callback([{
            LSHandlerRoleAll: "com.apple.dt.xcode",
            LSHandlerURLScheme: "xcdoc"
          },{
            LSHandlerContentTag: "cson",
            LSHandlerContentTagClass: "public.filename-extension",
            LSHandlerRoleAll: "com.sublimetext.2"
          },{
            LSHandlerRoleAll: "com.apple.mail",
            LSHandlerURLScheme: "mailto"
          }])
        @helper.isRegisteredForURLScheme 'mailto', (registered) ->
          expect(registered).toBe(false)

    describe "registerForURLScheme", ->
      it "should remove any existing records for the `LSHandlerURLScheme`", ->
        @helper.registerForURLScheme 'mailto', =>
          @helper.readDefaults (values) ->
            expect(JSON.stringify(values).indexOf('com.apple.mail')).toBe(-1)

      it "should add a record for the `LSHandlerURLScheme` and the app's bundle identifier", ->
        @helper.registerForURLScheme 'mailto', =>
          @helper.readDefaults (defaults) ->
            match = _.find defaults, (d) ->
              d.LSHandlerURLScheme is 'mailto' and d.LSHandlerRoleAll is 'com.nylas.nylas-mail'
            expect(match).not.toBe(null)

      it "should write the new defaults", ->
        spyOn(@helper, 'readDefaults').andCallFake (callback) ->
          callback([{
            LSHandlerRoleAll: "com.apple.dt.xcode",
            LSHandlerURLScheme: "xcdoc"
          }])
        spyOn(@helper, 'writeDefaults')
        @helper.registerForURLScheme('mailto')
        expect(@helper.writeDefaults).toHaveBeenCalled()
