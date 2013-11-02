/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import LunaNext 0.1

BaseIndicator {
    id: wifiIndicator

    property int signalLevel: 0

    indicatorImage: batteryIcon

    Image {
        id: batteryIcon

        fillMode: Image.PreserveAspectFit
        smooth: true

        source: __getIconForSignalLevel(signalLevel)
    }

    Connections {
        target: statusBarServicesConnector

        onSignalWifiIndexChanged: {
            if (index === StatusBarIconIndex.WIFI_OFF ||
               index === StatusBarIconIndex.WIFI_ON) {
                wifiIndicator.signalLevel = 0; // off, or on and no bar
            }
            else if (index === StatusBarIconIndex.WIFI_CONNECTING) {
                wifiIndicator.signalLevel = -1; // connecting
            }
            else {
                wifiIndicator.signalLevel = index - 2; // 1, 2 or 3 bars
            }

            wifiIndicator.enabled = show;
        }
    }

    function __getIconForSignalLevel(level) {
        var baseName = "../images/statusbar/wifi-";

        var normalizedLevel = level;
        if (level > 3) {
            normalizedLevel = "3";
        }
        else if (level < 0) {
            normalizedLevel = "connecting";
        }

        return baseName + normalizedLevel + ".png";
    }
}
