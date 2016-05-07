import { remote, webFrame } from 'electron';

import DictionaryManager from './dictionary-manager';

const { MenuItem } = remote;

let KeyboardLayout = null;

/**
 * Spellchecking Helper
 * Manages the spellcheckers
 *
 * @class NylasSpellcheck
 */
class NylasSpellcheck {
  constructor() {
    this.spellCheckers = DictionaryManager.createInstancesForInstalledLanguages();

    this.setup();
  }

  setup() {
    const lang = this.getCurrentKeyboardLanguage();
    this.current = this.spellCheckers[lang];

    webFrame.setSpellCheckProvider(lang.replace(/_/, '-'), false, {
      spellCheck: (text) => {
        if (!this.current) return true;

        const val = !(this.current.isMisspelled(text));
        return val;
      },
    });
  }

  /**
   * Add a word to the current spellcheck dictionary. Not persisted between
   * app restarts
   */
  add(word) {
    if (this.current) {
      this.current.add(word);
    }
  }

  /**
   * @return if the word provided is misspelled
   */
  isMisspelled(word) {
    if (!this.current) {
      return false;
    }
    return this.current.isMisspelled(word);
  }

  /**
   * @return the corrections for a misspelled word
   */
  getCorrectionsForMisspelling(word) {
    if (!this.current) {
      return [];
    }
    return this.current.getCorrectionsForMisspelling(word);
  }

  appendSpellingItemsToMenu({menu, word, onCorrect, onDidLearn}) {
    if (this.isMisspelled(word)) {
      const corrections = this.getCorrectionsForMisspelling(word);
      if (corrections.length > 0) {
        corrections.forEach((correction) => {
          menu.append(new MenuItem({
            label: correction,
            click: () => onCorrect(correction),
          }));
        });
      } else {
        menu.append(new MenuItem({ label: 'No Guesses Found', enabled: false}))
      }

      menu.append(new MenuItem({ type: 'separator' }));
      menu.append(new MenuItem({
        label: 'Learn Spelling',
        click: () => {
          this.add(word);
          if (onDidLearn) {
            onDidLearn(word);
          }
        },
      }));
      menu.append(new MenuItem({ type: 'separator' }));
    }
  }

  /**
   * @private
   * Returns the current keyboard language, or 'en_US' for Linux
   */
  getCurrentKeyboardLanguage() {
    if (process.platform === 'linux') {
      return 'en_US';
    }

    // eslint-disable-next-line global-require
    KeyboardLayout = KeyboardLayout || require('keyboard-layout');

    return KeyboardLayout.getCurrentKeyboardLanguage();
  }
}

export default new NylasSpellcheck();
