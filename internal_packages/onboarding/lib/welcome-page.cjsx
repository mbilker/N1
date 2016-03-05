React = require 'react'
{shell} = require 'electron'
classnames = require 'classnames'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'
PageRouterStore = require './page-router-store'
OnboardingActions = require './onboarding-actions'

class WelcomePage extends React.Component
  @displayName: "WelcomePage"

  constructor: (@props) ->
    @state =
      step: 0
      lastStep: 0

  render: ->
    <div className="welcome-page page opaque">
      <div className="quit" onClick={ -> OnboardingActions.closeWindow() }>
        <RetinaImg name="onboarding-close.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>
      <div className="steps-container">{@_renderSteps()}</div>
      <div className="footer step-#{@state.step}">{@_renderButtons()}</div>
    </div>

  _renderButtons: ->
    buttons = []
    btnText = ""
    if @state.step is 0
      btnText = "Let’s get started"
    else if @state.step is 1
      btnText = "Continue"
    else if @state.step is 2
      btnText = "Get started"
    buttons.push <button key="next" className="btn btn-large btn-continue" onClick={@_onContinue}>{btnText}</button>
    return buttons

  _renderSteps: -> [
    @_renderStep0()
    @_renderStep1()
    @_renderStep2()
  ]

  _stepClass: (n) ->
    obj =
      "step-wrap": true
      "active": @state.step is n
    obj["step-#{n}-wrap"] = true
    className = classnames(obj)
    return className

  _renderStep0: ->
    <div className={@_stepClass(0)} key="step-0">
      <RetinaImg className="logo" style={marginTop: 86} url="nylas://onboarding/assets/nylas-logo@2x.png" mode={RetinaImg.Mode.ContentPreserve}/>
      <p className="hero-text" style={fontSize: 46, marginTop: 57}>Welcome to Nylas N1</p>
      <RetinaImg className="icons" style={position: "absolute", top: 0, left: 0} url="nylas://onboarding/assets/icons-bg@2x.png" mode={RetinaImg.Mode.ContentPreserve} />
      {@_renderNavBubble(0)}
    </div>

  _renderStep1: ->
    <div className={@_stepClass(1)} key="step-1">
      <p className="hero-text" style={marginTop: 40}>Open source & made for developers.</p>
      <div className="gear-outer-container"><div className="gear-container">
        {@_gears()}
      </div></div>
      <RetinaImg className="gear-small" mode={RetinaImg.Mode.ContentPreserve}
                 url="nylas://onboarding/assets/gear-small@2x.png" />
      <RetinaImg className="wrench" mode={RetinaImg.Mode.ContentPreserve}
                 url="nylas://onboarding/assets/wrench@2x.png" />

      <p className="sub-text">Nylas N1 and the cloud sync engine are available on <a onClick={=> @_open("https://github.com/nylas/n1")}>GitHub</a></p>
      {@_renderNavBubble(1)}
    </div>

  _gears: ->
    gears = []
    gear = "gear-large@2x.png"
    for i in [0..3]
      if i isnt 0 then gear = "gear-large-outer@2x.png"
      gears.push <RetinaImg className="gear-large gear-large-#{i}"
                             mode={RetinaImg.Mode.ContentPreserve}
                             url="nylas://onboarding/assets/#{gear}" />
    return gears

  _renderStep2: ->
    <div className={@_stepClass(2)} key="step-2">
      <p className="hero-text" style={marginTop: 26}>Powered by Cloud Sync.</p>
      <RetinaImg mode={RetinaImg.Mode.ContentPreserve}
                 style={paddingTop: 4, paddingBottom: 4}
                 url="nylas://onboarding/assets/cloud@2x.png" />
      <p style={fontSize: 17, opacity: 0.7, marginTop: 18}>Nylas syncs your mail in the cloud. This makes N1 blazing fast<br/>and is needed for features like Snooze and Send Later.</p>
      <p><a onClick={=> @_open("https://github.com/nylas/sync-engine")}>Learn more</a></p>
      {@_renderNavBubble(2)}
    </div>

  _open: (link) ->
    shell.openExternal(link)
    return

  _renderNavBubble: (step=0) ->
    bubbles = [0..2].map (n) =>
      active = if n is step then "active" else ""
      <div className="nav-bubble #{active}"
           onClick={ => @setState step: n }></div>

    <div className="nav-bubbles">
      {bubbles}
    </div>

  _onBack: =>
    @setState(step: @state.step - 1)

  _onContinue: =>
    if @state.step < 2
      @setState(step: @state.step + 1)
    else
      Actions.recordUserEvent('Welcome Page Finished', {
        tokenAuthEnabled: PageRouterStore.tokenAuthEnabled(0)
      })
      if PageRouterStore.tokenAuthEnabled() is "no"
        OnboardingActions.moveToPage("account-choose")
      else
        OnboardingActions.moveToPage("token-auth")

module.exports = WelcomePage
