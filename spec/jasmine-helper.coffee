fs = require 'fs'
{remote} = require 'electron'

module.exports.runSpecSuite = (specSuite, logFile, logErrors=true) ->
  window[key] = value for key, value of require './jasmine'

  {TerminalReporter} = require 'jasmine-tagged'

  disableFocusMethods() if process.env.JANKY_SHA1

  TimeReporter = require './time-reporter'
  timeReporter = new TimeReporter()

  logStream = fs.openSync(logFile, 'w') if logFile?
  log = (str) ->
    if logStream?
      fs.writeSync(logStream, str)
    else
      remote.process.stdout.write(str)

  if NylasEnv.getLoadSettings().showSpecsInWindow
    reporter = require './n1-spec-reporter'
  else if NylasEnv.getLoadSettings().exitWhenDone
    reporter = new TerminalReporter
      color: true
      print: (str) ->
        log(str)
      onComplete: (runner) ->
        fs.closeSync(logStream) if logStream?
        if process.env.JANKY_SHA1
          grim = require 'grim'
          grim.logDeprecations() if grim.getDeprecationsLength() > 0
        if runner.results().failedCount > 0
          NylasEnv.exit(1)
        else
          NylasEnv.exit(0)
  else
    reporter = require './n1-spec-reporter'

  NylasEnv.initialize()

  require specSuite

  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)
  jasmineEnv.addReporter(timeReporter)
  jasmineEnv.setIncludedTags([process.platform])

  div = document.createElement('div')
  div.id = 'jasmine-content'
  document.body.appendChild(div)

  jasmineEnv.execute()

disableFocusMethods = ->
  ['fdescribe', 'ffdescribe', 'fffdescribe', 'fit', 'ffit', 'fffit'].forEach (methodName) ->
    focusMethod = window[methodName]
    window[methodName] = (description) ->
      error = new Error('Focused spec is running on CI')
      focusMethod description, -> throw error
