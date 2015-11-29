/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
 * Copyright (C) 2015 Nikolay Nizov <nizovn@gmail.com>
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
import org.nemomobile.dbus 2.0

Item {
    id: _device
    property string name: ""
    property string address: ""
    property int cod: 0
    property bool connected: false
    property string connStatus: ""
    property string path: "/"

    signal addBluetoothEntry(string name, string address, int cod, string connStatus, bool connected)
    signal updateBluetoothEntry(string address, string connStatus, bool connected)

    DBusInterface {
        id: btDevice
        service: "org.bluez"
        path: _device.path
        iface: "org.bluez.Device"
        bus: DBus.SystemBus
        signalsEnabled: false

        /*
        function propertyChanged(property, value) {
            console.log("propertychanged", path, property, value)
            if (property === "Name")
                name = value
        }
        */
    }

    DBusInterface {
        id: btAudio
        service: "org.bluez"
        path: _device.path
        iface: "org.bluez.Audio"
        bus: DBus.SystemBus
    }

    function connectBtAudioDevice() {
        btAudio.typedCall('Connect', [],
            function success(result) {
                connected = true;
                connStatus = "connected";
                updateBtEntry();
            },
            function fail() {
                connected = false;
                connStatus = "disconnected";
                updateBtEntry();
            }
        );
    }

    function disconnectDevice() {
        btDevice.typedCall('Disconnect', [],
            function success(result) {
                connected = false;
                connStatus = "disconnected";
                updateBtEntry();
            },
            function fail() {
                connected = false;
                connStatus = "disconnected";
                updateBtEntry();
            }
        );
    }

    function connectDevice() {
        connectBtAudioDevice();
    }

    function updateBtEntry() {
        updateBluetoothEntry(address, connStatus, connected);
    }

    Component.onCompleted: {
        btDevice.typedCall('GetProperties', [], function (result) {
            name = result.Name;
            address = result.Address;
            cod = result.Class;
            connected = result.Connected;
            connStatus = result.Connected?"connected":"disconnected";
            addBluetoothEntry(name, address, cod, connStatus, connected);
        });
    }
}
