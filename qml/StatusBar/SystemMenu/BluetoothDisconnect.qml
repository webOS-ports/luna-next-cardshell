/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
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
import LuneOS.Service 1.0
// LuneOS Bluetooth wrapper
import LuneOS.Bluetooth 0.2

/*
 * Disconnects a Bluetooth device the user tapped in the system menu.
 *
 * bluetooth2 connects the headset used last again whenever Bluetooth comes
 * on, and forgets a device the user disconnected, as Android does. The menu
 * disconnects through BlueZ (BluetoothManager), which bluetooth2 cannot tell
 * from the headset going away, so it says so first with
 * autoReconnect/forget, as the Bluetooth settings page does. Whether that
 * answers, or bluetooth2 is there at all, the disconnect goes ahead.
 */
QtObject {
    id: bluetoothDisconnect

    // Stand-ins in the tests.
    property QtObject manager: BluetoothManager
    property QtObject luna: LunaService {
        name: "com.webos.surfacemanager-cardshell"
    }

    readonly property string forgetUri: "luna://com.webos.service.bluetooth2/autoReconnect/forget"

    function disconnect(address) {
        var args = {"address": address};
        // The adapter the device is on, when BluezQt knows it; without it
        // bluetooth2 forgets the device on every adapter.
        var device = manager.btManager ? manager.btManager.deviceForAddress(address) : null;
        if (device && device.adapter && device.adapter.address)
            args.adapterAddress = device.adapter.address;

        luna.call(forgetUri, JSON.stringify(args), handleForgotten, handleForgetError);
        return manager.disconnectDeviceAddress(address);
    }

    function handleForgotten(message) {
    }

    function handleForgetError(message) {
        console.log("BluetoothDisconnect: autoReconnect/forget: " + message.payload);
    }
}
