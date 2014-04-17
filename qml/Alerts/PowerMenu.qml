/*
 * Copyright (C) 2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2014 Herman van Hazendonk <github.com@herrie.org>
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
import "../Utils"

Item {
    id: root

    visible: false

    property real contentMargin: Units.gu(2)
    height: powerMenuColumn.height + contentMargin

    Rectangle {
        id: bgImage
        radius: 10
        color: "black"
        opacity: 0.8

        anchors.centerIn: powerMenuColumn
        width: root.width
        height: root.height
    }

/*
    BorderImage {
        id: bgImage
        source: Qt.resolvedUrl("../images/systemui/popup-bg.png")

        anchors.centerIn: powerMenuColumn
        width: powerMenuColumn.width + 100
        height: powerMenuColumn.height + 100
        smooth: true;
        border { left: 100; top: 90; right: 100; bottom: 90 }
        opacity: active ? 1.0 : inactiveOpacity
    }
    */
    Column {
        id: powerMenuColumn

        property real buttonsHeight: Units.gu(4);

        anchors.top: root.top
        width: root.width - contentMargin

        ActionButton {
            width: powerMenuColumn.width
            height: powerMenuColumn.buttonsHeight

            caption: "Airplane Mode"
            affirmative: true

            onAction: {
                root.visible = false;
                console.log("Airplane Mode requested !")
                //TODO: Add actual action!
            }
        }
        Item {
            height: Units.gu(1) / 2
            width: powerMenuColumn.width
        }

        ActionButton {
            width: powerMenuColumn.width
            height: powerMenuColumn.buttonsHeight

            caption: "Device Restart"
            alternative: true

            onAction: {
                root.visible = false;
                console.log("Reboot requested !")
                powerKeyService.call("palm://com.palm.power/shutdown/machineReboot",
                    JSON.stringify({"reason": "User requested reboot"}), undefined, onRebootActionError)
            }

            function onRebootActionError(message) {
                console.log("Failed to call machine reboot service: " + message);
            }
        }
        Item {
            height: Units.gu(1) / 2
            width: powerMenuColumn.width
        }

        ActionButton {
            width: powerMenuColumn.width
            height: powerMenuColumn.buttonsHeight

            caption: "Luna-Next Restart"
            //affirmative: true
            alternative: true

            onAction: {
                root.visible = false;
                console.log("Luna-Next restart requested !")
                Qt.quit();
            }
        }
        Item {
            height: 5
            width: powerMenuColumn.width
        }

        ActionButton {
            width: powerMenuColumn.width
            height: powerMenuColumn.buttonsHeight

            caption: "Shut Down"
            negative: true

            onAction: {
                root.visible = false;
                console.log("Shutdown requested !")
                powerKeyService.call("palm://com.palm.power/shutdown/machineOff",
                    JSON.stringify({"reason": "User requested poweroff"}), undefined, onPowerOffActionError)
            }

            function onPowerOffActionError(message) {
                console.log("Failed to call machine poweroff service: " + message);
            }
        }
        Item {
            height: 5
            width: powerMenuColumn.width
        }

        ActionButton {
            width: powerMenuColumn.width
            height: powerMenuColumn.buttonsHeight

            id: cancelButton
            caption: "Cancel"

            onAction: root.visible = false
        }
    }

    LunaService {
        id: powerKeyService

        name: "org.webosports.luna"
        usePrivateBus: true

        onInitialized: {
            powerKeyService.subscribe("palm://com.palm.bus/signal/addmatch",
                JSON.stringify({"category":"/com/palm/display","name":"powerKeyPressed","subscribe":true}),
                onPowerKeyStatusChanged, onError);

        }

        function onPowerKeyStatusChanged(message) {
            var response = JSON.parse(message.payload);
            if (response.showDialog) {
                root.visible = true;
            }
        }

        function onError(message) {
            console.log("Failed to call powerkey service: " + message);
        }
    }
}
