import QtQuick 2.0

import LunaNext.Common 0.1
import LuneOS.Service 1.0

QtObject {

    property LunaService service: LunaService {
        name: "com.webos.surfacemanager-cardshell"
    }

    function setIconUrlFromWindow(window, setterFct) {
        //Deal with the mini/smallIcons both relative and absolute
        var myIconUrl = Qt.resolvedUrl("../images/default-app-icon.png").toString();
        //Enyo might set a smallIcon for the dashboard which will appear as LuneOS_icon
        if(window.windowProperties.hasOwnProperty("LuneOS_icon")) {
            myIconUrl = window.windowProperties["LuneOS_icon"];
        }
        else if(window.miniIcon){
            myIconUrl = window.miniIcon;
        }
        else if(window.appIcon) {
            myIconUrl = window.appIcon;
        }


        function __resolveRelative(path, base) {
            //Anything that starts with file:// we want to strip first
            if(path.substring(0,7)==="file://"){
                path=path.substr(7);
            }
            if(base.substring(0,7)==="file://"){
                base=base.substr(7);
            }

            //Already absolute path
            if (path[0] === '/') {
                if (FileUtils.exists(path)){
                    return path;
                }
            }
            //Relative path, prepend it with the app folder
            else {
                var myFullFilePath = (base + "/" + path).toString();
                if (FileUtils.exists(myFullFilePath)) {
                    return myFullFilePath;
                }
            }
        }

        function handleGetAppInfoResponse2(message) {
            var response = JSON.parse(message.payload);
            if (response.returnValue && typeof response.appInfo.folderPath === 'string') {
                var appFolder = response.appInfo.folderPath;
                setterFct(__resolveRelative(myIconUrl, appFolder));
            }
        }


        function handleGetAppInfoError2(error) {
            console.log("Could not retrieve information about current application: " + error);
        }


        //Get the app folder so we can make an absolute path if needed
        service.call("luna://com.webos.service.applicationManager/getAppInfo",
                     JSON.stringify({"id":window.appId}),
                     handleGetAppInfoResponse2, handleGetAppInfoError2);
    }

    function setIconUrlOrDefault(path, appId, setterFct) {
        var mypath = Qt.resolvedUrl("../images/default-app-icon.png").toString();
        if(path){
            mypath = path.toString();
        }
        if(FileUtils.exists(mypath)){
            setterFct(mypath);
        }
        else {
            //Do lookup of the appIcon
            service.call("luna://com.webos.service.applicationManager/getAppInfo",
                         JSON.stringify({"id":appId}),
                         handleGetAppInfoResponse, handleGetAppInfoError);

            function handleGetAppInfoResponse(message) {
                var response = JSON.parse(message.payload);
                if(mypath.length > 1 && mypath.slice(-1)!=="/" && mypath[0]!=="/" && mypath.substring(0,7)!=="file://") {
                    if (response.returnValue && typeof response.appInfo.folderPath === 'string'){
                        mypath = response.appInfo.folderPath+"/"+mypath;
                    }
                } else {
                    if (response.returnValue && (response.appInfo.icon || response.appInfo.miniicon)) {
                        if(response.appInfo.icon) {
                            //Use appIcon by default, fall back to miniicon when needed.
                            mypath = response.appInfo.folderPath+"/"+response.appInfo.icon;
                        } else {
                            mypath = response.appInfo.folderPath+"/"+response.appInfo.miniicon;
                        }
                    }
                }
                if(FileUtils.exists(mypath)){
                    setterFct(mypath);
                }
                else {
                    console.log("File path doesn't exist, return default icon");
                    setterFct(Qt.resolvedUrl("../images/default-app-icon.png"));
                }
            }

            function handleGetAppInfoError(error) {
                console.log("Could not retrieve information about current application: " + error);
            }
        }
    }
}
