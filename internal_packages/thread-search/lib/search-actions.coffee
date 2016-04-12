Reflux = require 'reflux'

SearchActions = Reflux.createActions [
  "querySubmitted"
  "queryChanged"
  "searchBlurred"
  "searchCompleted"
]

for key, action of SearchActions
  action.sync = true

module.exports = SearchActions
