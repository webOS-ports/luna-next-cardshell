/*
 * Copyright (C) 2015 Alan Stice <alan@alanstice.com>
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
import LuneOS.Service 1.0
import LunaNext.Common 0.1

MenuListEntry {
    id: volumeElement

    property alias volumeValue: volumeSlider.setValue
    property bool active: true

    selectable: false

    property int margin: 0
    property string soundOutput: "pcm_output"
    property int spacing: Units.gu(0.5)

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
        onInitialized: {
            // org.webosports.service.audio is the audio-service LuneOS no longer
            // ships, so this subscription never delivered anything and the slider
            // sat wherever it was. audiod nests the fields under volumeStatus.
            service.subscribe("luna://com.webos.service.audio/master/getVolume",
                 JSON.stringify({"subscribe": true}),
                 function(message) {
                     var payload = JSON.parse(message.payload);
                     var response = payload.hasOwnProperty("volumeStatus") ? payload.volumeStatus : payload;
                     if (response.hasOwnProperty("soundOutput") && response.soundOutput.length > 0)
                         volumeElement.soundOutput = response.soundOutput;
                     if (response.hasOwnProperty("volume"))
                         volumeValue = response.volume / 100;
                 },
                 function(error) {
                     console.log("Could not retrieve audio: " + error);
                 });
        }
    }

    content:
        Item {
            id: volumeContent
            x: Units.gu(0.4)
            width: volumeElement.width - Units.gu(0.8)
            height: volumeElement.height

            Image {
                id: imgLess
                source: "../../images/statusbar/volume-less.png"
                width: Units.gu(3.2)
                height: Units.gu(3.2)
                x: margin
                y: volumeElement.height/2 - height/2
            }

            Image {
                id: imgMore
                source: "../../images/statusbar/volume-more.png"
                width: Units.gu(3.2)
                height: Units.gu(3.2)
                x: volumeContent.width - width - margin
                y: volumeElement.height/2 - height/2
            }

            Slider {
                id: volumeSlider
                width: volumeContent.width - (imgLess.width + imgMore.width + 2 * margin + 2 * spacing)
                x: volumeContent.width/2 - width/2
                y: volumeContent.height/2 - height/2
                active: volumeElement.active

                onValueChanged: {
                    // audiod requires soundOutput here (REQUIRED_2 with volume).
                    service.call("luna://com.webos.service.audio/master/setVolume",
                                 JSON.stringify({"soundOutput": volumeElement.soundOutput,
                                                 "volume": Math.floor(volumeValue * 100)}),
                                 function(message) { }, function(error) { });
                }

                onSetFlickOverride: {
                    flickOverride(override)
                }
            }
        }
}
