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
import Connman 0.2

Item {
    id: telephonyService

    property bool online: manager.available && modem.online
    property string status: netreg.status
    property int strength: netreg.strength
    property string technology: netreg.technology
    property bool wanConnected: connectionManager.attached
    property string wanTechnology: connectionManager.bearer
    property bool offlineMode: networkManager.offlineMode

    onOfflineModeChanged: console.log("DEBUG: offlineMode = " + offlineMode)

    NetworkManager {
        id: networkManager
    }

    OfonoManager {
        id: manager
    }

    OfonoModem {
        id: modem
        modemPath: manager.modems[0]
    }

    OfonoConnMan {
        id: connectionManager
        modemPath: manager.modems[0]
    }

    OfonoNetworkRegistration {
        id: netreg
        modemPath: manager.modems[0]
        onStrengthChanged: console.log("Strength changed to " + netreg.strength)
    }
}
