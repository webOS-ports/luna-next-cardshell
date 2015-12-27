/*
 * Copyright (C) 2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2014 Herman van Hazendonk <github.com@herrie.org>
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
import QtMultimedia 5.4
import "../Utils"

Item {
    id: root

    visible: false

    property real contentMargin: Units.gu(2)
    height: powerMenuColumn.height + contentMargin

    signal showPowerMenu()
    onShowPowerMenu: {
        root.visible = true;
    }

    Audio {
        id: shutdownSound
        source: "/usr/palm/sounds/shutdown.mp3"
    }

    Rectangle {
        id: bgImage
        radius: 10
        color: "black"
        opacity: 0.8

        anchors.centerIn: powerMenuColumn
        width: root.width
        height: root.height
    }

    Column {
        id: powerMenuColumn

        property real buttonsHeight: Units.gu(4);

        anchors.top: root.top
        width: root.width - contentMargin

        ActionButton {
            width: powerMenuColumn.width
            height: powerMenuColumn.buttonsHeight

            caption: "Device Restart"
            alternative: true

            onAction: {
                root.visible = false;
                console.log("Reboot requested !")
                shutdownSound.play();
                powerKeyService.call("luna://com.palm.power/shutdown/machineReboot",
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
            width: powerMenuColumn.width;
            height: powerMenuColumn.buttonsHeight;

            caption: "Luna-Next Restart";
            alternative: true;

            onAction: {
                root.visible = false;
                console.log("Luna-Next restart requested !");
                Qt.quit();
            }
        }
        Item {
            height: Units.gu(1) / 2
            width: powerMenuColumn.width;
        }

        ActionButton {
            width: powerMenuColumn.width
            height: powerMenuColumn.buttonsHeight

            caption: "Shut Down"
            negative: true

            onAction: {
                root.visible = false;
                console.log("Shutdown requested !")
                shutdownSound.play();
                powerKeyService.call("luna://com.palm.power/shutdown/machineOff",
                    JSON.stringify({"reason": "User requested poweroff"}), undefined, onPowerOffActionError)
            }

            function onPowerOffActionError(message) {
                console.log("Failed to call machine poweroff service: " + message);
            }
        }
        Item {
            height: Units.gu(1) / 2
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
    }
}
