import NylasStore from 'nylas-store';
import Rx from 'rx-lite';
import _ from 'underscore';

import {DatabaseStore} from 'nylas-exports';
import EmojiActions from './emoji-actions';

const EmojiJSONBlobKey = 'emoji';


class EmojiStore extends NylasStore {
  constructor(props) {
    super(props);
    this._emoji = [];
  }

  activate = () => {
    const query = DatabaseStore.findJSONBlob(EmojiJSONBlobKey);
    this._subscription = Rx.Observable.fromQuery(query).subscribe((emoji) => {
      this._emoji = emoji ? emoji : [];
      this.trigger();
    });
    this.listenTo(EmojiActions.useEmoji, this._onUseEmoji);
  }

  frequentlyUsedEmoji = () => {
    const sortedEmoji = this._emoji;
    sortedEmoji.sort((a, b) => {
      if (a.frequency < b.frequency) return 1;
      return (b.frequency < a.frequency) ? -1 : 0;
    });
    const sortedEmojiNames = [];
    for (const emoji of sortedEmoji) {
      sortedEmojiNames.push(emoji.emojiName);
    }
    if (sortedEmojiNames.length > 32) {
      return sortedEmojiNames.slice(0, 32);
    }
    return sortedEmojiNames;
  }

  _onUseEmoji = (emoji) => {
    const savedEmoji = _.find(this._emoji, (curEmoji) => {
      return curEmoji.emojiChar === emoji.emojiChar;
    });
    if (savedEmoji) {
      for (const key in emoji) {
        if (emoji.hasOwnProperty(key)) {
          savedEmoji[key] = emoji[key];
        }
      }
      savedEmoji.frequency++;
    } else {
      _.extend(emoji, {frequency: 1});
      this._emoji.push(emoji);
    }
    this._saveEmoji();
    this.trigger();
  }

  _saveEmoji = () => {
    DatabaseStore.inTransaction((t) => {
      return t.persistJSONBlob(EmojiJSONBlobKey, this._emoji);
    });
  }

}

export default new EmojiStore();
