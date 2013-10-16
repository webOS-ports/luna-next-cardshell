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

