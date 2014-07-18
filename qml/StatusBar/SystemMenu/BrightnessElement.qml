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
import LunaNext.Common 0.1

MenuListEntry {
    id: brightnessElement

    property alias brightnessValue: brightnessSlider.setValue
    property bool active: true

    selectable: false

    property int margin: 0
    property int spacing: 5

    // Right now com.palm.display has no subscription support for the maximumBrightness
    // property and therefor our only way to update it when it changes for example through
    // the settings app is polling ...
    Timer {
        repeat: true
        running: true
        interval: 15000
        onTriggered: updateBrightness()
    }

    function updateBrightness() {
        service.call("palm://com.palm.display/control/getProperty",
                     JSON.stringify({"properties":["maximumBrightness"]}),
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (!response.maximumBrightness)
                             return;
                         brightnessValue = Math.max(0.0, Math.min(newValue, 1.0));
                     },
                     function(error) {
                         console.log("Could not retrieve maximum brightness from display manager: " + error);
                     });
    }

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: updateBrightness()
    }

    content:
        Item {
            id: brightnessContent
            x: 4
            width: brightnessElement.width - 8
            height: brightnessElement.height

            Image {
                id: imgLess
                source: "../../images/statusbar/brightness-less.png"
                x: margin
                y: brightnessElement.height/2 - height/2
            }

            Image {
                id: imgMore
                source: "../../images/statusbar/brightness-more.png"
                x: brightnessContent.width - width - margin
                y: brightnessElement.height/2 - height/2
            }

            Slider {
                id: brightnessSlider
                width: brightnessContent.width - (imgLess.width + imgMore.width + 2 * margin + 2 * spacing)
                x: brightnessContent.width/2 - width/2
                y: brightnessContent.height/2 - height/2
                active: brightnessElement.active

                onValueChanged: {
                    service.call("luna://com.palm.display/control/setProperty",
                                 JSON.stringify({"maximumBrightness":Math.floor(value*100)}),
                                 function(message) { }, function(error) { });
                }

                onSetFlickOverride: {
                    flickOverride(override)
                }
            }
        }
}
