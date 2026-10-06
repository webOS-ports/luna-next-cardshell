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

import QtQuick 2.5
import LunaNext.Common 0.1

/*!
 * \brief The system-wide Select All / Cut / Copy / Paste overlay.
 *
 * Legacy had two of these and LuneOS inherited neither in a usable form: an
 * "Edit" section inside enyo.AppMenu, which only an Enyo application that asked
 * for it ever showed, and the floating selection pill, which in LuneOS exists
 * only inside Atlas. Anything else - Memos, a QML application, the browser's
 * own fields - had no way to cut, copy or paste but a keyboard shortcut, and
 * until recently not even that.
 *
 * This is the shell's own, so every application gets it. It performs the edits
 * by asking the compositor to type Ctrl+X/C/V/A at the focused surface, which
 * is why it needs nothing of the application: every toolkit already implements
 * those shortcuts, and after the input method's grab was taught to hand keys
 * back they reach the client whatever it is written in. No command channel per
 * client, and nothing new in the web runtime.
 *
 * Shown only while a text field holds the input method's focus, which is what
 * keyboardService.inputFocus reports - the same question legacy's EditMenu
 * asked to decide whether to grey its items out.
 *
 * The look is legacy's selection pill, as Atlas still draws it: a dark rounded
 * bar with a downward arrow, light text, a soft drop shadow and no inset one.
 */
Item {
    id: editOverlay

    property QtObject keyboardService: null
    property QtObject compositorInstance: null

    //! Where to give the keyboard back to. The shell passes its own function,
    //! because pressing anything here takes the focus off the application and
    //! the shortcut has to arrive at one that still has it.
    property var foregroundWindow: null

    //! Where the pill points. Set before calling show().
    property real anchorX: width / 2
    property real anchorY: height / 2
    //! Where it points when it hangs above the line instead: the line's top, for a
    //! pill that points at a line of text rather than at a finger. The same as
    //! anchorY unless set.
    property real anchorTopY: anchorY

    visible: false
    z: 1001

    //! Whether an application is in front. The input method's focus belongs to
    //! whichever client spoke last and outlives the card it came from, so
    //! without this the pill came up over the card list, the launcher and the
    //! lock screen on the strength of a field nobody can see.
    property bool applicationForeground: true

    //! Whether there is anything to edit. Nothing is shown without it.
    readonly property bool editable: applicationForeground &&
                                     (keyboardService ? keyboardService.inputFocus : false)

    readonly property bool hasSelection: keyboardService ? keyboardService.inputHasSelection : false
    //! False against an input method that does not say, which gets every item.
    readonly property bool selectionKnown: keyboardService ? keyboardService.inputSelectionKnown : false
    readonly property bool hasText: keyboardService ? keyboardService.inputHasText : false

    //! Whether the pasteboard has text. True against a compositor that cannot say,
    //! so Paste is not lost to an old one.
    readonly property bool clipboardHasText:
        compositorInstance && compositorInstance.clipboardHasText !== undefined
            ? compositorInstance.clipboardHasText : true

    /*
     * The pill's items, by legacy's own rules - read out of libWebKitLuna's
     * ClipboardCommand classes, each command's enabled(Frame), in its order:
     *   Cut         a range selection, in an editable field
     *   Copy        a range selection
     *   Select      no range selection, and text in the field
     *   Select All  the same condition as Select
     *   Paste       text on the pasteboard, in an editable field
     * A caret, or nothing selected, is "no range selection". With none of them
     * enabled there is no pill at all.
     */
    readonly property var items: {
        // Raised by a tap on a misspelled word rather than by a hold, and then
        // it is the words that could replace it: legacy's spelling widget, which
        // used the same pill.
        if (editOverlay.spellingMode) {
            var words = [];
            var suggestions = keyboardService ? keyboardService.spellingSuggestions : [];

            for (var i = 0; i < suggestions.length; ++i)
                words.push({ label: suggestions[i], command: "suggest" });

            return words;
        }

        if (!editOverlay.selectionKnown) {
            // An input method that does not report a selection: everything, as
            // before.
            return [ { label: "Cut",        command: "cut" },
                     { label: "Copy",       command: "copy" },
                     { label: "Paste",      command: "paste" },
                     { label: "Select All", command: "selectAll" } ];
        }

        var list = [];

        if (editOverlay.hasSelection) {
            list.push({ label: "Cut",  command: "cut" });
            list.push({ label: "Copy", command: "copy" });
        } else if (editOverlay.hasText) {
            list.push({ label: "Select",     command: "selectWord" });
            list.push({ label: "Select All", command: "selectAll" });
        }

        if (editOverlay.clipboardHasText)
            list.push({ label: "Paste", command: "paste" });

        return list;
    }

    //! Whether the pill shows suggestions for a misspelled word instead of the
    //! edit commands. Set by showSuggestionsAt(), cleared whenever it goes away.
    property bool spellingMode: false

    /*
     * Suggestions at the word, where legacy's spelling widget put them, not where
     * the finger was. The keyboard reports the caret's rectangle in the
     * application's own coordinates and the window it is in knows how to turn
     * that into ours; without either, the tap point is as good as it gets.
     */
    function showSuggestionsAtWord(tapX, tapY) {
        var rect = editOverlay.keyboardService ? editOverlay.keyboardService.spellingRect : null;
        var foreground = editOverlay.foregroundWindow ? editOverlay.foregroundWindow() : null;

        if (rect && foreground && typeof foreground.mapToItem === "function") {
            var top = foreground.mapToItem(editOverlay, rect.x, rect.y);
            var bottom = foreground.mapToItem(editOverlay, rect.x, rect.y + rect.height);

            editOverlay.anchorTopY = top.y;
            editOverlay.showSuggestionsAt(top.x, bottom.y);
            return;
        }

        editOverlay.anchorTopY = tapY;
        editOverlay.showSuggestionsAt(tapX, tapY);
    }

    function showSuggestionsAt(x, y) {
        editOverlay.spellingMode = true;
        editOverlay.showAt(x, y);

        // Nothing to suggest means nothing was shown, and the mode must not be
        // left set for the next time the pill comes up.
        if (!editOverlay.visible)
            editOverlay.hide();
    }

    function showAt(x, y) {
        // Legacy's widget returned without showing when none of its commands was
        // enabled; an empty pill is not something to put up.
        if (editOverlay.items.length === 0)
            return;

        editOverlay.anchorX = x;
        editOverlay.anchorY = y;
        editOverlay.visible = true;

        console.log("EditOverlay: shown at " + x + "," + y
                    + " editable=" + editOverlay.editable);
    }

    function hide() {
        editOverlay.visible = false;
        editOverlay.spellingMode = false;
        editOverlay.anchorTopY = Qt.binding(function() { return editOverlay.anchorY; });
    }

    // The caret moved to another word, or out of this one: the suggestions are
    // for a word it is no longer in.
    Connections {
        target: editOverlay.keyboardService

        function onSpellingWordChanged() {
            if (editOverlay.spellingMode)
                editOverlay.hide();
        }
    }

    //! The field going away takes the overlay with it once it is up.
    onEditableChanged: if (!editOverlay.editable) editOverlay.hide()

    // A press anywhere else dismisses, the way the legacy pill did. Below the
    // pill in z order so its own buttons are hit first.
    MouseArea {
        anchors.fill: parent
        onPressed: editOverlay.hide()
    }

    /*!
     * \brief Legacy's own pill, from legacy's own slices.
     *
     * The artwork is the webOS one - usr/palm/webkit/images/ate-*.png out of a
     * Pre3 rootfs, the same files the old browser carried - drawn the way it
     * drew them: two 17 px caps, a stretched middle either side of a 33 px
     * arrow, all 60 px tall, with 4 px dividers between the words. A gridUnit
     * of 10 makes those gu measurements the legacy pixels exactly.
     */
    Item {
        id: pill

        /*
         * Every slice is the same 60 px canvas, and the bar does not fill it:
         * in the caps it is rows 3..49, in the arrow that points up it is rows
         * 10..56. Those seven rows are the whole trick - the arrow rides that
         * much higher and its point sticks out of the top of the bar, rather
         * than the slice being stretched taller, which only drags the bar down
         * with it and leaves a tab hanging below.
         */
        /*
         * How big legacy's 60 px slice is drawn here.
         *
         * Legacy's own bar is 41 px of a 768 px screen, and matching that share
         * exactly came out too small: that screenshot is a TouchPad, and the
         * same fraction of a phone's screen is a much smaller thing to hit and
         * to read. Half a gu above it, which is what a hand asked for.
         */
        readonly property real canvas: Units.gu(5.25)   // the 60 px slice
        readonly property real px: canvas / 60          // one of legacy's pixels
        readonly property real arrowRise: 7 * px        // caps' bar top vs the arrow's

        readonly property real capWidth: 17 * px
        readonly property real arrowWidth: 33 * px
        //! Where the bar's own ink sits inside that canvas, for placing the
        //! words in the middle of the bar rather than the middle of the slice.
        readonly property real barTop: 3 * px
        readonly property real barBottom: 49 * px

        //! Under the press, pointing up at the text, which is where legacy put
        //! it. Above it instead when there is no room below, which is what the
        //! second arrow slice was always there for.
        readonly property bool below: editOverlay.anchorY + canvas + arrowRise < editOverlay.height

        //! The most the words may take before the pill scrolls instead of growing:
        //! the screen less its margins and the two caps, which is the bound legacy
        //! put on its balloon.
        readonly property real maxViewportWidth:
            editOverlay.width - 2 * Units.gu(0.5) - 2 * capWidth

        width: background.width
        height: canvas + arrowRise

        x: Math.max(Units.gu(0.5),
                    Math.min(editOverlay.width - width - Units.gu(0.5),
                             editOverlay.anchorX - width / 2))
        //! The point sits on what it is pointing at, so the bar hangs the
        //! slice's own distance away from it rather than a made-up gap.
        y: below ? editOverlay.anchorY - barTop
                 : editOverlay.anchorTopY - height + barTop

        Row {
            id: background

            Image {
                id: leftCap
                source: Qt.resolvedUrl("images/edit/ate-left.png")
                width: pill.capWidth
                height: pill.canvas
            }
            Image {
                source: Qt.resolvedUrl("images/edit/ate-middle.png")
                width: viewport.width / 2 - pill.arrowWidth / 2
                height: pill.canvas
            }
            /*
             * The arrow slice is the bar with the point on top of it, so it has
             * to stand taller than the bar and hang out of the end the point is
             * on. It cannot say so with an anchor - a Row lays its children out
             * itself and ignores one - so it rides inside an item of bar height
             * and is offset out of it instead.
             */
            Item {
                width: pill.arrowWidth
                height: pill.canvas

                Image {
                    source: pill.below ? Qt.resolvedUrl("images/edit/ate-arrow-up.png")
                                       : Qt.resolvedUrl("images/edit/ate-arrow-down.png")
                    width: parent.width
                    height: pill.canvas
                    //! Same canvas, seven of its rows higher, so the two bars
                    //! meet and only the point stands above them.
                    y: pill.below ? -pill.arrowRise : 0
                }
            }
            Image {
                source: Qt.resolvedUrl("images/edit/ate-middle.png")
                width: viewport.width / 2 - pill.arrowWidth / 2
                height: pill.canvas
            }
            Image {
                source: Qt.resolvedUrl("images/edit/ate-right.png")
                width: pill.capWidth
                height: pill.canvas
            }
        }

        /*
         * The words, scrolling sideways when there are more than fit.
         *
         * As legacy's widget did: a scroll position kept between nothing and
         * what is left over, dragged with the finger and flicked on letting go,
         * with no spring past either end. Something is only a press on a word if
         * the finger did not drag - a drag that began on one belongs to the
         * scrolling, which Flickable takes from the MouseArea underneath.
         */
        Flickable {
            id: viewport

            anchors.centerIn: background
            //! Centred on the bar's ink, not on the canvas it is drawn in.
            anchors.verticalCenterOffset: (pill.barTop + pill.barBottom) / 2 - pill.canvas / 2

            width: Math.min(actions.width, pill.maxViewportWidth)
            height: actions.height

            contentWidth: actions.width
            contentHeight: actions.height

            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width

            //! What is still out of sight on each side.
            readonly property bool canScrollToLeft: contentX > 0
            readonly property bool canScrollToRight: contentX < contentWidth - width

            Row {
                id: actions

                spacing: Units.gu(0.6)

                Repeater {
                    model: editOverlay.items

                    delegate: Row {
                        spacing: Units.gu(0.6)

                        //! The same height for every item, whether or not it has a
                        //! divider. A Row leaves out a child that is not visible,
                        //! so the first item - the only one without one - would
                        //! otherwise be a row as short as its own text, and being
                        //! top-aligned with the rest it would sit higher than them.
                        height: 40 * pill.px

                        Image {
                            source: Qt.resolvedUrl("images/edit/ate-divider.png")
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4 * pill.px
                            height: 40 * pill.px
                            visible: index > 0
                        }

                        //! At least 50 of legacy's pixels wide, the word in the
                        //! middle of it, as legacy laid its commands out.
                        Item {
                            width: Math.max(label.implicitWidth, 50 * pill.px)
                            height: 40 * pill.px

                            Text {
                                id: label

                                //! In the middle of the bar. Without this the words sit
                                //! against the top of the row, because the divider
                                //! beside them is taller than they are and a Row aligns
                                //! its children to the top.
                                anchors.centerIn: parent

                                text: modelData.label
                                // Greyed rather than withheld when there is nothing to
                                // edit, as legacy's EditMenu did with autoDisableItems.
                                // Qt reads eight hex digits as #AARRGGBB, not CSS's
                                // #RRGGBBAA: "#E5E5E580" is a pale yellow, not a faded
                                // grey, which is where the yellow words came from.
                                color: editOverlay.editable ? "#E5E5E5" : "#80E5E5E5"
                                font.family: "Prelude"
                                //! Not DemiBold: the only Prelude faces on the device
                                //! are Medium and Bold, so anything above Normal picks
                                //! up Bold, which is not what legacy's pill reads like.
                                font.weight: Font.Normal
                                //! Measured off legacy's own pill - caps a third of the
                                //! bar's height - and expressed in its pixels so the
                                //! words follow the slice at any size.
                                font.pixelSize: 20 * pill.px
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Units.gu(0.3)
                                enabled: editOverlay.editable
                                onClicked: {
                                    /*
                                     * Hand the keyboard back before typing at it.
                                     *
                                     * Pressing this pill is a press on the shell,
                                     * and it leaves the application's surface
                                     * without the keyboard focus. The shortcut is
                                     * delivered to whatever holds that focus, so
                                     * sent from here it went nowhere at all: the
                                     * input method saw Ctrl+C and the page never
                                     * did.
                                     */
                                    if (modelData.command === "suggest") {
                                        editOverlay.keyboardService.applySpellingSuggestion(modelData.label);
                                        editOverlay.hide();
                                        return;
                                    }

                                    var foreground = editOverlay.foregroundWindow
                                                     ? editOverlay.foregroundWindow() : null;
                                    if (foreground && foreground.userData)
                                        foreground.userData.takeFocus();

                                    if (editOverlay.compositorInstance)
                                        editOverlay.compositorInstance.sendEditCommand(modelData.command);

                                    // Legacy hid the widget before running any command,
                                    // Select All included; the selection it leaves is
                                    // what a tap raises the pill for again.
                                    editOverlay.hide();
                                }
                            }
                        }
                    }
                }
            }
        }

        /*
         * Legacy's paintFade: the left one while scrolled away from the start,
         * the right one while there is more to the right, each at its edge of the
         * words and the height of the bar.
         */
        Image {
            source: Qt.resolvedUrl("images/edit/ate-left-scroll-fade.png")
            visible: viewport.canScrollToLeft
            x: viewport.x
            y: background.y
            width: 30 * pill.px
            height: pill.canvas
        }

        Image {
            source: Qt.resolvedUrl("images/edit/ate-right-scroll-fade.png")
            visible: viewport.canScrollToRight
            x: viewport.x + viewport.width - width
            y: background.y
            width: 30 * pill.px
            height: pill.canvas
        }
    }

    // It comes up at the start of the words, as legacy's showClipboardWidget put
    // it there before showing.
    onVisibleChanged: {
        if (visible)
            viewport.contentX = 0;
    }
}
