React = require 'react'
_ = require 'underscore'
{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI, Utils, Actions} = require 'nylas-exports'

OnboardingActions = require './onboarding-actions'
Providers = require './account-types'
url = require 'url'

class AccountChoosePage extends React.Component
  @displayName: "AccountChoosePage"

  constructor: (@props) ->
    @state =
      email: ""
      provider: ""

  componentWillUnmount: ->
    @_usub?()

  componentDidMount: ->
    if @props.pageData.provider
      providerData = _.findWhere(Providers, name: @props.pageData.provider)
      if providerData
        @_onChooseProvider(providerData)

  render: =>
    <div className="page account-choose">
      <div className="quit" onClick={ -> OnboardingActions.closeWindow() }>
        <RetinaImg name="onboarding-close.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>

      <div className="caption" style={marginTop: 33, marginBottom:25}>Select your email provider:</div>

      {@_renderProviders()}

    </div>

  _renderProviders: ->
    return Providers.map (provider) =>
      <div className={"provider "+provider.name} key={provider.name} onClick={=>@_onChooseProvider(provider)}>

        <div className="icon-container">
          <RetinaImg name={provider.icon} mode={RetinaImg.Mode.ContentPreserve} className="icon"/>
        </div>
        <span className="provider-name">{provider.displayName}</span>
      </div>

  _renderError: ->
    if @state.error
      <div className="alert alert-danger" role="alert">
        {@state.error}
      </div>
    else <div></div>

  _onEmailChange: (event) =>
    @setState email: event.target.value

  _onChooseProvider: (provider) =>
    Actions.recordUserEvent('Auth Flow Started', {
      provider: provider.name
    })

    if provider.name is 'gmail'
      # Show the "Sign in to Gmail" prompt for a moment before actually bouncing
      # to Gmail. (400msec animation + 200msec to read)
      _.delay =>
        @_onBounceToGmail(provider)
      , 600
    OnboardingActions.moveToPage("account-settings", {provider})

  _base64url: (buf) ->
    # Python-style urlsafe_b64encode
    buf.toString('base64')
      .replace(/\+/g, '-') # Convert '+' to '-'
      .replace(/\//g, '_') # Convert '/' to '_'

  _onBounceToGmail: (provider) =>
    crypto = require 'crypto'

    # Client key is used for polling. Requirements are that it not be guessable
    # and that it never collides with an active key (keys are active only between
    # initiating gmail auth and successfully requesting the account data once.
    provider.clientKey = @_base64url(crypto.randomBytes(40))

    # Encryption key is used to AES encrypt the account data during storage on the
    # server.
    provider.encryptionKey = crypto.randomBytes(24)
    provider.encryptionIv = crypto.randomBytes(16)
    code = NylasEnv.config.get('invitationCode') || ''
    state = [provider.clientKey,@_base64url(provider.encryptionKey),@_base64url(provider.encryptionIv),code].join(',')

    # Use a different app for production and development.
    env = NylasEnv.config.get('env') || 'production'
    google_client_id = '372024217839-cdsnrrqfr4d6b4gmlqepd7v0n0l0ip9q.apps.googleusercontent.com'
    if env != 'production'
      google_client_id = '529928329786-e5foulo1g9kiej2h9st9sb0f4dt96s6v.apps.googleusercontent.com'

    googleUrl = url.format({
      protocol: 'https'
      host: 'accounts.google.com/o/oauth2/auth'
      query:
        response_type: 'code'
        state: state
        client_id: google_client_id
        redirect_uri: "#{EdgehillAPI.APIRoot}/oauth/google/callback"
        access_type: 'offline'
        scope: 'https://www.googleapis.com/auth/userinfo.email \
            https://www.googleapis.com/auth/userinfo.profile \
            https://mail.google.com/ \
            https://www.google.com/m8/feeds \
            https://www.googleapis.com/auth/calendar'
        prompt: 'consent'
    })
    {shell} = require 'electron'
    shell.openExternal(googleUrl)

module.exports = AccountChoosePage
