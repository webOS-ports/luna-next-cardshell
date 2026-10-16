import QtQuick 2.0
import LunaNext.Common 0.1

/*!
 * \brief The gesture area's recogniser, made to decide the way legacy webOS did.
 *
 * Legacy's gesture area was not read by LunaSysMgr but by hidd's touch panel
 * plugin, libhidtouchpanel.so (HidTouchpanelGestures.c), configured by
 * /etc/hidd/HidTouchpanel_*.xml. The thresholds below come from decompiling it
 * and from those files, which carry the same gesture values on the Pre, Pre 2,
 * Veer, Pre 3 and TouchPad.
 *
 * What that recogniser does, and so what this one does:
 *  - Everything is decided when the finger lifts, and by distance only. There
 *    is no speed test, so a slow, deliberate swipe counts just as a fast one.
 *  - The checks run in a fixed order: tap, then up, then left/right. The first
 *    one that matches is the gesture.
 *
 * Legacy's numbers are touch panel pixels, the same on every device. They are
 * taken here at the original Pre's density (320x480, gestureBound 480) and
 * converted with Units.dp, so they keep the same size for the finger on a
 * denser screen.
 */
MouseArea {
    id: swipeArea

    signal tapped()
    signal swipeCanceled()
    signal swipeUpGesture(int modifiers)
    signal swipeLeftGesture(int modifiers)
    signal swipeRightGesture(int modifiers)

    /*!
     * A tap is a touch that never strays further than this from where it went
     * down. There is no time limit: legacy counted a long touch that did not
     * move as a tap too. (tapRadius 12)
     */
    property real tapRadius: Units.dp(12)

    /*!
     * Legacy only took a tap in the middle of the gesture area, between
     * homeButtonLeftBound and homeButtonRightBound (104 and 216 of 320). A tap
     * either side came out as HOME_LEFT or HOME_RIGHT, which LunaSysMgr mapped
     * to no key at all (hiddtp_qws.cpp lookupGesture), so it did nothing.
     */
    property real homeZoneLeft: 104 / 320
    property real homeZoneRight: 216 / 320

    //! Back and forward: further than this sideways. (BACK, MENU strokeLength 35)
    property real strokeLength: Units.dp(35)

    /*!
     * Up: the finger has to leave the gesture area and lift at least this far
     * above it (gestureBound - extendedGestureBound: 480 - 459 on the Pre 2).
     * A swipe that stays inside the area is not an up swipe.
     */
    property real launcherMargin: Units.dp(21)

    /*!
     * A second back is dropped when it follows a back that ended in the middle
     * of the area within a second, and starts there too: the finger bouncing
     * on the glass after a swipe, not a second request. The middle here is the
     * tap zone widened by 39 pixels each side. (CheckSwipeGesture,
     * maybeBlockNextBack)
     */
    property real backRepeatMargin: Units.dp(39)
    property int backRepeatWindowMs: 1000

    /*!
     * A long swipe, further than this and across the middle of the area, is
     * legacy's previous/next (NEXT, PREV strokeLength 125). LunaSysMgr turns
     * those into plain back and forward unless advanced gestures are on
     * (SystemUiController::handleKeyEvent, sysUiEnableNextPrevGestures, off by
     * default on phones), so they are reported as back and forward here. They
     * are checked before back, so the bounce filter above does not apply.
     */
    property real longStrokeLength: Units.dp(125)

    property real _startX: 0
    property real _startY: 0
    property bool _withinTapRadius: false
    property bool _backRepeatArmed: false
    property real _backRepeatArmedAt: 0

    function _inHomeZone(x, margin) {
        return x >= width * homeZoneLeft - margin && x <= width * homeZoneRight + margin;
    }

    //! From one side of the middle zone to the other. (CrossedHomeButton)
    function _crossedHomeZone(startX, endX) {
        var left = width * homeZoneLeft;
        var right = width * homeZoneRight;
        return (startX < left && endX > right) || (startX > right && endX < left);
    }

    /*!
     * Whether this back is the bounce of the previous one, and remember this one
     * in case the next back is its bounce.
     */
    function _isRepeatedBack(startX, endX) {
        var repeated = false;

        if (_backRepeatArmed) {
            _backRepeatArmed = false;
            repeated = _inHomeZone(startX, backRepeatMargin) &&
                       Date.now() - _backRepeatArmedAt < backRepeatWindowMs;
        }

        if (!repeated && _inHomeZone(endX, backRepeatMargin)) {
            _backRepeatArmed = true;
            _backRepeatArmedAt = Date.now();
        }

        return repeated;
    }

    onPressed: (mouse) => {
        _startX = mouse.x;
        _startY = mouse.y;
        _withinTapRadius = true;
    }

    onPositionChanged: (mouse) => {
        var dx = mouse.x - _startX;
        var dy = mouse.y - _startY;

        if (dx * dx + dy * dy > tapRadius * tapRadius)
            _withinTapRadius = false;
    }

    onReleased: (mouse) => {
        if (_withinTapRadius) {
            if (_inHomeZone(_startX, 0))
                tapped();
            return;
        }

        // The area's own top edge is y = 0, so above it is negative.
        if (mouse.y <= -launcherMargin) {
            swipeUpGesture(mouse.modifiers);
            return;
        }

        var dx = mouse.x - _startX;

        if (Math.abs(dx) > longStrokeLength && _crossedHomeZone(_startX, mouse.x)) {
            if (dx < 0)
                swipeLeftGesture(mouse.modifiers);
            else
                swipeRightGesture(mouse.modifiers);
            return;
        }

        if (dx < -strokeLength) {
            if (!_isRepeatedBack(_startX, mouse.x))
                swipeLeftGesture(mouse.modifiers);
            return;
        }

        if (dx > strokeLength) {
            swipeRightGesture(mouse.modifiers);
            return;
        }

        swipeCanceled();
    }
}
