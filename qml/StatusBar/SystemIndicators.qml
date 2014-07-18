/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013-2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013-2014 Herman van Hazendonk <github.com@herrie.org>
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
import "../Connectors"
import "Indicators"

Row {
    id: indicatorsRow

    anchors.margins: Units.gu(1) / 2
    spacing: Units.gu(1) / 2

    BatteryService {
        id: batteryService
    }

    TelephonyService {
        id: telephonyService
    }

    WiFiService {
        id: wifiService
    }

    FlightmodeStatusIndicator {
        id: flightmodeStatusIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: telephonyService.offlineMode
    }

    WifiIndicator {
        id: wifiIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: wifiService.powered
        signalBars: wifiService.signalBars
    }

    WanStatusIndicator {
        id: wanStatusIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: telephonyService.wanConnected
        technology: telephonyService.wanTechnology
    }

    TelephonySignalIndicator {
        id: telephonySignalIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        enabled: telephonyService.online && !telephonyService.offlineMode
        strength: telephonyService.strength
    }

    BatteryIndicator {
        id: batteryIndicator

        anchors.top: indicatorsRow.top
        anchors.bottom: indicatorsRow.bottom

        level: batteryService.level
        charging: batteryService.charging
        percentage: batteryService.percentage
    }

    Image {
        id: systemMenuArrow
        source: "../images/statusbar/menu-arrow.png"
        anchors.verticalCenter: parent.verticalCenter
    }
}
