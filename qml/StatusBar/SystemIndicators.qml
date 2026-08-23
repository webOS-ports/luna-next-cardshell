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

    AirplaneModeService {
        id: airplaneModeService
    }

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

        // packet data runs on one SIM at a time, so this reflects the SIM
        // currently selected as the data SIM
        enabled: telephonyService.powered && wanService.connected && !wifiService.online
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
