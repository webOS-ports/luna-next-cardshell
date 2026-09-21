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
import LuneOS.Service 1.0
import LunaNext.Common 0.1

MenuListEntry {
    id: brightnessElement

    property alias brightnessValue: brightnessSlider.setValue
    property bool active: true

    selectable: false

    property int margin: 0
    property int spacing: Units.gu(0.5)

    // True while the user has the slider under a finger. The subscription must
    // not write setValue in that window: Slider.updateBarValue() works *from* the
    // current setValue - a tap on the rail steps railChangeStep away from it, and
    // a drag is only emitted at all when the computed value differs from it - so
    // a value landing mid-gesture either jerks the handle back or makes the
    // gesture a no-op that never reaches the display manager.
    //
    // This matters more with a subscription than it did with the old poll: the
    // writes the drag itself makes come straight back to us as posts, so without
    // this guard the slider would fight its own echo on every drag.
    readonly property bool userIsAdjusting: brightnessSlider.mouseDownOnHandle
                                         || brightnessSlider.mouseDownOnBar

    // com.palm.display posts maximumBrightness to subscribers now, so the menu
    // follows a change made elsewhere - the Settings app, or the ALS - as it
    // happens. This replaced a 15 s poll, which was the only way to notice such
    // a change before and which fought the user's own gesture whenever it
    // happened to fire mid-drag.
    function subscribeBrightness() {
        service.subscribe("luna://com.palm.display/control/getProperty",
                     JSON.stringify({"properties":["maximumBrightness"], "subscribe":true}),
                     function(message) {
                         var response = JSON.parse(message.payload);
                         if (!response.hasOwnProperty("maximumBrightness"))
                             return;
                         if (userIsAdjusting)
                             return;
                         var newValue = response.maximumBrightness / 100;
                         brightnessValue = Math.max(0.0, Math.min(newValue, 1.0));
                     },
                     function(error) {
                         console.log("Could not subscribe to maximum brightness from display manager: " + error);
                     });
    }

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
        onInitialized: subscribeBrightness()
    }

    content:
        Item {
            id: brightnessContent
            x: Units.gu(0.4)
            width: brightnessElement.width - Units.gu(0.8)
            height: brightnessElement.height

            Image {
                id: imgLess
                source: "../../images/statusbar/brightness-less.png"
                width: Units.gu(3.2)
                height: Units.gu(3.2)
                x: margin
                y: brightnessElement.height/2 - height/2
            }

            Image {
                id: imgMore
                source: "../../images/statusbar/brightness-more.png"
                width: Units.gu(3.2)
                height: Units.gu(3.2)
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
