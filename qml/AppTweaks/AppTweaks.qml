/*
 * Copyright (C) 2014 Christophe Chapuis <chris.chapuis@gmail.com>
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

pragma Singleton

import QtQuick 2.0
import LuneOS.Components 1.0

Item {
    id: appTweaks

    // common property values
    property string owner: "luna-next-cardshell"
    property string serviceName: "com.webos.surfacemanager-cardshell"

    // aliases for each tweak
    property alias dateTimeTweakValue: dateTimeTweak.value
    property alias dragNDropTweakValue: dragNDropTweak.value
    property alias gestureAreaTweakValue: gestureAreaTweak.value
    property alias showTapRippleTweakValue: showTapRippleTweak.value
    property alias batteryIndicatorTypeValue: batteryIndicatorType.value
    property alias batteryPercentageColorOptionsValue: batteryPercentageColorOptions.value
    property alias enableCustomCarrierStringValue: enableCustomCarrierString.value
    property alias customCarrierStringValue: customCarrierString.value
    property alias tabTitleCaseTweakValue: tabTitleCaseTweak.value
    property alias tabIndicatorNumberTweakValue: tabIndicatorNumberTweak.value

    //// tweak definitions

    // CardShell
    Tweak {
        id: showTapRippleTweak
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "tapRippleSupport"
        defaultValue: true
    }

    // CardGroupListView
    Tweak {
        id: dragNDropTweak
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "stackedCardSupport"
        defaultValue: true
    }

    // CardsArea
    Tweak {
        id: gestureAreaTweak
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "showGestureArea"
        defaultValue: true
    }

    // StatusBar
    Tweak {
        id: dateTimeTweak
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "showDateTime"
        defaultValue: "timeOnly"
    }
    Tweak {
        id: batteryIndicatorType
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "showBatteryPercentage"
        defaultValue: "iconOnly"
    }
    Tweak {
        id: batteryPercentageColorOptions
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "batteryPercentageColor"
        defaultValue: String("white"); // without this cast, it would become a "color" type
    }
    Tweak {
        id: enableCustomCarrierString
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "useCustomCarrierString"
        defaultValue: "false"
    }
    Tweak {
        id: customCarrierString
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "carrierString"
        defaultValue: "Custom Carrier String"
    }

    // FullLauncher
    Tweak {
        id: tabTitleCaseTweak
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "tabTitleCase"
        defaultValue: "capitalizedCase"
    }
    Tweak {
        id: tabIndicatorNumberTweak
        owner: appTweaks.owner
        serviceName: appTweaks.serviceName
        key: "tabIndicatorNumber"
        defaultValue: "default"
    }

}
