import QtQuick 2.0
import LunaNext 0.1

ListModel {
    id: applicationModel

    property string filter: "*"
    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    function applyFilter(newFilter) {
        filter = newFilter;
        refresh()
    }

    function refresh() {
        lunaNextLS2Service.call("luna://com.palm.applicationManager/listApps", JSON.stringify({"filter": filter}), fillFromJSONResult, handleError);
    }

    function fillFromJSONResult(data) {
        var result = JSON.parse(data);
        applicationModel.clear();
        if(result.returnValue && result.apps !== undefined) {
            for(var i=0; i<result.apps.length; i++) {
                applicationModel.append(result.apps[i]);
            }
        }
    }

    function handleError(errorMessage) {
        console.log("Failed to call application manager: " + errorMessage);
    }

    Component.onCompleted: refresh();
}
