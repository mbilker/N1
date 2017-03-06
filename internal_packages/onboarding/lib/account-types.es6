// const TODO_ACCOUNT_TYPES = [
//   {
//     type: 'exchange',
//     displayName: 'Microsoft Exchange',
//     icon: 'ic-settings-account-eas.png',
//     headerIcon: 'setup-icon-provider-exchange.png',
//     color: '#1ea2a3',
//   },
//   {
//     type: 'outlook',
//     displayName: 'Outlook.com',
//     icon: 'ic-settings-account-outlook.png',
//     headerIcon: 'setup-icon-provider-outlook.png',
//     color: '#1174c3',
//   },
// ]

const AccountTypes = [
  {
    type: 'gmail',
    displayName: 'Gmail or G Suite',
    icon: 'ic-settings-account-gmail.png',
    headerIcon: 'setup-icon-provider-gmail.png',
    color: '#e99999',
    hidden: false,
  },
  {
    type: 'office365',
    displayName: 'Office 365',
    icon: 'ic-settings-account-outlook.png',
    headerIcon: 'setup-icon-provider-outlook.png',
    color: '#0078d7',
    hidden: false,
  },
  {
    type: 'yahoo',
    displayName: 'Yahoo',
    icon: 'ic-settings-account-yahoo.png',
    headerIcon: 'setup-icon-provider-yahoo.png',
    color: '#a76ead',
    hidden: false,
  },
  {
    type: 'icloud',
    displayName: 'iCloud',
    icon: 'ic-settings-account-icloud.png',
    headerIcon: 'setup-icon-provider-icloud.png',
    color: '#61bfe9',
    hidden: false,
  },
  {
    type: 'fastmail',
    displayName: 'FastMail',
    title: 'Setup your account',
    icon: 'ic-settings-account-fastmail.png',
    headerIcon: 'setup-icon-provider-fastmail.png',
    color: '#24345a',
    hidden: false,
  },
  {
    type: 'imap',
    displayName: 'IMAP / SMTP Setup',
    title: 'Setup your IMAP account',
    icon: 'ic-settings-account-imap.png',
    headerIcon: 'setup-icon-provider-imap.png',
    color: '#aaa',
    hidden: true,
  },
]

export default AccountTypes;
