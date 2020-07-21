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
import MeeGo.QOfono 0.2
import org.nemomobile.ofono 1.0


BaseIndicator {
    id: simIndicator
    imageSource: "../../images/statusbar/rssi-error.png"
    property int modemCount: 0

    OfonoModemListModel{
        id: modemModel
        Component.onCompleted: {
            console.log("Herrie OfonoListModel count: "+count);
        }
    }

    Repeater{
        id: simRepeater
        model: modemModel
        delegate: BaseIndicator {
            id: cellStatus

            //iconSize:       parent.height
            //iconSizeHeight: parent.height

            OfonoNetworkRegistration{
                id: cellularRegistrationStatus
                modemPath: path

                onStatusChanged: {
                    console.log("Herrie OfonoNetworkRegistration changed")
                    recalcIcon()
                }

                onStrengthChanged: {
                    console.log("Herrie OfonoNetworkRegistration Strength changed")
                    recalcIcon()
                }
            }

            function recalcIcon() {
                console.log("Herrie recalcicon");
                if(!model.enabled) {
                    cellStatus.source = "/usr/share/lipstick-glacier-home-qt5/qml/theme/disabled-sim.png"
                } else if(!cellularRegistrationStatus.status) {
                    cellStatus.source = "../../images/statusbar/rssi-error.png"
                } else if(cellularRegistrationStatus.strength > 20){
                    cellStatus.source = "../../images/statusbar/rssi-" + Math.ceil(cellularRegistrationStatus.strength/20) + ".png"
                } else {
                    cellStatus.source = "../../images/statusbar/rssi-0.png"
                }
            }
        }
    }
}
