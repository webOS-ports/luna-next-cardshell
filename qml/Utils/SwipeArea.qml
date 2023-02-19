import QtQuick 2.0

MouseArea {
    id: swipeArea

    signal clicked()
    signal swipeCanceled()
    signal swipeUpGesture(int modifiers)
    signal swipeDownGesture(int modifiers)
    signal swipeLeftGesture(int modifiers)
    signal swipeRightGesture(int modifiers)

    property real swipeVelocityThreshold: 0.2  /* pixels per ms */

    property real _pressedX: 0
    property real _pressedY: 0
    property real _velocityX: 0
    property real _velocityY: 0
    property var _timeStamp
    property bool _swipeInitiated: false

    onPressed: (mouse) => {
        _pressedX = mouse.x;
        _pressedY = mouse.y;
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

    onReleased: (mouse) => {
        if (mouse.wasHeld) return; // don't interfere with long press events

        // Evaluate how much time has passed since the last call to onPositionChanged
        var newTimeStamp = Date.now();
        var diffTime = newTimeStamp - _timeStamp; /* in milliseconds here */
        // During that time, the mouse hasn't moved more than 10 pixels.
        // That enables us to know whether the swipe is still in progress or not.
        if( 10/diffTime < swipeVelocityThreshold ) {
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
        else {
            if( _swipeInitiated ) {
                swipeCanceled();
            }
            else if( !mouse.wasHeld ) {
                clicked(mouse);
            }
        }

        _swipeInitiated = false;
    }
}
