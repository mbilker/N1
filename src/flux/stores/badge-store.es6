import NylasStore from 'nylas-store';
import FocusedPerspectiveStore from './focused-perspective-store';
import ThreadCountsStore from './thread-counts-store';
import CategoryStore from './category-store';

class BadgeStore extends NylasStore {

  constructor() {
    super();

    this.listenTo(FocusedPerspectiveStore, this._updateCounts);
    this.listenTo(ThreadCountsStore, this._updateCounts);

    NylasEnv.config.onDidChange('core.notifications.unreadBadge', ({newValue}) => {
      if (newValue === true) {
        this._setBadgeForCount()
      } else {
        this._setBadge("");
      }
    });

    this._updateCounts();
  }

  // Public: Returns the number of unread threads in the user's mailbox
  unread() {
    return this._unread;
  }

  total() {
    return this._total;
  }

  _updateCounts = () => {
    let unread = 0;
    let total = 0;

    const accountIds = FocusedPerspectiveStore.current().accountIds;
    for (const cat of CategoryStore.getStandardCategories(accountIds, 'inbox')) {
      unread += ThreadCountsStore.unreadCountForCategoryId(cat.id)
      total += ThreadCountsStore.totalCountForCategoryId(cat.id)
    }

    if ((this._unread === unread) && (this._total === total)) {
      return;
    }
    this._unread = unread;
    this._total = total;
    this._setBadgeForCount();
    this.trigger();
  }

  _setBadgeForCount = () => {
    if (!NylasEnv.config.get('core.notifications.unreadBadge')) {
      return;
    }
    if (!NylasEnv.isMainWindow() && !NylasEnv.inSpecMode()) {
      return;
    }

    if (this._unread > 999) {
      this._setBadge("999+");
    } else if (this._unread > 0) {
      this._setBadge(`${this._unread}`);
    } else {
      this._setBadge("");
    }
  }

  _setBadge = (val) => {
    require('electron').ipcRenderer.send('set-badge-value', val);
  }
}

module.exports = new BadgeStore()
