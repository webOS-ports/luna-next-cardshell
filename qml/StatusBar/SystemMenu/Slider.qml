/* @@@LICENSE
*
*      Copyright (c) 2009-2013 LG Electronics, Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* LICENSE@@@ */

import QtQuick 2.0

Item {
    id: slider
    property real  setValue : 0.5
    property bool  active:  true

    property int   railEdgeOffset:   8
    property int   railBorderWidth: 11

    property int   handleGrabTolerance: 12
    property int   railTapTolerance: 20
    property real  railChangeStep: 0.20

    property bool mouseDownOnHandle : false
    property bool mouseDownOnBar:     false
    property int  mouseDownX
    property int  lastMouseX

    signal valueChanged(real value, bool done);
    signal setFlickOverride(bool override);

    height: handle.height + handleGrabTolerance

    function updateBarValue(newVal, ended) {
        var value = clamp(newVal, 0.0, 1.0);

        if(ended || setValue != value) {
            setValue = value;
            valueChanged(setValue, ended);
        }
    }

    function clamp(x, min, max) {
        return Math.max(0.0, Math.min(1.0, x));
    }

    MouseArea {
        id: mouseArea
        property int xOffset: 2*handleGrabTolerance
        enabled: slider.active
        x: -xOffset
        width: parent.width + 2*xOffset
        height: parent.height
        y: (parent.height - mouseArea.height) / 2

        onPressed: {
            setFlickOverride(true);
            var mouseX = mouse.x - xOffset;
            lastMouseX = mouseX;
            if((mouseX > (handle.x - handleGrabTolerance)) && (mouseX < (handle.x + handle.width + handleGrabTolerance))) {
                // mouse down on the slider handle
                mouseDownOnHandle = true;
                mouseDownOnBar = false;
                mouse.accepted = true;
                mouseDownX = mouseX;
            } else if((mouse.y > (handle.y)) && (mouse.y < (handle.y + handle.height))) {
                mouseDownOnBar = true;
                mouseDownOnHandle = false;
                mouse.accepted = true;
                mouseDownX = mouseX;
            }
        }

        onReleased: {
            var mouseX = mouse.x - xOffset;
            setFlickOverride(false);
            if(mouseDownOnHandle && (mouseX != mouseDownX)) {
                // update the handle position for each mouse move
                updateBarValue(getValueForX(mouseX), true);
            } else if(mouseDownOnBar) {
                if(mouseX < handle.x) {
                    updateBarValue(setValue - railChangeStep, true);
                } else {
                    updateBarValue(setValue + railChangeStep, true);
                }
            }

            mouseDownOnHandle = false;
            mouseDownOnBar = false;
        }

        onExited: {
            mouseDownOnBar = false;

            if(!mouseDownOnHandle) {
                setFlickOverride(false);
            }

            if(mouseDownOnBar) {
                valueChanged(setValue, true);
            }
        }

        onCanceled: {
            setFlickOverride(false);
        }

        onPositionChanged: {
            var mouseX = mouse.x - xOffset;
            mouse.accepted = true;

            if(mouseX != lastMouseX) {
                if(mouseDownOnHandle) {
                    // update the handle position for each mouse move
                    var newVal = getValueForX(mouseX);
                    updateBarValue(newVal, false);
                } else if(mouseDownOnBar) {
                   if((mouseX < (mouseDownX - railTapTolerance)) || (mouseX > (mouseDownX + railTapTolerance))) {
                        mouseDownOnBar = false;
                        setFlickOverride(false);
                    }
                }
            }

            lastMouseX = mouseX;
        }

        function getValueForX(x) {
            return ((x - railEdgeOffset) / (slider.width - 2*railEdgeOffset));
        }

    }

    BorderImage {
        id: bar
        source: "../../images/statusbar/slider-track.png"
        width: parent.width;
        border { left: railBorderWidth; top: 0; right: railBorderWidth; bottom: 0 }
        anchors.verticalCenter: parent.verticalCenter
    }

    BorderImage {
        id: barProgress
        source: "../../images/statusbar/slider-track-progress.png"
        width: Math.max(((parent.width - handle.width/2) * setValue + handle.width/2), 2*railBorderWidth)
        border { left: railBorderWidth; top: 0; right: railBorderWidth; bottom: 0 }
        anchors.verticalCenter: parent.verticalCenter
    }

    Image {
        id: handle
        source: "../../images/statusbar/slider-handle.png"
        x: railEdgeOffset + ((slider.width - 2*railEdgeOffset) * setValue) - width/2
        y: slider.height/2 - height/2
    }

}
