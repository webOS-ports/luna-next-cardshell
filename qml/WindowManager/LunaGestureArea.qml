import QtQuick 2.0
// import Qt.labs.gestures 1.0

Item {
    id: gestureAreaItem

    signal tapGesture
    signal swipeUpGesture(int modifiers)
    signal swipeDownGesture(int modifiers)
    signal swipeLeftGesture(int modifiers)
    signal swipeRightGesture(int modifiers)

    focus: true

    // Black rectangle behind, and a glowing image in front
    Rectangle {
        anchors.fill: parent
        color: "black"
    }
    Image {
        id: glowImage
        anchors.centerIn: parent
        height: parent.height/2
        width: parent.width/2
        source: "../images/glow.png"
        smooth: true
        fillMode: Image.Stretch
    }
    Image {
        id: glowImageMask
        visible: false
        y: glowImage.y
        height: glowImage.height
        width: glowImage.width
        source: "../images/glowMask.png"
        smooth: true
        fillMode: Image.Stretch
    }

    SequentialAnimation {
        id: glowRightToLeft
        PropertyAction { target: glowImageMask; property: "x"; value: glowImage.x + glowImage.width }
        PropertyAction { target: glowImageMask; property: "visible"; value: true }
        NumberAnimation { target: glowImageMask; property: "x"; to: glowImage.x - glowImage.width; duration: 500 }
        PropertyAction { target: glowImageMask; property: "visible"; value: false }
    }
    SequentialAnimation {
        id: glowLeftToRight
        PropertyAction { target: glowImageMask; property: "x"; value: glowImage.x - glowImage.width }
        PropertyAction { target: glowImageMask; property: "visible"; value: true }
        NumberAnimation { target: glowImageMask; property: "x"; to: glowImage.x + glowImage.width; duration: 500 }
        PropertyAction { target: glowImageMask; property: "visible"; value: false }
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_End) {
            console.log("Key: End");
            event.accepted = true;
            swipeUpGesture(0);
        }
        else if(event.key === Qt.Key_Home) {
            console.log("Key: Home");
            event.accepted = true;
            tapGesture();
        }
        else if(event.key === Qt.Key_Escape) {
            console.log("Key: Escape");
            event.accepted = true;
            swipeLeftGesture(0);
        }
    }

    MouseArea {
        id: gestureAreaInput
        anchors.fill: parent

        property real pressedX: 0
        property real pressedY: 0
        property var timeStampPressed: 0

        onPressed: {
            pressedX = mouseX;
            pressedY = mouseY;
            timeStampPressed = Date.now();

            mouse.accepted = true;
        }
        onReleased: {
            var xDiff = mouseX - pressedX;
            var yDiff = mouseY - pressedY;

            var diffTime = Date.now() - timeStampPressed; /* in milliseconds here */

            if( diffTime < 500 &&
                (Math.abs(xDiff) > 10 || Math.abs(yDiff) > 10) ) {
                /* Consider this as a swipe */
                var angleTanAbs = Math.abs(xDiff/yDiff);

                /* Separate the various swipe cases */
                if( angleTanAbs < 1 /*Math.tan(Math.PI/4)*/ ) { // swipe Up or Down
                    if( yDiff>0 )
                        swipeDownGesture(mouse.modifiers);
                    else
                        swipeUpGesture(mouse.modifiers);
                }
                else {  // only posibility left: swipe Left or Right
                    if( xDiff>0 ) {
                        glowLeftToRight.start()
                        swipeRightGesture(mouse.modifiers);
                    }
                    else {
                        glowRightToLeft.start()
                        swipeLeftGesture(mouse.modifiers);
                    }
                }
            }
            else
            {
                tapGesture();
            }

            mouse.accepted = true;
        }
    }
}
