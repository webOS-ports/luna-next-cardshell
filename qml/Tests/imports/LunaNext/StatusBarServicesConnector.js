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

.pragma library

var signalBatteryLevelUpdated = new Object;
var signalChargingStateUpdated = new Object;
var signalPowerdConnectionStateChanged = new Object;
var signalCarrierTextChanged = new Object;
//var signalRssiIndexChanged(bool show, StatusBar::IndexRSSI index);
//var signalRssi1xIndexChanged(bool show, StatusBar::IndexRSSI1x index);
//var signalTTYStateChanged(bool enabled);
//var signalHACStateChanged(bool enabled);
//var signalCallForwardStateChanged(bool enabled);
//var signalRoamingStateChanged(bool enabled);
//var signalVpnStateChanged(bool enabled);
//var signalWanIndexChanged(bool show, StatusBar::IndexWAN index);
//var signalBluetoothIndexChanged(bool show, StatusBar::IndexBluetooth index);
var signalWifiIndexChanged = new Object;

var initialized;

function __init(rootObject)
{
    if( !initialized )
    {
        console.log("initializing status bar connector stub services...");

        initialized = Qt.createQmlObject('import QtQuick 2.0; import "StatusBarServicesConnector.js" as StatusBarServicesConnector; Timer {interval: 2000; running: true; repeat: true; onTriggered: StatusBarServicesConnector.spawnNotification()}',
              rootObject, "timerObject");

        signalBatteryLevelUpdated.connect = function (cb) {
            signalBatteryLevelUpdated.target = cb;
        }
        signalChargingStateUpdated.connect = function (cb) {
            signalChargingStateUpdated.target = cb;
        }
        signalPowerdConnectionStateChanged.connect = function (cb) {
            signalPowerdConnectionStateChanged.target = cb;
        }
        signalCarrierTextChanged.connect = function (cb) {
            signalCarrierTextChanged.target = cb;
        }
        signalWifiIndexChanged.connect = function (cb) {
            signalWifiIndexChanged.target = cb;
        }
    }
}

function spawnNotification()
{
    if( signalBatteryLevelUpdated.target )
        signalBatteryLevelUpdated.target(10*Math.floor(Math.random() * 11));
    if( signalChargingStateUpdated.target )
        signalChargingStateUpdated.target(Math.random()>0.5);
    if( signalPowerdConnectionStateChanged.target )
        signalPowerdConnectionStateChanged.target(Math.random()>0.5);
    if( signalCarrierTextChanged.target )
        signalCarrierTextChanged.target("carrier " + Math.ceil(Math.random()*10));
    if( signalWifiIndexChanged.target )
        signalWifiIndexChanged.target(Math.random()>0.2, Math.floor(Math.random()*6));
}

