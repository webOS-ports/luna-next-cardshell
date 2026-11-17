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

pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Effects
import LunaNext.Common 0.1

/*!
 * \brief A loupe over the text while a finger drags a selection's end.
 *
 * The finger that drags a selection handle covers the very letters it is
 * choosing between, so this shows them, larger, just above the line: the
 * application's own window around the end that moves, sampled live.
 *
 * The shell does not know there is a handle, nor where it is. What it does
 * know is the rectangle the application reports for its caret: a web page
 * reports the span from one end of the selection to the other
 * (RectBetweenSelectionBounds), so a handle being dragged changes that
 * rectangle's size, letter by letter. A page scrolling under the finger only
 * moves it. So the loupe comes up when the finger has dragged and the
 * rectangle changes size, and stays until the finger lifts:
 *   - a long press that selects a word did not drag: no loupe;
 *   - a drag that scrolls moves the rectangle without resizing it: no loupe;
 *   - an application that reports no caret gets none either, as there is
 *     nothing to tell where its text is.
 *
 * Nothing is taken from the touch: the shell feeds press(), move() and
 * release() from a passive watcher, and this item takes no input itself.
 */
Item {
    id: magnifier

    objectName: "caretMagnifier"

    property QtObject compositorInstance: null

    //! The application's window, sampled for the loupe. The shell passes its
    //! own function, as for the edit pill.
    property var foregroundWindow: null

    //! Whether a text field holds the input method's focus in an application
    //! in front: the pill's own condition.
    property bool editable: false

    //! Where the on-screen keyboard is, in this item's coordinates. A press
    //! there is typing.
    property rect keyboardRect: Qt.rect(0, 0, 0, 0)

    //! How much larger the text is drawn.
    property real zoom: 1.5

    //! How far the finger has to move before the press is a drag.
    readonly property real slop: Units.gu(1.5)

    //! The finger is down, off the keyboard, on an application with a field.
    property bool pressing: false
    property point pressedAt
    property point finger
    //! The finger has gone further than the slop.
    property bool dragging: false
    //! The press resized the caret's rectangle after it became a drag.
    property bool engaged: false

    //! The caret's rectangle as last reported during this press.
    property var lastCaret: undefined
    //! One line's height: the shortest the rectangle has been during this
    //! press, which is one line however many the selection grows to.
    property real lineHeight: 0

    //! The window being sampled, taken at the press.
    property Item sourceWindow: null

    readonly property bool shown: engaged && pressing && editable && sourceWindow !== null

    //! The point the loupe is about, in this item's coordinates: the finger's
    //! position along the text, on the line the moving end is on.
    readonly property point lookAt: lookAtFor(lastCaret, finger)

    visible: shown
    enabled: false
    z: 1002

    function onKeyboard(x, y) {
        var k = magnifier.keyboardRect;
        return k.width > 0 && k.height > 0
               && x >= k.x && x < k.x + k.width
               && y >= k.y && y < k.y + k.height;
    }

    function caretRectangle() {
        var inputMethod = magnifier.compositorInstance ? magnifier.compositorInstance.inputMethod : null;
        return inputMethod && typeof inputMethod.cursorRectangleIn === "function"
               ? inputMethod.cursorRectangleIn(magnifier) : undefined;
    }

    /*!
     * \brief Where in the text a loupe for this rectangle and finger looks.
     *
     * Across: at the finger, kept within the rectangle, so past the end of the
     * text it shows the end rather than empty field. Down: the middle of the
     * rectangle while it is one line; on a selection of several lines, the
     * line at the end the finger is at - the last one below the middle, the
     * first above it - which is the end being dragged.
     */
    function lookAtFor(caret, at) {
        if (caret === undefined || caret === null)
            return at;

        var x = Math.max(caret.x, Math.min(caret.x + caret.width, at.x));
        var line = magnifier.lineHeight > 0 ? magnifier.lineHeight : caret.height;

        if (caret.height <= line * 1.5)
            return Qt.point(x, caret.y + caret.height / 2);

        return at.y >= caret.y + caret.height / 2
               ? Qt.point(x, caret.y + caret.height - line / 2)
               : Qt.point(x, caret.y + line / 2);
    }

    function press(x, y) {
        magnifier.release();

        if (!magnifier.editable || magnifier.onKeyboard(x, y))
            return;

        magnifier.pressing = true;
        magnifier.pressedAt = Qt.point(x, y);
        magnifier.finger = Qt.point(x, y);
        magnifier.lastCaret = magnifier.caretRectangle();
        magnifier.lineHeight = magnifier.lastCaret ? magnifier.lastCaret.height : 0;
        magnifier.sourceWindow = magnifier.foregroundWindow ? magnifier.foregroundWindow() : null;
    }

    function move(x, y) {
        if (!magnifier.pressing)
            return;

        magnifier.finger = Qt.point(x, y);

        var dx = x - magnifier.pressedAt.x;
        var dy = y - magnifier.pressedAt.y;
        if (dx * dx + dy * dy > magnifier.slop * magnifier.slop)
            magnifier.dragging = true;
    }

    function release() {
        magnifier.pressing = false;
        magnifier.dragging = false;
        magnifier.engaged = false;
        magnifier.lastCaret = undefined;
        magnifier.lineHeight = 0;
        magnifier.sourceWindow = null;
    }

    //! The caret's rectangle changed: a selection's end moving, or the page
    //! moving the text. Only the first is a reason for the loupe.
    function caretMoved() {
        if (!magnifier.pressing)
            return;

        var caret = magnifier.caretRectangle();
        if (caret === undefined || caret === null)
            return;

        var before = magnifier.lastCaret;
        magnifier.lastCaret = caret;

        if (caret.height > 0 && (magnifier.lineHeight <= 0 || caret.height < magnifier.lineHeight))
            magnifier.lineHeight = caret.height;

        if (magnifier.dragging && before
                && (caret.width !== before.width || caret.height !== before.height))
            magnifier.engaged = true;
    }

    Connections {
        target: magnifier.compositorInstance ? magnifier.compositorInstance.inputMethod : null
        ignoreUnknownSignals: true

        function onCursorRectangleChanged() {
            magnifier.caretMoved();
        }
    }

    //! The field going away mid-drag takes the loupe with it.
    onEditableChanged: if (!editable) release()

    /*
     * The loupe: a rounded window onto the text, above the line it shows so
     * that the finger under the line does not cover it. A line too near the
     * top of the screen for that gets it at the top, over the line itself -
     * which it shows larger anyway - and still above the finger: below it is
     * where the hand is.
     */
    Item {
        id: lens

        objectName: "caretMagnifierLens"

        readonly property real gap: Units.gu(1.5)
        readonly property real radius: Units.gu(1)
        readonly property real lineTop:
            magnifier.lookAt.y - (magnifier.lineHeight > 0 ? magnifier.lineHeight : height / magnifier.zoom) / 2
        //! Whether there is room for it above the line, clear of it.
        readonly property bool above: lineTop - gap - height >= Units.gu(0.5)

        width: Units.gu(15)
        height: Units.gu(6)

        x: Math.max(Units.gu(0.5),
                    Math.min(magnifier.width - width - Units.gu(0.5), magnifier.lookAt.x - width / 2))
        y: Math.max(Units.gu(0.5), lineTop - gap - height)

        //! What of this item's area the loupe shows, before it is enlarged:
        //! the lens's own size over the zoom, centred on lookAt.
        readonly property rect area: Qt.rect(magnifier.lookAt.x - width / magnifier.zoom / 2,
                                             magnifier.lookAt.y - height / magnifier.zoom / 2,
                                             width / magnifier.zoom, height / magnifier.zoom)

        //! The same area in the window's own coordinates, which is what a
        //! ShaderEffectSource takes: the window can be anywhere, and scaled.
        readonly property rect sourceArea: {
            var w = magnifier.sourceWindow;
            if (!w)
                return Qt.rect(0, 0, 0, 0);
            var a = magnifier.mapToItem(w, area.x, area.y);
            var b = magnifier.mapToItem(w, area.x + area.width, area.y + area.height);
            return Qt.rect(a.x, a.y, b.x - a.x, b.y - a.y);
        }

        // A soft edge under the loupe, lifting it off the page.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Units.gu(0.3)
            anchors.topMargin: -Units.gu(0.1)
            anchors.bottomMargin: -Units.gu(0.5)
            radius: lens.radius + Units.gu(0.3)
            color: "#40000000"
        }

        // The page behind the text, for a window that leaves it transparent.
        Rectangle {
            anchors.fill: parent
            radius: lens.radius
            color: "white"
        }

        /*
         * The sampled text, made afresh each time the loupe comes up and
         * thrown away when it goes, so nothing is rendered for it while it is
         * down. Rather than switching one sample's sourceItem to null and back,
         * which once brought up a blank loupe in testing - not seen again, but
         * a texture swapped under a MultiEffect is what CardWindowWrapper's
         * corner mask already came to grief over, and a fresh one has nothing
         * to go stale.
         */
        Loader {
            objectName: "caretMagnifierSampleLoader"

            anchors.fill: parent
            active: magnifier.shown

            sourceComponent: Item {
                ShaderEffectSource {
                    id: sample

                    objectName: "caretMagnifierSample"

                    anchors.fill: parent
                    visible: false
                    sourceItem: magnifier.sourceWindow
                    sourceRect: lens.sourceArea
                    live: true
                    smooth: true
                }

                Rectangle {
                    id: corners

                    anchors.fill: parent
                    radius: lens.radius
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: sample
                    maskEnabled: true
                    maskSource: corners
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }
        }

        // Legacy's pill's grey for the rim.
        Rectangle {
            anchors.fill: parent
            radius: lens.radius
            color: "transparent"
            border.color: "#5A5A5A"
            border.width: Math.max(1, Units.gu(0.15))
        }
    }
}
