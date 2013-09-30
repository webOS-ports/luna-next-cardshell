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

    Image {
        id: batteryIcon
        source: getIconForBatteryLevel(batteryLevel)
    }

    function getIconForBatteryLevel(level) {
        var normalizedLevel = level;
        var baseName = "../images/statusbar/battery-";

        if (charging)
            baseName += "charging-";

        if (level > 11)
            normalizedLevel = "charged";
        else if (level < 0)
            normalizedLevel = "error";

        return baseName + normalizedLevel + ".png";
    }
}
