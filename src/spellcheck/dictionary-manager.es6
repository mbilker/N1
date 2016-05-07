import _ from 'underscore';
import fs from 'fs';
import path from 'path';

const bundledHunspell = () => {
  let dict = path.join(require.resolve('spellchecker'), '..', '..', 'vendor', 'hunspell_dictionaries');

  try {
    // HACK: Special case being in an asar archive
    const unpacked = dict.replace(`.asar${path.sep}`, `.asar.unpacked${path.sep}`);
    if (fs.statSyncNoException(unpacked)) {
      dict = unpacked;
    }
  } catch (e) {
    /* empty */
  }

  return dict;
}

const possibleLinuxDictionaryPaths = [
  '/usr/share/hunspell',
  '/usr/share/myspell',
  bundledHunspell(),
];

let KeyboardLayout = null;
let Spellchecker = null;

export default class DictionaryManager {
  static shouldUseHunspell() {
    // Linux only has Hunspell available from `node-spellchecker`
    if (process.platform === 'linux') {
      return true;
    }

    // Mac OS X has a better one exposed by the Cocoa API
    if (process.platform === 'darwin') {
      return false;
    }

    if (process.platform === 'win32') {
      // FIXME: Determine if user is on Windows 8 or later, which have the
      // provided spellcheck API
      return false;
    }

    return true;
  }

  /**
   * @public
   * Creates a list of {Spellchecker} instances corresponding to the list of
   * installed languages. This is to handle the mapping from actual language to
   * language for which we have a dictionary if a fallback was necessary
   * @param installedLanguages (optional) - an {Array} of language identifiers
   *   to return {Spellchecker} instances for.
   * @return an {Object} where the keys are the languages passed implementation
   *   installedLanguages (or the list of system installed languages),
   *   and values are {Spellchecker} instances
  */
  static createInstancesForInstalledLanguages(installedLanguages = null) {
    const kInstalledLanguages = installedLanguages || DictionaryManager.getInstalledLanguages();
    const dictionaryPath = DictionaryManager.getDictionaryDirectory();

    return _.reduce(kInstalledLanguages, (acc, lang) => {
      const fixedLanguage = DictionaryManager.mapToDictionaryName(lang);
      console.log(`Mapping ${lang} => ${fixedLanguage}`);

      // eslint-disable-next-line global-require
      Spellchecker = Spellchecker || require('spellchecker').Spellchecker;
      const ret = new Spellchecker();

      if (fixedLanguage && ret.setDictionary(fixedLanguage, dictionaryPath)) {
        acc[lang] = ret;
      } else {
        console.log(`Failed to set dictionary: ${lang}`);
      }

      return acc;
    }, {});
  }

  /**
   * @private
   * Determines the actual dictionary to use for the given language
   *
   * In situations where an exact match for the language + locale (i.e. 'en_ZA'
   * for South American English) is not available, but a close match is
   * available (i.e. 'en_BR' for UK English) which is close and pretty good.
   *
   * @return language code to use instead of the one passed in
   */
  static mapToDictionaryName(language) {
    if (!this.dictionaryInfo) {
      this.dictionaryInfo = {
        useHunspell: DictionaryManager.shouldUseHunspell(),
        dictionaryDirectory: DictionaryManager.getDictionaryDirectory(),
      };

      if (fs.statSyncNoException(this.dictionaryInfo.dictionaryDirectory)) {
        const files = fs.readdirSync(this.dictionaryInfo.dictionaryDirectory);

        this.dictionaryInfo.localDictionaries = _.reduce(files, (acc, x) => {
          if (!x.match(/\.dic/i)) return acc;
          if (x.match(/hyph_/i)) return acc;

          // Normalize en_US => en-US for `node-spellchecker`
          const lang = x.substring(0, 5).replace(/_/, '-');
          acc[lang] = x;

          // Mark en => en-US
          acc[lang.substring(0, 2)] = lang;

          return acc;
        }, {});
      }
    }

    if (!this.dictionaryInfo.useHunspell) return language;

    // Use an exact match if we have one
    const kLanguage = language.replace(/_/, '-');
    if (this.dictionaryInfo.localDictionaries[kLanguage]) return kLanguage;

    const fullLang = this.dictionaryInfo.localDictionaries[kLanguage.substring(0, 2)];
    if (fullLang) return fullLang;

    return null;
  }

  static getInstalledLanguages() {
    if (process.platform !== 'linux') {
      try {
        // eslint-disable-next-line global-require
        KeyboardLayout = KeyboardLayout || require('keyboard-layout');

        return KeyboardLayout.getInstalledKeyboardLanguages();
      } catch (e) {
        return [];
      }
    }

    const dir = DictionaryManager.getDictionaryDirectory();
    return _.reduce(fs.readdirSync(dir), (acc, x) => {
      if (!x.match(/\.dic$/i)) return acc;

      acc.push(x.replace(/\.dic$/, ''));
      return acc;
    }, []);
  }

  /**
   * @private
   * Runs fs.statSync on a target directory, but does not throw an exception
   */
  static statSyncNoException(fsPath) {
    if ('statSyncNoException' in fs) {
      return fs.statSyncNoException(fsPath);
    }

    try {
      return fs.statSync(fsPath);
    } catch (e) {
      return null;
    }
  }

  /**
   * @public
   * Returns the root local dictionary directory
   * @return fully-qualified path to the dictionary directory
   */
  static getDictionaryDirectory() {
    if (process.platform === 'linux') {
      return _.find(possibleLinuxDictionaryPaths, (x) => DictionaryManager.statSyncNoException(x));
    }

    return path.join(path.dirname(process.execPath), '..', 'dictionaries');
  }
}
