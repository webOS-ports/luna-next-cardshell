/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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

Item {
    signal signalWifiIndexChanged(bool show, int index);
    signal signalBatteryLevelUpdated(int percentage);
    signal signalChargingStateUpdated(bool charging);
    signal signalCarrierTextChanged(string newCarrier);
    signal signalPowerdConnectionStateChanged(bool connected);

    Timer {
        interval: 2000;
        running: true;
        repeat: true;
        onTriggered: spawnNotification();
    }

    function spawnNotification()
    {
        signalBatteryLevelUpdated(10*Math.floor(Math.random() * 11));
        signalChargingStateUpdated(Math.random()>0.5);
        signalPowerdConnectionStateChanged(Math.random()>0.5);
        signalCarrierTextChanged("carrier " + Math.ceil(Math.random()*10));
        signalWifiIndexChanged(Math.random()>0.2, Math.floor(Math.random()*6));
    }
}
