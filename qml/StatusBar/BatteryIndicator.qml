/*
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

BaseIndicator {
    id: batteryIndicator

    property int batteryLevel: 0
    property bool charging: false

    indicatorImage: batteryIcon

    Image {
        id: batteryIcon

        fillMode: Image.PreserveAspectFit
        smooth: true

        source: getIconForBatteryLevel(batteryLevel)
    }

    function getIconForBatteryLevel(level) {
        var baseName = "../images/statusbar/battery-";

        var normalizedLevel = level;
        if (level > 11) {
            normalizedLevel = "charged";
        }
        else if (level < 0) {
            normalizedLevel = "error";
        }
        else {
            if (charging)
                baseName += "charging-";
        }

        return baseName + normalizedLevel + ".png";
    }
}
