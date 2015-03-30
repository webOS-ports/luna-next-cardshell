/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext.Common 0.1

Item {
    property bool   isPressed: false
    property bool   active: true
    property string caption: "Button"
    property bool   affirmative: false
    property bool   negative:    false
    property bool   alternative:    false
    property real   inactiveOpacity: 0.70

    property string affirmativeButtonImage: Qt.resolvedUrl("../images/systemui/palm-notification-button-affirmative.png");
    property string affirmativeButtonImagePressed: Qt.resolvedUrl("../images/systemui/palm-notification-button-affirmative-press.png");
    property string negativeButtonImage: Qt.resolvedUrl("../images/systemui/palm-notification-button-negative.png");
    property string negativeButtonImagePressed: Qt.resolvedUrl("../images/systemui/palm-notification-button-negative-press.png");
    property string alternativeButtonImage: Qt.resolvedUrl("../images/systemui/palm-notification-button-alternate.png");
    property string alternativeButtonImagePressed: Qt.resolvedUrl("../images/systemui/palm-notification-button-alternate-press.png");
    property string neutralButtonImage: Qt.resolvedUrl("../images/systemui/palm-notification-button.png");
    property string neutralButtonImagePressed: Qt.resolvedUrl("../images/systemui/palm-notification-button-press.png");

    Image {
        id: pressedBkg
        source: affirmative ?    ( !isPressed ? affirmativeButtonImage : affirmativeButtonImagePressed ) :
                 ( negative ?    ( !isPressed ? negativeButtonImage    : negativeButtonImagePressed )   :
                 ( alternative ? ( !isPressed ? alternativeButtonImage    : alternativeButtonImagePressed )   :
                                 ( !isPressed ? neutralButtonImage : neutralButtonImagePressed )  ) )
        visible: true;
        anchors.fill: parent
        layer.mipmap: true;
        //border { left: 40; top: 40; right: 40; bottom: 40 }
        opacity: active ? 1.0 : inactiveOpacity
    }

    Text {
        id: buttonText
        text: caption
        anchors.fill: parent
        anchors.margins: parent.height * 0.3

        fontSizeMode: Text.Fit
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: "#FFF";
        font.bold: true;
        font.family: Settings.fontStatusBar
        font.pixelSize: parent.height;
        opacity: active ? 1.0 : inactiveOpacity
    }

    MouseArea {
        id: mouseArea
        enabled: true;
        anchors.fill: parent
        onPressAndHold:  setPressed(true);
        onPressed: { mouse.accepted = true; setPressed(true); }
        onReleased: {setPressed(false);}
        onExited: {setPressed(false);}
        onCanceled: {setPressed(false);}
        onClicked: {
            actionPerformed()
         }
    }

    function setPressed (pressed) {
        if(active) {
            isPressed = pressed;
        }
    }

    function actionPerformed () {
        if(active) {
            action()
        }
    }

    signal action()
}
