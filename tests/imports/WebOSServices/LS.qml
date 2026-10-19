pragma Singleton
import QtQuick 2.0

// The part of webOS OSE's LS the shell uses: calls go nowhere.
QtObject {
    property string appId: "com.webos.surfacemanager"
    property QtObject adhoc: QtObject {
        function call(uri, method, payload) {}
    }
}
