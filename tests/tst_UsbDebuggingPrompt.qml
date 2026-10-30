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

import QtQuick
import QtTest
import LunaNext.Common 0.1
import LuneOS.Components 1.0
import QtQuick.Controls.LuneOS 2.0

import "../qml/Notifications"

/*
 * UsbDebuggingPrompt: the fingerprint it shows, its answers, and that saying
 * nothing is Deny. The sizes Dialog and DialogCheckBox keep when nobody sets
 * them are luneos-components' tst_dialog_text_sizes.
 */
Item {
    id: page
    width: 480
    height: 800

    UsbDebuggingPrompt {
        id: prompt
        // Shorter than the 1 s the shell gets, so the suite stays quick.
        armDelayMs: 300
    }

    Component {
        id: confirmComponent
        ConfirmDialog {}
    }

    Component {
        id: defaultPrompt
        UsbDebuggingPrompt {}
    }

    SignalSpy {
        id: answers
        target: prompt
        signalName: "answered"
    }

    TestCase {
        name: "UsbDebuggingPrompt"
        when: windowShown

        readonly property string fp: "SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU"

        function init() {
            prompt.withdraw();
            answers.clear();
        }

        // ask(), and wait until Allow takes a tap.
        function askArmed(f) {
            prompt.ask(f, 30000);
            tryVerify(function() { return prompt.armed; }, 2000);
        }

        function child(name) {
            var c = findChild(prompt, name);
            verify(c !== null, name);
            return c;
        }

        function test_asks_with_the_fingerprint() {
            prompt.ask(fp, 30000);
            verify(prompt.opened);
            compare(child("usbDebuggingFingerprint").text.replace(/\s/g, ""), fp);
            compare(prompt.fingerprint, fp);
        }

        // In groups of four after "SHA256:" on its own line, wrapped between
        // groups only, in a monospaced face.
        function test_the_fingerprint_is_shown_in_groups() {
            prompt.ask(fp, 30000);
            var t = child("usbDebuggingFingerprint");
            compare(t.text, "SHA256:\n47DE Qpj8 HBSa +/TI\nmW+5 JCeu QeRk m5NM\npJWZ G3hS uFU");
            compare(t.wrapMode, Text.WordWrap);
            compare(t.font.family, "Liberation Mono");
            prompt.ask("abcdefghij", 30000);
            compare(t.text, "abcd efgh ij");
        }

        // The Dialog's message, by its text.
        function messageText() {
            var found = null;
            function walk(it) {
                if (!found && it.text === prompt.message && it.font !== undefined)
                    found = it;
                for (var i = 0; i < it.children.length && !found; i++)
                    walk(it.children[i]);
            }
            walk(prompt);
            verify(found !== null, "the message");
            return found;
        }

        // The Dialog's content inset: 2 gu where it has one, 1.6 gu before.
        function inset() {
            return prompt.contentInset !== undefined ? prompt.contentInset : Units.gu(1.6);
        }

        // The buttons (26 gu) centred, one under the other; the message,
        // fingerprint and box at the Dialog's content inset, as wide as
        // its content. Allow first, then Deny.
        function test_centred_buttons_words_at_the_inset_allow_first() {
            prompt.ask(fp, 30000);
            var allow = child("usbDebuggingAllow"), deny = child("usbDebuggingDeny");
            var left = allow.mapToItem(prompt, 0, 0).x;
            var names = ["usbDebuggingAllow", "usbDebuggingDeny"];
            for (var i = 0; i < names.length; i++) {
                var b = child(names[i]);
                var at = b.mapToItem(prompt, 0, 0);
                fuzzyCompare(at.x, prompt.width - (at.x + b.width), 1, names[i] + " margins");
                fuzzyCompare(at.x, left, 1, names[i] + " one under the other");
                compare(b.width, Units.gu(26));
            }
            var frameLeft = (prompt.width - prompt.dialogWidth) / 2;
            var words = [messageText(), child("usbDebuggingFingerprint"), child("usbDebuggingAlways")];
            for (i = 0; i < words.length; i++) {
                var w = words[i];
                fuzzyCompare(w.mapToItem(prompt, 0, 0).x - frameLeft, inset(), 1, "word " + i + " at the inset");
                fuzzyCompare(w.width, prompt.dialogWidth - 2 * inset(), 1, "word " + i + " as wide as the content");
            }
            verify(allow.mapToItem(prompt, 0, 0).y + allow.height <= deny.mapToItem(prompt, 0, 0).y,
                   "Allow above Deny");
        }

        // The words are the Dialog's own message: no column of the prompt's
        // own any more, now that Dialog keeps them clear of the frame.
        function test_the_message_is_the_dialogs() {
            prompt.ask(fp, 30000);
            compare(prompt.message, "A computer wants to use USB debugging. Its key fingerprint is:");
            verify(findChild(prompt, "usbDebuggingMessage") === null);
        }

        // Allow and Deny read as two answers: 1.5 gu of clear space between
        // them, and the same between the box and Allow. The Dialog's own
        // 0.5 gu stays as it is for every other dialog.
        function test_clear_space_between_the_answers() {
            prompt.ask(fp, 30000);
            var box = child("usbDebuggingAlways");
            var allow = child("usbDebuggingAllow"), deny = child("usbDebuggingDeny");
            var boxBottom = box.mapToItem(prompt, 0, box.height).y;
            var allowTop = allow.mapToItem(prompt, 0, 0).y;
            var allowBottom = allow.mapToItem(prompt, 0, allow.height).y;
            var denyTop = deny.mapToItem(prompt, 0, 0).y;
            fuzzyCompare(denyTop - allowBottom, Units.gu(1.5), 1, "Allow to Deny");
            fuzzyCompare(allowTop - boxBottom, Units.gu(1.5), 1, "box to Allow");
            compare(allow.parent.spacing, Units.gu(0.5));
            var d = createTemporaryObject(confirmComponent, page);
            compare(findChild(d, "confirmAcceptButton").parent.parent.spacing, Units.gu(0.5));
        }

        // Allow on top must not make a stray tap count: one landing where
        // Allow is, half way through its wait, sends nothing and leaves the
        // question up; once armed, the same tap allows.
        function test_a_tap_where_allow_is_half_way_through_the_wait() {
            prompt.ask(fp, 30000);
            var allow = child("usbDebuggingAllow");
            wait(prompt.armDelayMs / 2);
            verify(!prompt.armed);
            // Where Allow is now, the dialog laid out.
            var c = allow.mapToItem(page, allow.width / 2, allow.height / 2);
            compare(page.childAt(c.x, c.y), prompt);
            mouseClick(page, c.x, c.y);
            compare(answers.count, 0);
            verify(prompt.opened);
            tryVerify(function() { return prompt.armed; }, 2000);
            var c2 = allow.mapToItem(page, allow.width / 2, allow.height / 2);
            compare(c2.x, c.x);
            compare(c2.y, c.y);
            mouseClick(page, c.x, c.y);
            compare(answers.count, 1);
            compare(answers.signalArguments[0][1], true);
        }

        // The same width as the other LuneOS dialogs' buttons: 26 gu, as in
        // ConfirmDialog (read off a ConfirmDialog, not restated here).
        function test_the_buttons_are_as_wide_as_confirm_dialogs() {
            var confirm = createTemporaryObject(confirmComponent, page);
            verify(confirm !== null);
            var cb = findChild(confirm, "confirmAcceptButton");
            verify(cb !== null, "ConfirmDialog's accept button");
            compare(cb.width, Units.gu(26.0));
            prompt.ask(fp, 30000);
            compare(child("usbDebuggingDeny").width, cb.width);
            compare(child("usbDebuggingAllow").width, cb.width);
        }

        // font.pixelSize is whole pixels.
        function px(size) {
            return Math.round(FontUtils.sizeToPixels(size));
        }

        // Sized as the shell's system dialog (LockScreen/MessageDialog):
        // the title "large", the message, fingerprint and box "medium".
        function test_the_title_is_large_and_the_rest_medium() {
            prompt.ask(fp, 30000);
            compare(prompt.titlePixelSize, px("large"));
            compare(prompt.messagePixelSize, px("medium"));
            compare(child("usbDebuggingFingerprint").font.pixelSize, px("medium"));
            compare(child("usbDebuggingAlways").labelPixelSize, px("medium"));
            verify(prompt.titlePixelSize > prompt.messagePixelSize);
        }

        // Allow green and Deny red, LuneOSButton's own colours.
        function test_allow_is_green_and_deny_red() {
            prompt.ask(fp, 30000);
            compare(child("usbDebuggingAllow").color, LuneOSButton.affirmativeColor);
            compare(child("usbDebuggingDeny").color, LuneOSButton.negativeColor);
            compare(child("usbDebuggingAllow").fontcolor, Qt.color("white"));
            compare(child("usbDebuggingDeny").fontcolor, Qt.color("white"));
        }

        function test_allow_once() {
            askArmed(fp);
            mouseClick(child("usbDebuggingAllow"));
            compare(answers.count, 1);
            compare(answers.signalArguments[0][0], fp);
            compare(answers.signalArguments[0][1], true);
            compare(answers.signalArguments[0][2], false);
            verify(!prompt.opened);
        }

        function test_allow_always() {
            askArmed(fp);
            mouseClick(child("usbDebuggingAlways"));
            verify(prompt.always);
            mouseClick(child("usbDebuggingAllow"));
            compare(answers.count, 1);
            compare(answers.signalArguments[0][1], true);
            compare(answers.signalArguments[0][2], true);
        }

        function test_deny_never_remembers() {
            askArmed(fp);
            mouseClick(child("usbDebuggingAlways"));
            mouseClick(child("usbDebuggingDeny"));
            compare(answers.count, 1);
            compare(answers.signalArguments[0][1], false);
            compare(answers.signalArguments[0][2], false);
        }

        function test_the_box_starts_unticked_for_every_question() {
            askArmed(fp);
            mouseClick(child("usbDebuggingAlways"));
            prompt.withdraw();
            prompt.ask(fp, 30000);
            verify(!prompt.always);
        }

        function test_no_answer_is_deny() {
            prompt.ask(fp, 100);
            answers.wait(2000);
            compare(answers.count, 1);
            compare(answers.signalArguments[0][0], fp);
            compare(answers.signalArguments[0][1], false);
            verify(!prompt.opened);
        }

        function test_withdrawn_is_no_answer() {
            prompt.ask(fp, 100);
            prompt.withdraw();
            verify(!prompt.opened);
            wait(300);
            compare(answers.count, 0);
        }

        function test_one_answer_a_question() {
            askArmed(fp);
            var allow = child("usbDebuggingAllow");
            mouseClick(allow);
            prompt._answer(true);
            prompt._answer(false);
            compare(answers.count, 1);
        }

        function test_nothing_to_ask_about() {
            prompt.ask("", 30000);
            verify(!prompt.opened);
            prompt.ask(undefined, 30000);
            verify(!prompt.opened);
        }

        function test_allow_waits_a_second_by_default() {
            var p = createTemporaryObject(defaultPrompt, page);
            compare(p.armDelayMs, 1000);
        }

        function test_a_tap_on_allow_too_soon_does_nothing() {
            prompt.ask(fp, 30000);
            verify(!prompt.armed);
            verify(!child("usbDebuggingAllow").enabled);
            // Still looks it: dimmed, though green.
            verify(child("usbDebuggingAllow").opacity <= 0.5);
            mouseClick(child("usbDebuggingAllow"));
            mouseClick(child("usbDebuggingAlways"));
            prompt._answer(true);
            compare(answers.count, 0);
            verify(prompt.opened);
            verify(!prompt.always);
        }

        function test_allow_works_once_it_is_armed() {
            prompt.ask(fp, 30000);
            tryVerify(function() { return child("usbDebuggingAllow").enabled; }, 2000);
            compare(child("usbDebuggingAllow").opacity, 1);
            mouseClick(child("usbDebuggingAllow"));
            compare(answers.count, 1);
            compare(answers.signalArguments[0][1], true);
        }

        function test_deny_is_never_held_back() {
            prompt.ask(fp, 30000);
            verify(!prompt.armed);
            mouseClick(child("usbDebuggingDeny"));
            compare(answers.count, 1);
            compare(answers.signalArguments[0][1], false);
        }

        function test_another_computer_waits_again() {
            askArmed(fp);
            prompt.ask("SHA256:other", 30000);
            verify(!prompt.armed);
            mouseClick(child("usbDebuggingAllow"));
            compare(answers.count, 0);
            tryVerify(function() { return prompt.armed; }, 2000);
            mouseClick(child("usbDebuggingAllow"));
            compare(answers.count, 1);
            compare(answers.signalArguments[0][0], "SHA256:other");
        }

        // A question that takes the place of one still waiting waits the whole delay again.
        function test_a_new_question_mid_wait_starts_the_wait_over() {
            prompt.ask(fp, 30000);
            wait(200);
            prompt.ask("SHA256:other", 30000);
            wait(200);
            verify(!prompt.armed, "armed 400 ms after the first ask, 200 ms after the second");
            tryVerify(function() { return prompt.armed; }, 2000);
        }

        function test_shown_again_waits_again() {
            askArmed(fp);
            prompt.withdraw();
            prompt.ask(fp, 30000);
            verify(!prompt.armed);
            mouseClick(child("usbDebuggingAllow"));
            compare(answers.count, 0);
        }

        function test_markup_in_the_fingerprint_is_shown_as_text() {
            prompt.ask("<b>x</b>", 30000);
            compare(child("usbDebuggingFingerprint").textFormat, Text.PlainText);
        }
    }
}
