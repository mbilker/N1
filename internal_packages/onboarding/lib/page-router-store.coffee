OnboardingActions = require './onboarding-actions'
TokenAuthAPI = require './token-auth-api'
{AccountStore, Actions} = require 'nylas-exports'
{ipcRenderer} = require 'electron'
NylasStore = require 'nylas-store'

return unless NylasEnv.getWindowType() is "onboarding"

class PageRouterStore extends NylasStore
  constructor: ->
    NylasEnv.onWindowPropsReceived @_onWindowPropsChanged

    @_page = NylasEnv.getWindowProps().page ? ''
    @_pageData = NylasEnv.getWindowProps().pageData ? {}
    @_pageStack = [{page: @_page, pageData: @_pageData}]

    @_checkTokenAuthStatus()
    @listenTo OnboardingActions.moveToPreviousPage, @_onMoveToPreviousPage
    @listenTo OnboardingActions.moveToPage, @_onMoveToPage
    @listenTo OnboardingActions.closeWindow, @_onCloseWindow
    @listenTo OnboardingActions.accountJSONReceived, @_onAccountJSONReceived
    @listenTo OnboardingActions.retryCheckTokenAuthStatus, @_checkTokenAuthStatus

  _onAccountJSONReceived: (json) =>
    isFirstAccount = AccountStore.accounts().length is 0
    AccountStore.addAccountFromJSON(json)
    ipcRenderer.send('new-account-added')
    NylasEnv.displayWindow()
    if isFirstAccount
      @_onMoveToPage('initial-preferences', {account: json})
      Actions.recordUserEvent('First Account Linked')
      @openWelcomePage()
    else
      # When account JSON is received, we want to notify external services
      # that it succeeded. Unfortunately in this case we're likely to
      # close the window before those requests can be made. We add a short
      # delay here to ensure that any pending requests have a chance to
      # clear before the window closes.
      setTimeout ->
        ipcRenderer.send('account-setup-successful')
      , 100

  _onWindowPropsChanged: ({page, pageData}={}) =>
    @_onMoveToPage(page, pageData)

  openWelcomePage: ->
    encode = (str) -> encodeURIComponent(new Buffer(str).toString('base64'))
    account = AccountStore.accounts()[0]
    n1_id = encode(NylasEnv.config.get("updateIdentity"))
    email = encode(account.emailAddress)
    provider = encode(account.provider)
    accountId = encode(account.id)
    params = "?n=#{n1_id}&e=#{email}&p=#{provider}&a=#{accountId}"
    {shell} = require('electron')
    shell.openExternal("https://nylas.com/welcome#{params}", activate: false)

  page: -> @_page

  pageData: -> @_pageData

  tokenAuthEnabled: -> @_tokenAuthEnabled

  tokenAuthEnabledError: -> @_tokenAuthEnabledError

  connectType: ->
    @_connectType

  _onMoveToPreviousPage: ->
    current = @_pageStack.pop()
    prev = @_pageStack.pop()
    @_onMoveToPage(prev.page, prev.pageData)

  _onMoveToPage: (page, pageData={}) ->
    @_pageStack.push({page, pageData})
    @_page = page
    @_pageData = pageData
    @trigger()

  _onCloseWindow: ->
    isFirstAccount = AccountStore.accounts().length is 0
    if isFirstAccount
      NylasEnv.quit()
    else
      NylasEnv.close()

  _checkTokenAuthStatus: ->
    @_tokenAuthEnabled = "unknown"
    @_tokenAuthEnabledError = null
    @trigger()

    TokenAuthAPI.request
      path: "/status/"
      returnsModel: false
      timeout: 10000
      success: (json) =>
        if json.restricted
          @_tokenAuthEnabled = "yes"
        else
          @_tokenAuthEnabled = "no"

        if @_tokenAuthEnabled is "no" and @_page is 'token-auth'
          @_onMoveToPage("account-choose")
        else
          @trigger()

      error: (err) =>
        if err.statusCode is 404
          err.message = "Sorry, we could not reach the Nylas API. Please try again."
        @_tokenAuthEnabledError = err.message
        @trigger()

module.exports = new PageRouterStore()
