child_process = require 'child_process'
path = require 'path'

_ = require 'underscore'
async = require 'async'
fs = require 'fs-plus'
GitHub = require 'github-releases'
request = require 'request'

grunt = null

token = process.env.N1_DEPLOY_ACCESS_TOKEN
defaultHeaders =
  Authorization: "token #{token}"
  'User-Agent': 'N1-Travis'

module.exports = (gruntObject) ->
  grunt = gruntObject
  {cp} = require('./task-helpers')(grunt)

  grunt.registerTask 'publish-build', 'Publish the built app', ->
    tasks = []
    tasks.push('upload-assets')
    grunt.task.run(tasks)

  grunt.registerTask 'upload-assets', 'Upload the assets to a GitHub release', ->
    doneCallback = @async()
    startTime = Date.now()
    done = (args...) ->
      elapsedTime = Math.round((Date.now() - startTime) / 100) / 10
      grunt.log.ok("Upload time: #{elapsedTime}s")
      doneCallback(args...)

    unless token
      return done(new Error('N1_DEPLOY_ACCESS_TOKEN environment variable not set'))

    buildDir = grunt.config.get('nylasGruntConfig.buildDir')
    assets = getAssets()

    zipAssets buildDir, assets, (error) ->
      return done(error) if error?
      getN1DraftRelease 'master', (error, release) ->
        return done(error) if error?
        assetNames = (asset.assetName for asset in assets)
        deleteExistingAssets release, assetNames, (error) ->
          return done(error) if error?
          uploadAssets(release, buildDir, assets, done)

getAssets = ->
  {cp} = require('./task-helpers')(grunt)

  {version} = grunt.file.readJSON('package.json')
  buildDir = grunt.config.get('nylasGruntConfig.buildDir')
  appName = grunt.config.get('nylasGruntConfig.appName')
  appFileName = grunt.config.get('nylasGruntConfig.appFileName')

  switch process.platform
    when 'darwin'
      dmgName = "#{appName.split('.')[0]}.dmg"

      [
        {assetName: "N1-#{version}-mac.zip", sourcePath: appName}
        {assetName: "N1-#{version}-mac-symbols.zip", sourcePath: 'Nylas.breakpad.syms'}
        {assetName: "N1-#{version}.dmg", sourcePath: dmgName}
      ]
    when 'win32'
      assets = [{assetName: "N1-#{version}-windows.zip", sourcePath: appName}]
      for squirrelAsset in ["N1-#{version}-Setup.exe", 'RELEASES', "N1-#{version}-full.nupkg", "N1-#{version}-delta.nupkg"]
        cp path.join(buildDir, 'installer', squirrelAsset), path.join(buildDir, squirrelAsset)
        assets.push({assetName: squirrelAsset, sourcePath: assetName})
      assets
    when 'linux'
      if process.arch is 'ia32'
        arch = 'i386'
      else
        arch = 'amd64'

      assets = []

      # Check for a Debian build
      sourcePath = "#{buildDir}/#{appFileName}-#{version}-#{arch}.deb"
      assetName = "N1-#{version}-#{arch}.deb"
      grunt.log.ok "Debian Deb: #{sourcePath}"
      if fs.isFileSync(sourcePath)
        assets.push {assetName, sourcePath}
        cp sourcePath, path.join(buildDir, assetName)

      # Check for a Fedora build
      rpmName = fs.readdirSync("#{buildDir}/rpm")[0]
      sourcePath = "#{buildDir}/rpm/#{rpmName}"
      grunt.log.ok "Fedora RPM: #{sourcePath}"
      if fs.isFileSync(sourcePath)
        if process.arch is 'ia32'
          arch = 'i386'
        else
          arch = 'x86_64'
        assetName = "N1-#{version}-#{arch}.rpm"

        assets.push {assetName, sourcePath}
        cp sourcePath, path.join(buildDir, assetName)

      assets

logError = (message, error, details) ->
  grunt.log.error(message)
  grunt.log.error(error.message ? error) if error?
  grunt.log.error(require('util').inspect(details)) if details

zipAssets = (buildDir, assets, callback) ->
  zip = (directory, sourcePath, assetName, callback) ->
    if process.platform is 'win32'
      zipCommand = "C:/psmodules/7z.exe a -r #{assetName} \"#{sourcePath}\""
    else
      zipCommand = "zip -r --symlinks '#{assetName}' '#{sourcePath}'"
    options = {cwd: directory, maxBuffer: Infinity}
    child_process.exec zipCommand, options, (error, stdout, stderr) ->
      logError("Zipping #{sourcePath} failed", error, stderr) if error?
      callback(error)

  tasks = []
  for {assetName, sourcePath} in assets when path.extname(assetName) is '.zip'
    fs.removeSync(path.join(buildDir, assetName))
    tasks.push(zip.bind(this, buildDir, sourcePath, assetName))
  async.parallel(tasks, callback)

getN1DraftRelease = (branchName, callback) ->
  nylasRepo = new GitHub({repo: 'mbilker/N1', token})
  nylasRepo.getReleases {prerelease: false}, (error, releases=[]) ->
    if error?
      logError('Fetching mbilker/N1 releases failed', error, releases)
      callback(error)
    else
      [firstDraft] = releases.filter ({draft}) -> draft
      if firstDraft?
        options =
          uri: firstDraft.assets_url
          method: 'GET'
          headers: defaultHeaders
          json: true
        request options, (error, response, assets=[]) ->
          if error? or response.statusCode isnt 200
            logError('Fetching draft release assets failed', error, assets)
            callback(error ? new Error(response.statusCode))
          else
            firstDraft.assets = assets
            callback(null, firstDraft)
      else
        createN1DraftRelease(branchName, callback)

createN1DraftRelease = (branchName, callback) ->
  {version} = require('../../package.json')
  options =
    uri: 'https://api.github.com/repos/mbilker/N1/releases'
    method: 'POST'
    headers: defaultHeaders
    json:
      tag_name: "#{version}"
      prerelease: false
      target_commitish: branchName
      name: "v#{version}"
      draft: true
      body: """
        ### Notable Changes

        * Something new
      """

  request options, (error, response, body='') ->
    if error? or response.statusCode isnt 201
      logError("Creating mbilker/N1 draft release failed", error, body)
      callback(error ? new Error(response.statusCode))
    else
      callback(null, body)

deleteRelease = (release) ->
  options =
    uri: release.url
    method: 'DELETE'
    headers: defaultHeaders
    json: true
  request options, (error, response, body='') ->
    if error? or response.statusCode isnt 204
      logError('Deleting release failed', error, body)

deleteExistingAssets = (release, assetNames, callback) ->
  [callback, assetNames] = [assetNames, callback] if not callback?

  deleteAsset = (url, callback) ->
    options =
      uri: url
      method: 'DELETE'
      headers: defaultHeaders
    request options, (error, response, body='') ->
      if error? or response.statusCode isnt 204
        logError('Deleting existing release asset failed', error, body)
        callback(error ? new Error(response.statusCode))
      else
        callback()

  tasks = []
  for asset in release.assets when not assetNames? or asset.name in assetNames
    tasks.push(deleteAsset.bind(this, asset.url))
  async.parallel(tasks, callback)

uploadAssets = (release, buildDir, assets, callback) ->
  uploadToReleases = (release, assetName, assetPath, callback) ->
    options =
      uri: release.upload_url.replace(/\{.*$/, "?name=#{assetName}")
      method: 'POST'
      headers: _.extend({
        'Content-Type': 'application/zip'
        'Content-Length': fs.getSizeSync(assetPath)
        }, defaultHeaders)

    assetRequest = request options, (error, response, body='') ->
      if error? or response.statusCode >= 400
        logError("Upload release asset #{assetName} to Releases failed", error, body)
        callback(error ? new Error(response.statusCode))
      else
        callback(null, release)

    fs.createReadStream(assetPath).pipe(assetRequest)

  tasks = []
  for {assetName} in assets
    assetPath = path.join(buildDir, assetName)
    tasks.push(uploadToReleases.bind(this, release, assetName, assetPath))
  async.parallel(tasks, callback)
