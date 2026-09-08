/*
 * Copyright (C) 2015 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.9
import QtSensors 5.11
import LuneOS.Service 1.0
import "LunaSysAPI"

Item {
    Preferences {
        id: preferences
    }

    OrientationSensor {
        id: sensor

        property int sensorOrientationAngle: 0

        onReadingChanged: {
          if (reading.orientation === OrientationReading.TopUp) {
             sensorOrientationAngle = 0;
          }
          else if (reading.orientation === OrientationReading.LeftUp) {
             sensorOrientationAngle = 90;
          }
          else if (reading.orientation === OrientationReading.TopDown) {
             sensorOrientationAngle = 180;
          }
          else if (reading.orientation === OrientationReading.RightUp) {
             sensorOrientationAngle = 270;
          }
        }
    }

    id: orientationHelperItem
    x: 0; y: 0
    height: parent.height; width: parent.width

    property real __lockedRotationAngle: 0
    property bool automaticOrientation: false
    property int orientationAngle: !locked ? sensor.sensorOrientationAngle : __lockedRotationAngle;
    property bool transitionEnabled: false
    property bool rotationLock: false
    property bool locked: rotationLock || preferences.rotationLock

    property real rotationCenterX: parent.width/2;
    property real rotationCenterY: parent.height/2;

    transform: Rotation { origin.x: rotationCenterX; origin.y: rotationCenterY; angle: -orientationAngle}
    Behavior on orientationAngle { RotationAnimation { duration: 500; direction: RotationAnimation.Shortest}}

    Connections {
        target: preferences;
        function onRotationLockChanged() {
            if( preferences.rotationLock ) __lockedRotationAngle = orientationAngle;
        }
    }

    // Tell WebAppMgr where the device is pointing.
    //
    // LunaSysMgr held the shell and the web application host in one process and
    // set this directly (WebAppMgrProxy::setOrientation). They are separate
    // processes now, so nothing was telling WAM anything and
    // PalmSystem.screenOrientation stayed at its hard-coded "up" - which is why
    // Enyo's ApplicationEvents onWindowRotated never fires
    // (luneos-testing#13). enyo.sendOrientationChange() compares that property
    // against its own last value, so a constant means no rotation is ever
    // dispatched.
    //
    // The names are LunaSysMgr's, and the angles follow its convention:
    // HostBase::setOrientation rotated the UI by 90 for "right" and 270 for
    // "left", and this item rotates its content by -orientationAngle, so
    // RightUp (270) is "right" and LeftUp (90) is "left".
    function orientationName(angle) {
        switch (angle % 360) {
        case 90:  return "left";
        case 180: return "down";
        case 270: return "right";
        default:  return "up";
        }
    }

    property string __lastPublishedOrientation: ""

    function publishOrientation() {
        var name = orientationName(orientationAngle);
        if (name === __lastPublishedOrientation)
            return;
        __lastPublishedOrientation = name;
        console.log("OrientationHelper: orientation " + orientationAngle + " -> " + name);
        webAppMgrService.call("luna://com.palm.webappmanager/setOrientation",
                              JSON.stringify({"orientation": name}),
                              function (message) {
                                  // A rejected call comes back here with
                                  // returnValue false, not through the error
                                  // callback below, so it has to be checked or
                                  // a failure is silent. console.log is not
                                  // routed to the journal, only warnings are.
                                  var response = JSON.parse(message.payload);
                                  if (!response.returnValue)
                                      console.warn("OrientationHelper: setOrientation rejected: " + message.payload);
                              },
                              function(error) {
                                  console.warn("OrientationHelper: setOrientation failed: " + JSON.stringify(error));
                              });
    }

    // The angle animates, so publish where it settled rather than every frame.
    onOrientationAngleChanged: publishTimer.restart()

    Timer {
        id: publishTimer
        interval: 100
        onTriggered: orientationHelperItem.publishOrientation()
    }

    LunaService {
        id: webAppMgrService
        name: "com.webos.surfacemanager-cardshell"
        onInitialized: orientationHelperItem.publishOrientation()
    }

    states: [
        State {
            name: "normal"
            when: orientationAngle === 0 || orientationAngle === 180
            PropertyChanges {
                target: orientationHelperItem
                height: parent.height
                width: parent.width
                rotationCenterX: parent.width/2;
                rotationCenterY: parent.height/2;
            }
        },
        State {
            name: "rotated"
            when: orientationAngle === 90
            PropertyChanges {
                target: orientationHelperItem
                height: parent.width
                width: parent.height
                rotationCenterX: parent.height/2;
                rotationCenterY: parent.height/2;
            }
        },
        State {
            name: "rotatedInversed"
            when: orientationAngle === 270
            PropertyChanges {
                target: orientationHelperItem
                height: parent.width
                width: parent.height
                rotationCenterX: parent.width/2;
                rotationCenterY: parent.width/2;
            }
        }
    ]

    Component.onCompleted: {
        sensor.start();
    }

    function setOrientation(angle) {
        if (locked) return;
        orientationAngle = angle;
    }

    function setLocked(lock) {
        if (lock) __lockedRotationAngle = orientationAngle;
        rotationLock = lock;
    }

    function convertRawPos(pos) {
        return mapFromItem(parent, pos.x, pos.y);
    }
}
