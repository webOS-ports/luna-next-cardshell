/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013-2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013-2016 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.5
import LunaNext.Common 0.1
// LuneOS Bluetooth wrapper
import LuneOS.Bluetooth 0.2
import "../Connectors"
import "Indicators"

Row {
    id: indicatorsRow

    BatteryService {
        id: batteryService
    }

    TelephonyService {
        id: telephonyService
    }

    WanService {
        id: wanService
    }

    WiFiService {
        id: wifiService
    }

/*    RecorderIndicator {
        id: recorderIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        // FIXME We don't have this yet in luna-surfacemanager it seems. Disable it for now.
        // enabled: compositor.recording
        enabled: false
    }*/

    // airplaneModeService is the shell wide one from CardShell.qml, so this
    // indicator reflects exactly the state the system menu applies.

    FlightmodeStatusIndicator {
        id: flightmodeStatusIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: airplaneModeService.active
    }

    RotationLockIndicator {
        id: rotationLockIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: preferences.rotationLock
    }

    MuteSoundIndicator {
        id: muteSoundIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: preferences.muteSound
    }

    WifiIndicator {
        id: wifiIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: wifiService.powered
        signalBars: wifiService.signalBars
    }
    
    BluetoothIndicator {
        id: bluetoothIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: BluetoothManager.powered
        connected: BluetoothManager.bluetoothOperational
        isTurningOn: BluetoothManager.initializing
    }

    WanStatusIndicator {
        id: wanStatusIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        /*
         * The service indicator that goes with the signal bars: it says which
         * radio access technology the modem is registered on, so it is up
         * whenever there is a mobile network, not only while cellular happens
         * to be carrying the internet connection - it used to be gated on
         * that, which hid it for good on any device with WiFi up.
         *
         * Packet data runs on one SIM at a time, so this reflects the SIM
         * currently selected as the data SIM.
         */
        enabled: telephonyService.powered && !airplaneModeService.active &&
                 wanService.technology !== "none"
        technology: wanService.technology
    }

    /*
     * One set of signal bars per SIM slot. On a single SIM device this renders
     * exactly the one indicator the status bar always had, without the slot
     * badge; with two SIMs each set of bars gets a small "1"/"2" next to it and
     * the slot carrying data is highlighted.
     */
    Repeater {
        id: telephonySignalIndicators

        model: telephonyService.sims

        delegate: Item {
            id: simIndicatorDelegate

            readonly property bool showBadge: telephonyService.sims.multiSim && model.powered

            anchors.top: indicatorsRow.top
            anchors.bottom: indicatorsRow.bottom

            // the badge is drawn into the empty corner above the low bars, so
            // the signal icon keeps its full size and a slot takes no more
            // width than the icon itself
            width: simSignalIndicator.width

            TelephonySignalIndicator {
                id: simSignalIndicator

                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left

                enabled: model.powered
                bars: model.bars
            }

            SimSlotIndicator {
                id: simSlotBadge

                anchors.top: parent.top
                anchors.left: parent.left

                height: parent.height * 0.55

                enabled: simIndicatorDelegate.showBadge
                label: "" + (model.simId + 1)
                highlighted: model.defaultForData
            }
        }
    }

    /*
     * One indicator per battery that is not the phone's own and is actually
     * there: the PinePhone (Pro) keyboard's, while the phone is docked in it.
     * The list is empty on every single-battery device, so the status bar looks
     * exactly as it always did.
     *
     * Same indicator as the phone's own - same size, same icon, same style,
     * including whatever AppTweaks has made of it - with the role's initial
     * drawn over the cell. A shorter indicator with a badge beside it read as a
     * lesser widget rather than as a second battery, and cost width the status
     * bar does not have. BatteryIndicator only picks up the AppTweaks style on
     * its change signal, so follow the phone's indicator rather than the
     * defaults a freshly created one starts at.
     */
    Repeater {
        id: auxBatteryIndicators

        model: batteryService.auxBatteries

        delegate: BatteryIndicator {
            id: auxBatteryIndicator

            readonly property var battery: modelData
            readonly property string roleInitial: battery.label.charAt(0).toUpperCase()

            anchors.top: indicatorsRow.top
            anchors.bottom: indicatorsRow.bottom

            level: battery.level
            charging: battery.charging
            percentage: battery.percentage

            imageVisible: batteryIndicator.imageVisible
            textVisible: batteryIndicator.textVisible

            /*
             * Where the initial goes depends on whether there is a cell to put
             * it on. With one, it sits on it. With only a reading - the
             * percentage-only style - centring it lands squarely on the digits,
             * so it follows the reading instead. Making it part of the same
             * string rather than a second item means it is the same size and
             * colour by construction, and the indicator is wide enough for it
             * without having to reach inside BaseIndicator for the width.
             */
            textValue: imageVisible ? (percentage + "%")
                                    : (percentage + "% " + roleInitial)
            textReferenceValue: imageVisible ? "100%" : ("100% " + roleInitial)

            /*
             * Sized and placed against the cell rather than against the
             * indicator: with a reading above it the icon is drawn rotated and
             * squashed into the lower part of the box, so an initial centred on
             * the whole indicator at half its height stood well clear of the
             * cell it is supposed to mark. Outlined so it stays legible over
             * both the full and the empty part of the cell, and over the
             * charging icon's lighter fill.
             */
            Text {
                id: auxRoleBadge

                readonly property real cellCenterY: auxBatteryIndicator.textVisible
                                                    ? parent.height * 0.645
                                                    : parent.height * 0.5
                readonly property real cellSize: auxBatteryIndicator.textVisible
                                                 ? parent.height * 0.20
                                                 : parent.height * 0.45

                visible: auxBatteryIndicator.imageVisible

                anchors.horizontalCenter: parent.horizontalCenter
                y: cellCenterY - height / 2

                text: auxBatteryIndicator.roleInitial

                color: "white"
                style: Text.Outline
                styleColor: "black"
                font.family: Settings.fontStatusBar
                font.bold: true
                font.pixelSize: Math.max(1, Math.round(cellSize))
            }
        }
    }

    BatteryIndicator {
        id: batteryIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        level: batteryService.level
        charging: batteryService.charging
        percentage: batteryService.percentage

        enabled: !batteryService.error
    }
}
