path = require 'path'

{$, $$} = require '../src/space-pen-extensions'
fs = require 'fs-plus'
temp = require 'temp'

ThemeManager = require '../src/theme-manager'
Package = require '../src/package'

describe "ThemeManager", ->
  themeManager = null
  resourcePath = NylasEnv.getLoadSettings().resourcePath
  configDirPath = NylasEnv.getConfigDirPath()

  beforeEach ->
    spyOn(console, "log")
    spyOn(console, "warn")
    spyOn(console, "error")
    theme_dir = path.resolve(__dirname, '../internal_packages')

    # Don't load ALL of our packages. Some packages may do very expensive
    # and asynchronous things on require, including hitting the database.
    packagePaths = [
      path.resolve(__dirname, '../internal_packages/ui-light')
      path.resolve(__dirname, '../internal_packages/ui-dark')
    ]
    spyOn(NylasEnv.packages, "getAvailablePackagePaths").andReturn packagePaths
    NylasEnv.packages.packageDirPaths.unshift(theme_dir)
    themeManager = new ThemeManager({packageManager: NylasEnv.packages, resourcePath, configDirPath})

  afterEach ->
    themeManager.deactivateThemes()

  describe "theme getters and setters", ->
    beforeEach ->
      jasmine.snapshotDeprecations()
      NylasEnv.packages.loadPackages()

    afterEach ->
      jasmine.restoreDeprecationsSnapshot()

    it 'getLoadedThemes get all the loaded themes', ->
      themes = themeManager.getLoadedThemes()
      expect(themes.length).toEqual(2)

    it 'getActiveThemes get all the active themes', ->
      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        names = NylasEnv.config.get('core.themes')
        expect(names.length).toBeGreaterThan(0)
        themes = themeManager.getActiveThemes()
        expect(themes).toHaveLength(names.length)

  describe "when the core.themes config value contains invalid entry", ->
    it "ignores theme", ->
      NylasEnv.config.set 'core.themes', [
        'ui-light'
        null
        undefined
        ''
        false
        4
        {}
        []
        'ui-dark'
      ]

      expect(themeManager.getEnabledThemeNames()).toEqual ['ui-dark', 'ui-light']

  describe "::getImportPaths()", ->
    it "returns the theme directories before the themes are loaded", ->
      NylasEnv.config.set('core.themes', ['theme-with-index-less', 'ui-dark', 'ui-light'])

      paths = themeManager.getImportPaths()

      # syntax theme is not a dir at this time, so only two.
      expect(paths.length).toBe 2
      expect(paths[0]).toContain 'ui-light'
      expect(paths[1]).toContain 'ui-dark'

    it "ignores themes that cannot be resolved to a directory", ->
      NylasEnv.config.set('core.themes', ['definitely-not-a-theme'])
      expect(-> themeManager.getImportPaths()).not.toThrow()

  describe "when the core.themes config value changes", ->
    it "add/removes stylesheets to reflect the new config value", ->
      themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
      spyOn(NylasEnv.styles, 'getUserStyleSheetPath').andCallFake -> null

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        didChangeActiveThemesHandler.reset()
        NylasEnv.config.set('core.themes', [])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect($('style.theme')).toHaveLength 0
        NylasEnv.config.set('core.themes', ['ui-dark'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect($('style[priority=1]')).toHaveLength 1
        expect($('style[priority=1]:eq(0)').attr('source-path')).toMatch /ui-dark/
        NylasEnv.config.set('core.themes', ['ui-light', 'ui-dark'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect($('style[priority=1]')).toHaveLength 2
        expect($('style[priority=1]:eq(0)').attr('source-path')).toMatch /ui-dark/
        expect($('style[priority=1]:eq(1)').attr('source-path')).toMatch /ui-light/
        NylasEnv.config.set('core.themes', [])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect($('style[priority=1]')).toHaveLength(1)
        # ui-dark has an directory path, the syntax one doesn't
        NylasEnv.config.set('core.themes', ['theme-with-index-less', 'ui-light'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        expect($('style[priority=1]')).toHaveLength 2
        importPaths = themeManager.getImportPaths()
        expect(importPaths.length).toBe 1
        expect(importPaths[0]).toContain 'ui-light'

    it 'adds theme-* classes to the workspace for each active theme', ->
      workspaceElement = document.createElement('nylas-workspace')
      jasmine.attachToDOM(workspaceElement)

      themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        expect(workspaceElement).toHaveClass 'theme-ui-light'

        themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
        NylasEnv.config.set('core.themes', ['theme-with-ui-variables'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount > 0

      runs ->
        # `theme-` twice as it prefixes the name with `theme-`
        expect(workspaceElement).toHaveClass 'theme-theme-with-ui-variables'
        expect(workspaceElement).not.toHaveClass 'theme-ui-dark'

  describe "when a theme fails to load", ->
    it "logs a warning", ->
      NylasEnv.packages.activatePackage('a-theme-that-will-not-be-found')
      expect(console.warn.callCount).toBe 1
      expect(console.warn.argsForCall[0][0]).toContain "Could not resolve 'a-theme-that-will-not-be-found'"

  describe "::requireStylesheet(path)", ->
    beforeEach ->
      jasmine.snapshotDeprecations()

    afterEach ->
      jasmine.restoreDeprecationsSnapshot()

    it "synchronously loads css at the given path and installs a style tag for it in the head", ->
      NylasEnv.styles.onDidAddStyleElement styleElementAddedHandler = jasmine.createSpy("styleElementAddedHandler")
      themeManager.onDidChangeStylesheets stylesheetsChangedHandler = jasmine.createSpy("stylesheetsChangedHandler")
      themeManager.onDidAddStylesheet stylesheetAddedHandler = jasmine.createSpy("stylesheetAddedHandler")

      cssPath = path.join(__dirname, 'fixtures', 'css.css')
      lengthBefore = $('head style').length

      themeManager.requireStylesheet(cssPath)
      expect($('head style').length).toBe lengthBefore + 1

      expect(styleElementAddedHandler).toHaveBeenCalled()
      expect(stylesheetAddedHandler).toHaveBeenCalled()
      expect(stylesheetsChangedHandler).toHaveBeenCalled()

      element = $('head style[source-path*="css.css"]')
      expect(element.attr('source-path')).toBe themeManager.stringToId(cssPath)
      expect(element.text()).toBe fs.readFileSync(cssPath, 'utf8')
      expect(element[0].sheet).toBe stylesheetAddedHandler.argsForCall[0][0]

      # doesn't append twice
      styleElementAddedHandler.reset()
      themeManager.requireStylesheet(cssPath)
      expect($('head style').length).toBe lengthBefore + 1
      expect(styleElementAddedHandler).not.toHaveBeenCalled()

      $('head style[id*="css.css"]').remove()

    it "synchronously loads and parses less files at the given path and installs a style tag for it in the head", ->
      lessPath = path.join(__dirname, 'fixtures', 'sample.less')
      lengthBefore = $('head style').length
      themeManager.requireStylesheet(lessPath)
      expect($('head style').length).toBe lengthBefore + 1

      element = $('head style[source-path*="sample.less"]')
      expect(element.attr('source-path')).toBe themeManager.stringToId(lessPath)
      expect(element.text()).toBe """
      #header {
        color: #4d926f;
      }
      h2 {
        color: #4d926f;
      }

      """

      # doesn't append twice
      themeManager.requireStylesheet(lessPath)
      expect($('head style').length).toBe lengthBefore + 1
      $('head style[id*="sample.less"]').remove()

    it "supports requiring css and less stylesheets without an explicit extension", ->
      themeManager.requireStylesheet path.join(__dirname, 'fixtures', 'css')
      expect($('head style[source-path*="css.css"]').attr('source-path')).toBe themeManager.stringToId(path.join(__dirname, 'fixtures', 'css.css'))
      themeManager.requireStylesheet path.join(__dirname, 'fixtures', 'sample')
      expect($('head style[source-path*="sample.less"]').attr('source-path')).toBe themeManager.stringToId(path.join(__dirname, 'fixtures', 'sample.less'))

      $('head style[id*="css.css"]').remove()
      $('head style[id*="sample.less"]').remove()

    it "returns a disposable allowing styles applied by the given path to be removed", ->
      cssPath = require.resolve('./fixtures/css.css')

      expect($(document.body).css('font-weight')).not.toBe("bold")
      disposable = themeManager.requireStylesheet(cssPath)
      expect($(document.body).css('font-weight')).toBe("bold")

      NylasEnv.styles.onDidRemoveStyleElement styleElementRemovedHandler = jasmine.createSpy("styleElementRemovedHandler")
      themeManager.onDidRemoveStylesheet stylesheetRemovedHandler = jasmine.createSpy("stylesheetRemovedHandler")
      themeManager.onDidChangeStylesheets stylesheetsChangedHandler = jasmine.createSpy("stylesheetsChangedHandler")

      disposable.dispose()

      expect($(document.body).css('font-weight')).not.toBe("bold")

      expect(styleElementRemovedHandler).toHaveBeenCalled()
      expect(stylesheetRemovedHandler).toHaveBeenCalled()
      stylesheet = stylesheetRemovedHandler.argsForCall[0][0]
      expect(stylesheet instanceof CSSStyleSheet).toBe true
      expect(stylesheet.cssRules[0].selectorText).toBe 'body'

      expect(stylesheetsChangedHandler).toHaveBeenCalled()

  describe "base style sheet loading", ->
    workspaceElement = null
    beforeEach ->
      workspaceElement = document.createElement('nylas-workspace')
      workspaceElement.appendChild document.createElement('nylas-theme-wrap')
      jasmine.attachToDOM(workspaceElement)

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
        additionalDelay = null
        @waitsForThemeRefresh = ->
          waitsFor ->
            # We need to wait a bit of additional time for the browser to actually
            # apply the CSS to the elements we check.
            if didChangeActiveThemesHandler.callCount > 0
              additionalDelay ?= Date.now() + 100
              return Date.now() > additionalDelay
            return false

    it "loads the correct values from the theme's ui-variables file", ->
      NylasEnv.config.set('core.themes', ['theme-with-ui-variables'])

      @waitsForThemeRefresh()
      runs ->
        # an override loaded in the base css of theme-with-ui-variables
        expect(getComputedStyle(workspaceElement)["background-color"]).toBe "rgb(0, 0, 255)"

        # a value that is not overridden in the theme
        expect($("nylas-theme-wrap").css("padding-top")).toBe "150px"
        expect($("nylas-theme-wrap").css("padding-right")).toBe "150px"
        expect($("nylas-theme-wrap").css("padding-bottom")).toBe "150px"

    describe "when there is a theme with incomplete variables", ->
      it "loads the correct values from the fallback ui-variables", ->
        NylasEnv.config.set('core.themes', ['theme-with-incomplete-ui-variables'])

        @waitsForThemeRefresh()
        runs ->
          # an override loaded in the base css of theme-with-incomplete-ui-variables
          expect(getComputedStyle(workspaceElement)["background-color"]).toBe "rgb(0, 0, 255)"

          # a value that is not overridden in the theme
          expect($("nylas-theme-wrap").css("background-color")).toBe "rgb(152, 123, 0)"

  describe "user stylesheet", ->
    userStylesheetPath = null
    beforeEach ->
      userStylesheetPath = path.join(temp.mkdirSync("nylas-spec"), 'styles.less')
      fs.writeFileSync(userStylesheetPath, 'body {border-style: dotted !important;}')
      spyOn(NylasEnv.styles, 'getUserStyleSheetPath').andReturn userStylesheetPath

    describe "when the user stylesheet changes", ->
      beforeEach ->
        jasmine.snapshotDeprecations()

      afterEach ->
        jasmine.restoreDeprecationsSnapshot()

      it "reloads it", ->
        [styleElementAddedHandler, styleElementRemovedHandler] = []
        [stylesheetRemovedHandler, stylesheetAddedHandler, stylesheetsChangedHandler] = []

        waitsForPromise ->
          themeManager.activateThemes().then ->

            runs ->
              NylasEnv.styles.onDidRemoveStyleElement styleElementRemovedHandler = jasmine.createSpy("styleElementRemovedHandler")
              NylasEnv.styles.onDidAddStyleElement styleElementAddedHandler = jasmine.createSpy("styleElementAddedHandler")

              themeManager.onDidChangeStylesheets stylesheetsChangedHandler = jasmine.createSpy("stylesheetsChangedHandler")
              themeManager.onDidRemoveStylesheet stylesheetRemovedHandler = jasmine.createSpy("stylesheetRemovedHandler")
              themeManager.onDidAddStylesheet stylesheetAddedHandler = jasmine.createSpy("stylesheetAddedHandler")
              spyOn(themeManager, 'loadUserStylesheet').andCallThrough()

              expect($(document.body).css('border-style')).toBe 'dotted'
              fs.writeFileSync(userStylesheetPath, 'body {border-style: dashed}')

            waitsFor ->
              themeManager.loadUserStylesheet.callCount is 1

            runs ->
              expect($(document.body).css('border-style')).toBe 'dashed'

              expect(styleElementRemovedHandler).toHaveBeenCalled()
              expect(styleElementRemovedHandler.argsForCall[0][0].textContent).toContain 'dotted'
              expect(stylesheetRemovedHandler).toHaveBeenCalled()

              match = null
              for rule in stylesheetRemovedHandler.argsForCall[0][0].cssRules
                match = rule if rule.selectorText is 'body'
              expect(match.style.border).toBe 'dotted'

              expect(styleElementAddedHandler).toHaveBeenCalled()
              expect(styleElementAddedHandler.argsForCall[0][0].textContent).toContain 'dashed'
              expect(stylesheetAddedHandler).toHaveBeenCalled()
              match = null
              for rule in stylesheetAddedHandler.argsForCall[0][0].cssRules
                match = rule if rule.selectorText is 'body'
              expect(match.style.border).toBe 'dashed'

              expect(stylesheetsChangedHandler).toHaveBeenCalled()

              styleElementRemovedHandler.reset()
              stylesheetRemovedHandler.reset()
              stylesheetsChangedHandler.reset()
              fs.removeSync(userStylesheetPath)

            waitsFor ->
              themeManager.loadUserStylesheet.callCount is 2

            runs ->
              expect(styleElementRemovedHandler).toHaveBeenCalled()
              expect(styleElementRemovedHandler.argsForCall[0][0].textContent).toContain 'dashed'
              expect(stylesheetRemovedHandler).toHaveBeenCalled()

            waitsFor ->
              match = null
              for rule in stylesheetRemovedHandler.argsForCall[0][0].cssRules
                match = rule if rule.selectorText is 'body'
              match.style.border is 'dashed' and $(document.body).css('border-style') is 'none'

            runs ->
              expect(stylesheetsChangedHandler).toHaveBeenCalled()

    describe "when there is an error reading the stylesheet", ->
      addErrorHandler = null
      beforeEach ->
        themeManager.loadUserStylesheet()
        spyOn(themeManager.lessCache, 'cssForFile').andCallFake ->
          throw new Error('EACCES permission denied "styles.less"')

      it "creates an error notification and does not add the stylesheet", ->
        themeManager.loadUserStylesheet()
        expect(console.error).toHaveBeenCalled()
        note = console.error.mostRecentCall.args[0]
        expect(note).toEqual 'EACCES permission denied "styles.less"'
        expect(NylasEnv.styles.styleElementsBySourcePath[NylasEnv.styles.getUserStyleSheetPath()]).toBeUndefined()

    describe "when there is an error watching the user stylesheet", ->
      addErrorHandler = null
      beforeEach ->
        {File} = require 'pathwatcher'
        spyOn(File::, 'onDidChange').andCallFake (event) ->
          throw new Error('Unable to watch path')
        spyOn(themeManager, 'loadStylesheet').andReturn ''

      it "creates an error notification", ->
        themeManager.loadUserStylesheet()
        expect(console.error).toHaveBeenCalled()
        note = console.error.mostRecentCall.args[0]
        expect(note).toEqual 'Error: Unable to watch path'

  describe "when a non-existent theme is present in the config", ->
    beforeEach ->
      NylasEnv.config.set('core.themes', ['non-existent-dark-ui'])

      waitsForPromise ->
        themeManager.activateThemes()

    it 'uses the default theme and logs a warning', ->
      activeThemeNames = themeManager.getActiveThemeNames()
      expect(console.warn.callCount).toBe(1)
      expect(activeThemeNames.length).toBe(1)
      expect(activeThemeNames).toContain('ui-light')

  describe "when in safe mode", ->
    beforeEach ->
      themeManager = new ThemeManager({packageManager: NylasEnv.packages, resourcePath, configDirPath, safeMode: true})

    describe 'when the enabled UI theme is bundled with N1', ->
      beforeEach ->
        NylasEnv.config.set('core.themes', ['ui-light'])

        waitsForPromise ->
          themeManager.activateThemes()

      it 'uses the enabled themes', ->
        activeThemeNames = themeManager.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(1)
        expect(activeThemeNames).toContain('ui-light')

    describe 'when the enabled UI theme is not bundled with N1', ->
      beforeEach ->
        NylasEnv.config.set('core.themes', ['installed-dark-ui'])

        waitsForPromise ->
          themeManager.activateThemes()

      it 'uses the default UI theme', ->
        activeThemeNames = themeManager.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(1)
        expect(activeThemeNames).toContain('ui-light')

    describe 'when the enabled UI theme is not bundled with N1', ->
      beforeEach ->
        NylasEnv.config.set('core.themes', ['installed-dark-ui'])

        waitsForPromise ->
          themeManager.activateThemes()

      it 'uses the default UI theme', ->
        activeThemeNames = themeManager.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(1)
        expect(activeThemeNames).toContain('ui-light')
