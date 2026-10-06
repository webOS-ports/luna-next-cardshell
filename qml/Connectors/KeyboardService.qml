/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import LuneOS.Service 1.0

/*!
 * \brief What the input method says about the keyboard, and the one knob on it.
 *
 * A physical keyboard takes the on-screen one away, which leaves nothing for
 * what the hardware cannot do: an emoji, a script it has no keys for, a key it
 * simply lacks. com.webos.service.ime carries the way back.
 *
 * hardwareKeyboardPresent is what decides whether a control for this is worth
 * showing at all - on a device with no physical keyboard the toggle would do
 * nothing anyone wants.
 */
Item {
    id: keyboardService

    //! Whether a physical keyboard is attached.
    property bool hardwareKeyboardPresent: false
    //! Whether it can be typed on right now. False on a slider that is closed.
    property bool hardwareKeyboardUsable: false
    //! Whether the on-screen keyboard has been asked for despite the above.
    property bool onScreenKeyboardForced: false

    //! Whether a text field currently holds the input method's focus.
    //!
    //! What the edit overlay is shown for: there is no point offering Cut and
    //! Paste with nothing focused to cut from. Legacy's enyo.EditMenu greyed
    //! its items out on the same question.
    property bool inputFocus: false

    //! Whether the focused field has a selection, and whether it has any text.
    //!
    //! What the edit overlay chooses its items from, as legacy's did: Cut and
    //! Copy are for a selection, Select All and Paste for a field with none.
    property bool inputHasSelection: false
    property bool inputHasText: false
    //! Whether the input method reports the two above at all. An older one does
    //! not, and then "no selection" would just be a silence to read as a fact.
    property bool inputSelectionKnown: false

    //! The misspelled word the caret is in, and what the keyboard would put in its
    //! place. Both empty when the caret is in no such word, or in a field that
    //! gets no suggestions - which includes any that hides what is typed in it.
    property string spellingWord: ""
    property var spellingSuggestions: []
    //! Where the caret is, in the application's own coordinates - {x, y, width,
    //! height} - while there is a misspelling to point at; null otherwise.
    property var spellingRect: null

    /*! The digits printed on the key faces, by evdev scancode.
     *
     * For the things that take digits without an input method: the lock screen's
     * PIN pad is our own QML, running inside the compositor, so nothing in
     * maliit ever sees its keys and nothing can substitute a digit for the
     * letter key it is printed on. On a Q25 the key labelled 1 is w.
     *
     * Empty where the keyboard has no profile saying so, which is every device
     * whose digits are on keys of their own.
     */
    property var keyFaceDigits: ({})

    /*! \brief The digit printed on a key, or "" if it is not a digit key.
     *
     * Takes the scancode from a QML key event, which on the compositor's evdev
     * keyboard is the kernel's own code - the same numbering the profile uses.
     */
    function digitForScanCode(scanCode) {
        var d = keyboardService.keyFaceDigits[String(scanCode)];
        return d === undefined ? "" : d;
    }

    LunaService {
        id: imeService
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            imeService.subscribe("luna://com.webos.service.ime/getKeyboardStatus",
                                 JSON.stringify({"subscribe": true}),
                                 keyboardService._onStatus, keyboardService._onError);
        }
    }

    function _onStatus(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue)
            return;

        if (response.hardwareKeyboard !== undefined) {
            keyboardService.hardwareKeyboardPresent = response.hardwareKeyboard.present === true;
            keyboardService.hardwareKeyboardUsable = response.hardwareKeyboard.usable === true;
            keyboardService.keyFaceDigits =
                response.hardwareKeyboard.keyFaceDigits !== undefined
                    ? response.hardwareKeyboard.keyFaceDigits : ({});
        }

        if (response.onScreenKeyboardForced !== undefined)
            keyboardService.onScreenKeyboardForced = response.onScreenKeyboardForced === true;

        if (response.inputFocus !== undefined)
            keyboardService.inputFocus = response.inputFocus === true;

        if (response.inputHasSelection !== undefined) {
            keyboardService.inputSelectionKnown = true;
            keyboardService.inputHasSelection = response.inputHasSelection === true;
        }

        if (response.inputHasText !== undefined)
            keyboardService.inputHasText = response.inputHasText === true;

        if (response.spellingSuggestions !== undefined) {
            keyboardService.spellingWord = response.spellingWord !== undefined
                                           ? response.spellingWord : "";
            keyboardService.spellingSuggestions = response.spellingSuggestions;
            keyboardService.spellingRect = response.spellingRect !== undefined
                                           ? response.spellingRect : null;
        }
    }

    function _onError(message) {
        // Said once. maliit-server is started on demand, so being unable to
        // reach it is ordinary rather than broken, and a line per retry would
        // bury everything else.
        if (!keyboardService._warned) {
            keyboardService._warned = true;
            console.warn("KeyboardService: no keyboard status: " + message.payload);
        }
    }

    property bool _warned: false

    //! A rejected call arrives here with returnValue false rather than through
    //! the error callback, so it has to be read or a refusal looks like success.
    function _onSetResponse(message) {
        var response = JSON.parse(message.payload);

        if (response.returnValue !== true) {
            console.warn("KeyboardService: could not set the on-screen keyboard: "
                         + message.payload);
            return;
        }

        // The reply carries the new status, so the menu entry updates without
        // waiting for the subscription to come round.
        keyboardService._onStatus(message);
    }

    //! \brief Puts one of the suggestions in the misspelled word's place.
    //!
    //! Refused by the input method if the caret has left that word since the
    //! suggestions were reported, which is as it should be.
    function applySpellingSuggestion(suggestion) {
        imeService.call("luna://com.webos.service.ime/applySpellingSuggestion",
                        JSON.stringify({"suggestion": suggestion}),
                        keyboardService._onApplyResponse, keyboardService._onError);
    }

    function _onApplyResponse(message) {
        var response = JSON.parse(message.payload);

        if (response.returnValue !== true)
            console.warn("KeyboardService: suggestion not applied: " + message.payload);
    }

    //! \brief Asks for the on-screen keyboard, or stops asking.
    //!
    //! Sticky, as LunaSysMgr's keyboard key was: it toggled IMEController and
    //! left it toggled.
    function setOnScreenKeyboardForced(forced) {
        imeService.call("luna://com.webos.service.ime/setOnScreenKeyboardForced",
                        JSON.stringify({"forced": forced === true}),
                        keyboardService._onSetResponse, keyboardService._onError);
    }
}
