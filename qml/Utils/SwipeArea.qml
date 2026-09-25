import QtQuick 2.0
import LunaNext.Common 0.1

MouseArea {
    id: swipeArea

    signal clicked()
    signal swipeCanceled()
    signal swipeUpGesture(int modifiers)
    signal swipeDownGesture(int modifiers)
    signal swipeLeftGesture(int modifiers)
    signal swipeRightGesture(int modifiers)

    property real swipeVelocityThreshold: 0.2  /* pixels per ms */

    /* A finger that pauses before lifting releases at zero velocity, so such a
       gesture is judged by the distance it travelled since the press instead.
       This is a finger distance, so it is expressed in grid units and scales
       with the screen like the shell's other gesture lengths (compare
       GestureHandler.minimalFlickLength, Units.gu(10)). */
    property real swipeDistanceThreshold: Units.gu(25)

    /* A SwipeArea narrower than swipeDistanceThreshold could never satisfy it
       horizontally, so sideways gestures ask for at most this fraction of the
       width. There is deliberately no vertical equivalent: the gesture area is
       a short bar the finger leaves almost immediately, so its height says
       nothing about the distance available. */
    property real swipeDistanceWidthFraction: 0.25

    property real _pressedX: 0
    property real _pressedY: 0
    /* Where the finger went down. _pressedX/_pressedY follow it while it moves,
       so they cannot serve as the origin of the gesture. */
    property real _startX: 0
    property real _startY: 0
    property real _velocityX: 0
    property real _velocityY: 0
    property var _timeStamp
    property bool _swipeInitiated: false

    onPressed: (mouse) => {
        _pressedX = mouse.x;
        _pressedY = mouse.y;
        _startX = mouse.x;
        _startY = mouse.y;
        // a new gesture inherits nothing from the previous one
        _velocityX = 0;
        _velocityY = 0;
        _timeStamp = Date.now();

        // we manage this event
        // mouse.accepted = true;
    }

    onPressAndHold: (mouse) => {
        // just defining the function, so that mouse.wasHeld is true
        mouse.accepted = false;
    }

    onPositionChanged: (mouse) => {
        if (mouse.wasHeld) return;  // if the intent is a long press, ignore the movements

        var xDiff = mouse.x - _pressedX;
        var yDiff = mouse.y - _pressedY;

        // don't compute anything if the distance is too short
        if( Math.abs(xDiff) > 10 || Math.abs(yDiff) > 10 ) {
            var newTimeStamp = Date.now();
            var diffTime = newTimeStamp - _timeStamp; /* in milliseconds here */

            _velocityX = xDiff/diffTime;
            _velocityY = yDiff/diffTime;

            // update position for next time
            _pressedX = mouse.x;
            _pressedY = mouse.y;
            // update also time stamp
            _timeStamp = newTimeStamp;

            _swipeInitiated = true;
        }
    }

    /* Emit the gesture the travelled distance describes, dominant axis winning,
       and report whether it was far enough to count. */
    function _emitDistanceGesture(mouse) {
        var totalX = mouse.x - _startX;
        var totalY = mouse.y - _startY;

        if( Math.abs(totalX) >= Math.abs(totalY) ) {
            if( Math.abs(totalX) <= Math.min(width * swipeDistanceWidthFraction, swipeDistanceThreshold) )
                return false;

            if( totalX > 0 )
                swipeRightGesture(mouse.modifiers);
            else
                swipeLeftGesture(mouse.modifiers);
            return true;
        }

        if( Math.abs(totalY) <= swipeDistanceThreshold )
            return false;

        if( totalY > 0 )
            swipeDownGesture(mouse.modifiers);
        else
            swipeUpGesture(mouse.modifiers);
        return true;
    }

    onReleased: (mouse) => {
        if (mouse.wasHeld) return; // don't interfere with long press events

        // Evaluate how much time has passed since the last call to onPositionChanged
        var newTimeStamp = Date.now();
        var diffTime = newTimeStamp - _timeStamp; /* in milliseconds here */
        // During that time, the mouse hasn't moved more than 10 pixels.
        // That enables us to know whether the swipe is still in progress or not.
        var paused = ( 10/diffTime < swipeVelocityThreshold );
        if( paused ) {
            _velocityX = 0;
            _velocityY = 0;
        }

        if( Math.abs(_velocityX) > swipeVelocityThreshold || Math.abs(_velocityY) > swipeVelocityThreshold ) {
            /* Consider this as a swipe */
            var angleTanAbs = Math.abs(_velocityX/_velocityY);

            /* Separate the various swipe cases */
            if( angleTanAbs < 1 /*Math.tan(Math.PI/4)*/ ) { // swipe Up or Down
                if( _velocityY>0 )
                    swipeDownGesture(mouse.modifiers);
                else
                    swipeUpGesture(mouse.modifiers);
            }
            else {  // only posibility left: swipe Left or Right
                if( _velocityX>0 ) {
                    swipeRightGesture(mouse.modifiers);
                }
                else {
                    swipeLeftGesture(mouse.modifiers);
                }
            }
        }
        /* The finger paused before lifting, which zeroed the velocity above -
           but pausing at the end of a deliberate swipe is natural, and dropping
           those made the gesture area feel unreliable. Fall back to the whole
           distance travelled. */
        else if( paused && _swipeInitiated && _emitDistanceGesture(mouse) ) {
            /* handled as a swipe */
        }
        else {
            if( _swipeInitiated ) {
                swipeCanceled();
            }
            else if( !mouse.wasHeld ) {
                clicked();
            }
        }

        _swipeInitiated = false;
    }
}
