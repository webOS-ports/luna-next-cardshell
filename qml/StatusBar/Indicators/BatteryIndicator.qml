/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013-2014 Simon Busch <morphis@gravedo.de>
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
import LuneOS.Components 1.0

import "../../Utils"

BaseIndicator {
    id: batteryIndicator

    property int level: -1
    property int percentage: 0
    property bool charging: false

    imageSource: __getIconForBatteryLevel(level, charging)
    textValue: percentage + "%"
    textColor: __getColorForBatteryLevel(level)


    Tweak {
        id: batteryIndicatorType
        owner: "luna-next-cardshell"
        serviceName: "org.webosports.luna"
        key: "showBatteryPercentage"
        defaultValue: "iconOnly"
        onValueChanged: updateBatteryIndicator();

        function updateBatteryIndicator()
        {
            if (batteryIndicatorType.value === "iconOnly"){
                batteryIndicator.textVisible = false
                batteryIndicator.imageVisible = true
            }
            else if (batteryIndicatorType.value === "iconPercentage"){
                batteryIndicator.textVisible = true
                batteryIndicator.imageVisible = true

            }
            else if (batteryIndicatorType.value === "percentageOnly"){
                batteryIndicator.textVisible = true
                batteryIndicator.imageVisible = false
            }

        }
    }

    Tweak {
        id: batteryPercentageColorOptions
        owner: "luna-next-cardshell"
        serviceName: "org.webosports.luna"
        key: "batteryPercentageColor"
        defaultValue: String("white"); // without this cast, it would become a "color" type
        onValueChanged: updateBatteryPercentageColor();

        function updateBatteryPercentageColor()
        {
            if (batteryPercentageColorOptions.value === "white") {
                //Show white color
                batteryIndicator.textColor = "white";
            }
            else {
                //Get the color for the level, keeping property binding
                batteryIndicator.textColor = Qt.binding(function() {
                    return batteryIndicator.__getColorForBatteryLevel(level);
                } );
            }
        }
    }

    function __getColorForBatteryLevel(level) {
        var result = ""
        if (level >= 11 ){
            result = "lime"
        }
        else if (level > 1 && level <= 10) {
            result = "lightgray"
        }
        else if (level <= 0) {
            result = "red"
        }
        else if (level === 1) {
            result = "orange"
        }
        return result;
    }

    function __getIconForBatteryLevel(level, isCharging) {
        var baseName = "../../images/statusbar/battery-";
        var normalizedLevel = 0;

        if (level > 11 && !isCharging) {
            level = 11;
            normalizedLevel = level;
        }
        else if (level > 11 && isCharging) {
            normalizedLevel = "charged";
        }
        else if (level < 0) {
            normalizedLevel = "error";
        }
        else {
            if (isCharging)
                baseName += "charging-";

            normalizedLevel = level;
        }

        var result = baseName + normalizedLevel + ".png";
        return result;
    }
}
