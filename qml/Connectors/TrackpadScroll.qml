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
import WebOSCoreCompositor 1.0

/*!
 * \brief Makes the trackpad scroll inside applications, by being a finger.
 *
 * A phone's trackpad is an arrow-key device: sliding it sends Up, Down, Left and
 * Right, and nothing else. Applications here were written for a touchscreen and
 * scroll by being dragged, so arrows arriving at one do precisely nothing - the
 * list sits there while the thumb works. A QML application's ListView only moves
 * on an arrow if something inside it holds the focus and asks for key
 * navigation, which none of them do, and a web application is no better off.
 *
 * So the arrows are turned into what the applications do understand: a finger.
 * Each tick of the trackpad drags the page a little further, and when the ticks
 * stop the finger lifts. One flick is one drag rather than a dozen separate
 * prods, which is also what stops a short one from reading as a tap - the very
 * first move is already further than any tap threshold.
 *
 * It has to be a key filter rather than a Keys handler: a focused application
 * holds the keyboard focus, so its keys never reach the shell's own QML at all
 * (the same reason KeyboardActivity is a filter). And it only does any of this
 * while an application's own window is the thing on screen - see \a active -
 * because in the shell's own UI the arrows already mean something.
 *
 * Wheel events would be the obvious thing to send instead, and cannot be:
 * QWaylandSeat::sendMouseWheelEvent is not invokable from QML. The touch API is.
 */
Item {
    id: trackpadScroll

    //! Whether an application's own window is what the arrows should reach. The
    //! shell binds this; while it is false every key goes on its way untouched.
    property bool active: false

    //! Where to ask which window that is - the shell passes its own function,
    //! because compositor.activeSurface is empty for some applications (a
    //! browser_shell one among them) and the card view is never wrong about
    //! what it is showing.
    property var windowInFront: null

    //! How far one tick of the trackpad drags the page. Well past the distance
    //! at which a press and a release would otherwise be taken for a tap, and
    //! far enough that a flick of a dozen ticks covers real ground.
    property int stepPixels: 80

    /*!
     * \brief How long after the last tick the finger lifts.
     *
     * Short, and that matters for more than tidiness: the page works out the
     * velocity to carry on with from how the touch point was moving just before
     * it was released, so a finger that hangs about after the last tick lets
     * that estimate decay to nothing and the page stops dead where the drag
     * ended. Measured against a real thumb on the same page: the thumb travels
     * some 300 px and the page carries on to 880, while a drag released late
     * stopped at 120. Lifting while the finger is still moving is the whole
     * difference. Still longer than the 24 ms between one flick's ticks, so a
     * flick stays a single drag rather than breaking into several.
     */
    property int liftDelayMs: 80

    //! How close to the edge the finger may get before it has to be picked up.
    //! Small: the further it can travel in one go, the more speed it has to
    //! hand over when it lifts.
    property int edgeMarginPixels: 16

    /*!
     * \brief How long the trackpad is ignored after the finger ran out of glass.
     *
     * A finger that reaches the bottom of the screen lifts, and the page flies
     * on by itself; putting it straight back down to use up the rest of the
     * flick would only stop that dead, because a touch on a moving page is how
     * you halt it. So the rest of the burst is let go - the flick has already
     * been spent - and the next one starts a new drag. Long enough to outlast
     * the tail of a burst, short enough not to be in the way of a second flick.
     */
    property int spentIgnoreMs: 250

    //! What WebOSKeyFilter::Result is worth. The enum is not registered for QML,
    //! so these have to be the numbers - see HardwareKeys, which says the same.
    readonly property int resultAccepted: 1     //!< ours; goes no further
    readonly property int resultNextPolicy: 2   //!< not ours; carry on

    //! A touch point id the touchscreen itself will not be using, so a synthetic
    //! finger and a real one cannot be mistaken for each other.
    readonly property int touchId: 42

    /*!
     * \brief True while the application is expecting something to be typed.
     *
     * A focused text field is the one thing in an application that has a real
     * use for the arrows - moving the caret - so while one has the focus they
     * are left well alone and scrolling waits. The compositor already knows:
     * a client activates the text-input protocol when it focuses a field, which
     * is the same thing that would raise the on-screen keyboard, so this holds
     * whether that keyboard is showing or suppressed on a keyboard device.
     */
    readonly property bool typing: !!compositor && !!compositor.inputMethod &&
                                   compositor.inputMethod.active

    //! A field just took the focus mid-scroll: take the finger off the glass and
    //! let the application have its arrows.
    onTypingChanged: if (trackpadScroll.typing) trackpadScroll._lift();

    property bool _installed: false
    property bool _down: false
    property bool _spent: false
    property var _item: null
    property real _x: 0
    property real _y: 0

    KeyFilter { id: trackpadKeyFilter }

    Component.onCompleted: trackpadScroll._install()

    //! The window went away or the shell came back to the front: the finger has
    //! to come off the glass, or the application is left mid-drag for ever.
    onActiveChanged: if (!trackpadScroll.active) trackpadScroll._lift();

    Timer {
        id: liftTimer
        interval: trackpadScroll.liftDelayMs
        repeat: false
        onTriggered: trackpadScroll._lift()
    }

    Timer {
        id: spentTimer
        interval: trackpadScroll.spentIgnoreMs
        repeat: false
        onTriggered: trackpadScroll._spent = false
    }

    function _install() {
        if (trackpadScroll._installed)
            return;

        if (!compositor) {
            console.warn("TrackpadScroll: no compositor, the trackpad will not scroll");
            return;
        }

        // Reuse whichever filter is already installed - KeyboardActivity and
        // HardwareKeys may have put one there - so they do not fight over
        // compositor.keyFilter.
        if (!compositor.keyFilter)
            compositor.keyFilter = trackpadKeyFilter;

        compositor.keyFilter.addKeyFilter(trackpadScroll._onKey, "trackpadScroll");
        trackpadScroll._installed = true;
    }

    function _onKey(keycode, pressed, autoRepeat, nativeModifiers) {
        if (!trackpadScroll.active || trackpadScroll.typing)
            return trackpadScroll.resultNextPolicy;

        const dx = keycode === Qt.Key_Left ? -1 : keycode === Qt.Key_Right ? 1 : 0;
        const dy = keycode === Qt.Key_Up ? -1 : keycode === Qt.Key_Down ? 1 : 0;

        if (dx === 0 && dy === 0)
            return trackpadScroll.resultNextPolicy;

        // Auto-repeat counts: a held arrow key is somebody asking to keep
        // scrolling, and the trackpad never sends one anyway.
        if (pressed)
            trackpadScroll._drag(dx, dy);

        // Consume press and release together. Having turned the press into a
        // drag, letting the release through as well would give the application
        // half an event of something it never saw the start of.
        return trackpadScroll.resultAccepted;
    }

    function _drag(dx, dy) {
        if (trackpadScroll._spent)
            return; // the page is flying; let it

        const item = trackpadScroll.windowInFront ? trackpadScroll.windowInFront() : null;
        if (!item || !item.surface || item.width <= 0 || item.height <= 0)
            return;

        if (trackpadScroll._down && trackpadScroll._item !== item)
            trackpadScroll._lift(); // the foreground window changed under us

        // The page follows the finger, so "down" on the trackpad - show me what
        // is below this - is the finger travelling *up* the glass.
        const byX = -dx * trackpadScroll.stepPixels;
        const byY = -dy * trackpadScroll.stepPixels;

        if (!trackpadScroll._down)
            trackpadScroll._press(item);

        trackpadScroll._moveBy(byX, byY);

        liftTimer.restart();
    }

    function _moveBy(dx, dy) {
        const item = trackpadScroll._item;
        if (!item)
            return;

        const margin = trackpadScroll.edgeMarginPixels;
        var x = trackpadScroll._x + dx;
        var y = trackpadScroll._y + dy;

        // The finger has run out of glass. It lifts - at speed, so the page flies
        // on - and the rest of this flick is let go rather than pressing down
        // again and stopping what was just thrown.
        if (x < margin || x > item.width - margin || y < margin || y > item.height - margin) {
            trackpadScroll._lift();
            trackpadScroll._spent = true;
            spentTimer.restart();
            return;
        }

        trackpadScroll._x = x;
        trackpadScroll._y = y;
        trackpadScroll._send("sendTouchPointMoved");
    }

    /*!
     * \brief Put the finger down in the middle of the card.
     *
     * Not down at the edge it is travelling from, tempting as that is for the
     * extra room: the edges of a card are where an application keeps its
     * toolbars, and a finger that lands on one is pressing a button rather than
     * starting a scroll. Atlas was shut by exactly that during a measurement -
     * the drag began on its bottom bar. Half a card of travel is enough anyway,
     * because the distance comes from the flick and not from the drag: a real
     * thumb measured on the same page travelled around 300 px and carried the
     * page 880.
     */
    function _press(item) {
        trackpadScroll._item = item;
        trackpadScroll._x = item.width / 2;
        trackpadScroll._y = item.height / 2;
        trackpadScroll._down = true;
        trackpadScroll._send("sendTouchPointPressed");
    }

    function _lift() {
        liftTimer.stop();

        if (!trackpadScroll._down)
            return;

        trackpadScroll._send("sendTouchPointReleased");
        trackpadScroll._down = false;
        trackpadScroll._item = null;
    }

    /*!
     * \brief One touch point, and the frame that tells the client to act on it.
     *
     * Every one of these has to be followed by a frame event or the client is
     * still waiting for the rest of the touch when the next one arrives, which
     * looks exactly like nothing happening.
     */
    function _send(what) {
        const item = trackpadScroll._item;
        if (!item || !item.surface || !compositor || !compositor.defaultSeat)
            return;

        const seat = compositor.defaultSeat;
        const at = Qt.point(trackpadScroll._x, trackpadScroll._y);

        if (what === "sendTouchPointPressed")
            seat.sendTouchPointPressed(item.surface, trackpadScroll.touchId, at);
        else if (what === "sendTouchPointMoved")
            seat.sendTouchPointMoved(item.surface, trackpadScroll.touchId, at);
        else
            seat.sendTouchPointReleased(item.surface, trackpadScroll.touchId, at);

        seat.sendTouchFrameEvent(item.surface.client);
    }
}
