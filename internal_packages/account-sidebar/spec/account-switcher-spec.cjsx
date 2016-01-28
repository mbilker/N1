React = require 'react/addons'
TestUtils = React.addons.TestUtils
AccountSwitcher = require './../lib/components/account-switcher'
SidebarStore = require './../lib/sidebar-store'
{AccountStore} = require 'nylas-exports'

describe "AccountSwitcher", ->
  switcher = null

  beforeEach ->
    account = AccountStore.accounts()[0]
    accounts = [
      account,
      {
        emailAddress: "dillon@nylas.com",
        provider: "exchange"
        label: "work"
      }
    ]
    switcher = TestUtils.renderIntoDocument(
      <AccountSwitcher accounts={accounts} focusedAccounts={[account]} />
    )

  it "shows other accounts and the 'Add Account' button", ->
    items = TestUtils.scryRenderedDOMComponentsWithClass switcher, "secondary-item"
    newAccountButton = TestUtils.scryRenderedDOMComponentsWithClass switcher, "new-account-option"

     # The unified Inbox item, then both accounts, then the manage item
    expect(items.length).toBe 4
    expect(newAccountButton.length).toBe 1
