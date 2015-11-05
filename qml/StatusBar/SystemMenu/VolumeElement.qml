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
    property int spacing: Units.gu(0.5)

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            service.subscribe("luna://org.webosports.audio/getStatus",
                 JSON.stringify({"subscribe": true}),
                 function(message) {
                     var response = JSON.parse(message.payload);
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
                    service.call("luna://org.webosports.audio/setVolume",
                                 JSON.stringify({"volume": Math.floor(volumeValue * 100)}),
                                 function(message) { }, function(error) { });
                }

                onSetFlickOverride: {
                    flickOverride(override)
                }
            }
        }
}
