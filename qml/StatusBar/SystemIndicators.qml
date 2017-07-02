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
    
    RecorderIndicator {
        id: recorderIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: compositor.recording
    }

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

        enabled: BluetoothService.powered
        connected: BluetoothService.connected
        isTurningOn: BluetoothService.isTurningOn
    }

    WanStatusIndicator {
        id: wanStatusIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: telephonyService.powered && wanService.connected && !wifiService.online
        technology: wanService.technology
    }

    TelephonySignalIndicator {
        id: telephonySignalIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: telephonyService.powered
        bars: telephonyService.bars
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
