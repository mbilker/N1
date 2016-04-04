import React from 'react';
import fs from 'fs'
import Immutable from 'immutable';
import classNames from 'classnames';

import {Flexbox, RetinaImg} from 'nylas-component-kit';
import {Actions, PreferencesUIStore, Utils} from 'nylas-exports';


class PreferencesTabItem extends React.Component {

  static displayName = 'PreferencesTabItem';

  static propTypes = {
    selection: React.PropTypes.instanceOf(Immutable.Map).isRequired,
    tabItem: React.PropTypes.instanceOf(PreferencesUIStore.TabItem).isRequired,
  }

  constructor() {
    super();
  }

  _onClick = () => {
    Actions.switchPreferencesTab(this.props.tabItem.tabId);
  }

  _onClickAccount = (event, accountId) => {
    Actions.switchPreferencesTab(this.props.tabItem.tabId, {accountId});
    event.stopPropagation();
  }

  render() {
    const {tabId, displayName} = this.props.tabItem;

    const classes = classNames({
      "item": true,
      "active": tabId === this.props.selection.get('tabId'),
    });

    let path = `icon-preferences-${displayName.toLowerCase().replace(" ", "-")}.png`
    if (!fs.existsSync(Utils.imageNamed(path))) {
      path = "icon-preferences-general.png";
    }
    const icon = (<RetinaImg
                    className="tab-icon"
                    name={path}
                    mode={RetinaImg.Mode.ContentPreserve} />);

    return (
      <div className={classes} onClick={this._onClick}>
        {icon}
        <div className="name">{displayName}</div>
      </div>
    );
  }

}


class PreferencesTabsBar extends React.Component {

  static displayName = 'PreferencesTabsBar';

  static propTypes = {
    tabs: React.PropTypes.instanceOf(Immutable.List).isRequired,
    selection: React.PropTypes.instanceOf(Immutable.Map).isRequired,
  }

  constructor() {
    super();
  }

  renderTabs() {
    return this.props.tabs.map((tabItem) =>
      <PreferencesTabItem
        key={tabItem.tabId}
        tabItem={tabItem}
        selection={this.props.selection} />
    );
  }

  render() {
    return (
      <div className="container-preference-tabs">
        <Flexbox direction="row" className="preferences-tabs">
          {this.renderTabs()}
        </Flexbox>
      </div>
    );
  }

}

export default PreferencesTabsBar;
