import {DOMUtils, ComposerExtension} from 'nylas-exports';
import EmojiActions from './emoji-actions';
import EmojiPicker from './emoji-picker';
import emoji from 'node-emoji';
import missingEmojiList from './missing-emoji';


class EmojiComposerExtension extends ComposerExtension {

  static selState = null;

  static onContentChanged = ({editor}) => {
    const sel = editor.currentSelection()
    const {emojiOptions, triggerWord} = EmojiComposerExtension._findEmojiOptions(sel);
    if (sel.anchorNode && sel.isCollapsed) {
      if (emojiOptions.length > 0) {
        const offset = sel.anchorOffset;
        if (!DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete")) {
          const anchorOffset = Math.max(sel.anchorOffset - triggerWord.length - 1, 0);
          editor.select(sel.anchorNode,
                        anchorOffset,
                        sel.focusNode,
                        sel.focusOffset)
          editor.wrapSelection("n1-emoji-autocomplete");
          editor.select(sel.anchorNode,
                        offset,
                        sel.anchorNode,
                        offset);
        }
      } else {
        if (DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete")) {
          editor.unwrapNodeAndSelectAll(DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete"));
          editor.select(sel.anchorNode,
                        sel.anchorOffset + triggerWord.length + 1,
                        sel.focusNode,
                        sel.focusOffset + triggerWord.length + 1);
        }
      }
    } else {
      if (DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete")) {
        editor.unwrapNodeAndSelectAll(DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete"));
        editor.select(sel.anchorNode,
                      sel.anchorOffset + triggerWord.length,
                      sel.focusNode,
                      sel.focusOffset + triggerWord.length);
      }
    }
  };

  static onBlur = ({editor}) => {
    EmojiComposerExtension.selState = editor.currentSelection().exportSelection();
  };

  static onFocus = ({editor}) => {
    if (EmojiComposerExtension.selState) {
      editor.select(EmojiComposerExtension.selState);
      EmojiComposerExtension.selState = null;
    }
  };

  static toolbarComponentConfig = ({toolbarState}) => {
    const sel = toolbarState.selectionSnapshot;
    if (sel) {
      const {emojiOptions} = EmojiComposerExtension._findEmojiOptions(sel);
      if (emojiOptions.length > 0 && !toolbarState.dragging && !toolbarState.doubleDown) {
        const locationRefNode = DOMUtils.closest(sel.anchorNode,
                                                 "n1-emoji-autocomplete");
        if (!locationRefNode) return null;
        const selectedEmoji = locationRefNode.getAttribute("selectedEmoji");
        return {
          component: EmojiPicker,
          props: {emojiOptions,
                  selectedEmoji},
          locationRefNode: locationRefNode,
          width: EmojiComposerExtension._emojiPickerWidth(emojiOptions),
          height: EmojiComposerExtension._emojiPickerHeight(emojiOptions),
          hidePointer: true,
        }
      }
    }
    return null;
  };

  static editingActions = () => {
    return [{
      action: EmojiActions.selectEmoji,
      callback: EmojiComposerExtension._onSelectEmoji,
    }]
  };

  static onKeyDown = ({editor, event}) => {
    const sel = editor.currentSelection()
    const {emojiOptions} = EmojiComposerExtension._findEmojiOptions(sel);
    if (emojiOptions.length > 0) {
      if (event.key === "ArrowDown" || event.key === "ArrowRight" ||
          event.key === "ArrowUp" || event.key === "ArrowLeft") {
        event.preventDefault();
        const moveToNext = (event.key === "ArrowDown" || event.key === "ArrowRight");
        const emojiNameNode = DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete");
        if (!emojiNameNode) return null;
        const selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
        if (selectedEmoji) {
          const emojiIndex = emojiOptions.indexOf(selectedEmoji);
          if (emojiIndex < emojiOptions.length - 1 && moveToNext) {
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[emojiIndex + 1]);
          } else if (emojiIndex > 0 && !moveToNext) {
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[emojiIndex - 1]);
          } else {
            const index = moveToNext ? 0 : emojiOptions.length - 1;
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[index]);
          }
        } else {
          const index = moveToNext ? 1 : emojiOptions.length - 1;
          emojiNameNode.setAttribute("selectedEmoji", emojiOptions[index]);
        }
      } else if (event.key === "Enter" || event.key === "Tab") {
        event.preventDefault();
        const emojiNameNode = DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete");
        if (!emojiNameNode) return null;
        let selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
        if (!selectedEmoji) selectedEmoji = emojiOptions[0];
        const args = {
          editor: editor,
          actionArg: {
            emojiName: selectedEmoji,
            replaceSelection: true,
          },
        };
        EmojiComposerExtension._onSelectEmoji(args);
      }
    }
  };

  static applyTransformsToDraft = ({draft}) => {
    const nextDraft = draft.clone();
    nextDraft.body = nextDraft.body.replace(/<span class="missing-emoji ([a-zA-Z0-9-_]*)">.*<\/span>/g, (match, emojiName) =>
      `<span class="broken-emoji ${emojiName}">${emoji.get(emojiName)}</span>`
    );
    return nextDraft;
  }

  static unapplyTransformsToDraft = ({draft}) => {
    const nextDraft = draft.clone();
    nextDraft.body = nextDraft.body.replace(/<span class="broken-emoji ([a-zA-Z0-9-_]*)">.*<\/span>/g, (match, emojiName) =>
      `<span class="missing-emoji ${emojiName}"><img src="images/composer-emoji/missing-emoji/${emojiName}.png" width="14" height="14" style="margin-top: -5px;" /></span>`
    );
    return nextDraft;
  }

  static _findEmojiOptions(sel) {
    if (sel.anchorNode &&
        sel.anchorNode.nodeValue &&
        sel.anchorNode.nodeValue.length > 0 &&
        sel.isCollapsed) {
      const words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset);
      let index = words.lastIndexOf(":");
      let lastWord = "";
      if (index !== -1 && words.lastIndexOf(" ") < index) {
        lastWord = words.substring(index + 1, sel.anchorOffset);
      } else {
        const {text} = EmojiComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
        index = text.lastIndexOf(":");
        if (index !== -1 && text.lastIndexOf(" ") < index) {
          lastWord = text.substring(index + 1);
        } else {
          return {triggerWord: "", emojiOptions: []};
        }
      }
      if (lastWord.length > 0) {
        return {triggerWord: lastWord, emojiOptions: EmojiComposerExtension._findMatches(lastWord)};
      }
      return {triggerWord: lastWord, emojiOptions: []};
    }
    return {triggerWord: "", emojiOptions: []};
  }

  static _onSelectEmoji = ({editor, actionArg}) => {
    const {emojiName, replaceSelection} = actionArg;
    if (!emojiName) return null;
    if (replaceSelection) {
      const sel = editor.currentSelection();
      if (sel.anchorNode &&
          sel.anchorNode.nodeValue &&
          sel.anchorNode.nodeValue.length > 0 &&
            sel.isCollapsed) {
        const words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset);
        let index = words.lastIndexOf(":");
        let lastWord = words.substring(index + 1, sel.anchorOffset);
        if (index !== -1 && words.lastIndexOf(" ") < index) {
          editor.select(sel.anchorNode,
                        sel.anchorOffset - lastWord.length - 1,
                        sel.focusNode,
                        sel.focusOffset);
        } else {
          const {text, textNode} = EmojiComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
          index = text.lastIndexOf(":");
          lastWord = text.substring(index + 1);
          const offset = textNode.nodeValue.lastIndexOf(":");
          editor.select(textNode,
                        offset,
                        sel.focusNode,
                        sel.focusOffset);
          editor.delete();
        }
      }
    }
    const emojiChar = emoji.get(emojiName);
    if (process.platform === "darwin" && missingEmojiList.indexOf(emojiName) !== -1) {
      const html = `<span class="missing-emoji ${emojiName}"><img
                      src="images/composer-emoji/missing-emoji/${emojiName}.png"
                      width="14"
                      height="14"
                      style="margin-top: -5px;" /></span>`;
      editor.insertHTML(html, {selectInsertion: false});
    } else {
      editor.insertText(emojiChar);
    }
    EmojiActions.useEmoji({emojiName: emojiName, emojiChar: emojiChar});
  };

  static _emojiPickerWidth(emojiOptions) {
    let maxLength = 0;
    for (const emojiOption of emojiOptions) {
      if (emojiOption.length > maxLength) {
        maxLength = emojiOption.length;
      }
    }
    // TODO: Calculate width of words more accurately for a closer fit.
    const WIDTH_PER_CHAR = 8;
    return (maxLength + 10) * WIDTH_PER_CHAR;
  }

  static _emojiPickerHeight(emojiOptions) {
    const HEIGHT_PER_EMOJI = 25;
    if (emojiOptions.length < 5) {
      return emojiOptions.length * HEIGHT_PER_EMOJI + 20;
    }
    return 5 * HEIGHT_PER_EMOJI + 23;
  }

  static _getTextUntilSpace(node, offset) {
    let text = node.nodeValue.substring(0, offset);
    let prevTextNode = DOMUtils.previousTextNode(node);
    if (!prevTextNode) return {text: text, textNode: node};
    while (prevTextNode) {
      if (prevTextNode.nodeValue.indexOf(" ") === -1 &&
          prevTextNode.nodeValue.indexOf(":") === -1) {
        text = prevTextNode.nodeValue + text;
        prevTextNode = DOMUtils.previousTextNode(prevTextNode);
      } else {
        text = prevTextNode.nodeValue.trim() + text;
        break;
      }
    }
    return {text: text, textNode: prevTextNode};
  }

  static _findMatches(word) {
    const emojiOptions = []
    const emojiNames = Object.keys(emoji.emoji).sort();
    for (const emojiName of emojiNames) {
      if (word === emojiName.substring(0, word.length)) {
        emojiOptions.push(emojiName);
      }
    }
    return emojiOptions;
  }

}

export default EmojiComposerExtension;
