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
import "../../AppTweaks"

BaseIndicator {
    id: batteryIndicator

    property int level: -1
    property int percentage: 0
    property bool charging: false

    imageSource: __getIconForBatteryLevel(level, charging)
    textValue: percentage + "%"
    // Always as wide as a full charge reads, so the cell keeps one size and the
    // indicators either side of it keep one position.
    textReferenceValue: "100%"
    /*
     * Tweaks > Luna > Status Bar: the icon, the percentage or both, and the
     * percentage white or in the level's colour. Bound, so the saved values
     * apply at start-up as well as when changed: as handlers they only ran on
     * a change, and White, the default, never did, so the percentage was the
     * level's colour (green when charged) until White was picked again.
     */
    readonly property string __indicatorType: AppTweaks.batteryIndicatorTypeValue
    imageVisible: __indicatorType !== "percentageOnly"
    textVisible: __indicatorType === "iconPercentage" || __indicatorType === "percentageOnly"
    textColor: AppTweaks.batteryPercentageColorOptionsValue === "white" ? "white" : __getColorForBatteryLevel(level)

    // Tints taken from legacy's own status bar battery frames
    // (battery-11/-1/-0.png): the fill green, the low amber and the empty
    // red, so the percentage reads in the same colour as the icon beside it.
    function __getColorForBatteryLevel(level) {
        var result = ""
        if (level >= 11 ){
            result = "#31cd31"
        }
        else if (level > 1 && level <= 10) {
            result = "lightgray"
        }
        else if (level <= 0) {
            result = "#922b1c"
        }
        else if (level === 1) {
            result = "#ffc61b"
        }
        return result;
    }

    function __getIconForBatteryLevel(level, isCharging) {
        var baseName = "../../images/statusbar/battery/battery-";
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
