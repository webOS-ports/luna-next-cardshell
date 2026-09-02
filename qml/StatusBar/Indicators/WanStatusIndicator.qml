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
    id: wanStatusIndicator

    // Radio access technology as com.palm.wan/getstatus words it. telephonyd
    // reports ofono's NetworkRegistration.Technology when no bearer is up, so
    // this is set from the moment the modem registers.
    property string technology: "none"

    imageSource: getIconForTechnology(technology)
    imageVisible: imageSource.length > 0

    // Only technologies we actually have artwork for; anything else leaves the
    // indicator empty rather than pointing Image at a file that is not there.
    readonly property var __iconNames: ({
        "gsm":       "gprs",
        "gprs":      "gprs",
        "edge":      "edge",
        "umts":      "3g",
        "hsdpa":     "hsdpa",
        "hsupa":     "hsdpa-plus",
        "hspa":      "hsdpa-plus",
        "hspa+":     "hsdpa-plus",
        "lte":       "4g",
        "1x":        "1x",
        "evdo":      "evdo"
    })

    function getIconForTechnology(value) {
        var name = __iconNames[value];

        if (!name)
            return "";

        return "../../images/statusbar/network/network-" + name + "-connected.png";
    }
}
