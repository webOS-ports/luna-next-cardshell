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
import LunaNext.Common 0.1

BaseIndicator {
    id: telephonySignalIndicator

    property int strength: 0

    imageSource: __getIconForStrengthValue(strength)

    function mapStrengthToRssi(value) {
        return (value * 5) / 100;
    }

    function __getIconForStrengthValue(value) {
        var baseName = "../../images/statusbar/rssi-";

        var normalizedValue = mapStrengthToRssi(value);
        if (value > 5)
            normalizedValue = "5";
        else if (value < 0)
            normalizedValue = "error";

        return baseName + normalizedValue + ".png";
    }
}
