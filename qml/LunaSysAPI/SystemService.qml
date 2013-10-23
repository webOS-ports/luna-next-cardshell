import QtQuick 2.0
import LunaNext 0.1

LunaService {
    id: systemService

    name: "org.webosports.luna"

    property variant screenShooter

    onInitialized: {
        console.log("Starting system service ...");
        systemService.registerMethod("/", "takeScreenShot", handleTakeScreenShot);
    }

    function buildErrorResponse(message) {
        return JSON.stringify({ "returnValue": false, "errorMessage": message });
    }

    function handleTakeScreenShot(data) {
        var request = JSON.parse(data);

        if (request === null || request.file === undefined)
            return buildErrorResponse("Invalid parameters.");

        if (systemService.screenShooter == null)
            return buildErrorResponse("Internal error.");

        screenShooter.takeScreenshot(request.file);

        return JSON.stringify({"returnValue":true});
    }
}
