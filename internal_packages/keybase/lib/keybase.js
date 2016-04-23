/** @babel */

import _ from 'underscore';

class KeybaseAPI {
  constructor() {
    this.baseUrl = 'https://keybase.io';
  }

  getUser(key, keyType, callback) {
    const keyTypes = ['usernames', 'domain', 'twitter', 'github', 'reddit',
                      'hackernews', 'coinbase', 'key_fingerprint'];
    if (!keyTypes.some(x => x === keyType)) {
      console.error('keyType must be a supported Keybase query type.');
    }

    const url = `${this.baseUrl}/_/api/1.0/user/lookup.json?${keyType}=${key}`;
    this._keybaseRequest(url).then((obj) => {
      if (!obj || !obj.them) {
        throw new Error("Empty response!");
      } else if (obj.status && obj.status.name !== 'OK') {
        throw new Error(obj.status.desc);
      }

      callback(null, _.map(obj.them, this._regularToAutocomplete));
    }).catch((err) => {
      if (err) {
        callback(err, null);
      }
    });
  }

  getKey(username, callback) {
    const url = `${this.baseUrl}/${username}/key.asc`;
    Promise.resolve(fetch(url)).then((response) => {
      if (response.status !== 200) {
        throw new Error(`Status code: ${response.status}`);
      }

      return response.text();
    }).then((obj) => {
      if (!obj) {
        throw new Error(`No key found for ${username}`);
      }

      callback(null, obj);
    }).catch((err) => {
      if (err) {
        callback(err);
      }
    });
  }

  autocomplete(query, callback) {
    const url = `${this.baseUrl}/_/api/1.0/user/autocomplete.json?q=${query}`;
    Promise.resolve(fetch(url)).then((response) => {
      if (response.status !== 200) {
        throw new Error(`Status code: ${response.status}`);
      }

      return response.json();
    }).then((obj) => {
      if (obj.status && obj.status.name !== 'OK') {
        throw new Error(obj.status.desc);
      }

      callback(null, obj.completions);
    }).catch((err) => {
      callback(err, null);
    });
  }

  _keybaseRequest(url, callback) {
    return Promise.resolve(fetch(this.baseUrl + url)).then((response) => {
      if (response.status !== 200) {
        return Promise.reject(`Status code: ${response.status}`);
      }

      return response.json();
    });
  }

  _regularToAutocomplete(profile) {
    // converts a keybase profile to the weird format used in the autocomplete
    // endpoint for backward compatability
    // (does NOT translate accounts - e.g. twitter, github - yet)
    // TODO this should be the other way around
    let cleanedProfile = {
      components: {},
      thumbnail: null,
    };

    if (profile.pictures && profile.pictures.primary) {
      cleanedProfile.thumbnail = profile.pictures.primary.url;
    }
    cleanedProfile.components = { username: { val: profile.basics.username } };

    return cleanedProfile;
  }
}

export default new KeybaseAPI()
