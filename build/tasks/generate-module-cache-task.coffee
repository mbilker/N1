path = require 'path'
fs = require 'fs-plus'

module.exports = (grunt) ->
  grunt.registerTask 'generate-module-cache', 'Generate a module cache for all core modules and packages', ->
    ModuleCache = require '../../src/module-cache'
    appDir = grunt.config.get('nylasGruntConfig.appDir')

    {packageDependencies} = grunt.file.readJSON('package.json')

    for packageName, version of packageDependencies
      ModuleCache.create(path.join(appDir, 'node_modules', packageName))

    ModuleCache.create(appDir)

    metadata = grunt.file.readJSON(path.join(appDir, 'package.json'))

    metadata._nylasModuleCache.folders.forEach (folder) ->
      if '' in folder.paths
        folder.paths = [
          ''
          'spec'
          'src'
          'src/browser'
          'static'
        ]

    grunt.file.write(path.join(appDir, 'package.json'), JSON.stringify(metadata))
