/// Window Manager services

.pragma library

// Add a notification in the notification area.
// The notif parameter should contain the following members:
//  * icon: the path to the icon resource to show
//  * content: the html content to display in open mode
function addNotification(notif)
{
    return windowManager.addNotification(notif);
}

/// Base window service
/// Useful services to help the applications request some
/// info/changes on their window
function getWrapperFromWindow(window)
{
    if( window && window.parent )
        return window.parent.parent;

    return null;
}

function getWindowState(window)
{
    var windowWrapper = getWrapperFromWindow(window);
    return windowWrapper?windowWrapper.windowState:-1;
}

function setWindowState(window, state)
{
    var windowWrapper = getWrapperFromWindow(window);
    windowWrapper.switchToState(state);
}

/// Window Manager Tap Action services

// This model contains the list of actions to call when a "tap" gesture is detected.
// It is treated as a stack of actions, i.e. "LIFO".

// It has 3 properties:
//   - "id" which identifies the action. It is possible to
//     insert several actions with identical id.
//   - "actionFct" which contains a callback to the function to call
//   - "actionData" which contains the data to pass to the function
var _listRegisteredTapActions = new Array

function nbRegisteredTapActions() {
    return _listRegisteredTapActions.length;
}

function addTapAction(actionID, actionFct, actionData) {
    var previousList = _listRegisteredTapActions;
    _listRegisteredTapActions.push({"id": actionID, "actionFct": actionFct, "actionData": actionData});
}

function removeTapAction(actionID) {
    var index = 0;

    for (var n = _listRegisteredTapActions.length-1; n >= 0; n--) {
        actionItem = list[n];
        if( actionItem.id === actionID ) {
            _listRegisteredTapActions.splice(n, 1);
        }
    }
}

function doNextTapAction() {
    // retrieve the last registered action
    var actionItem = _listRegisteredTapActions.pop();

    if( actionItem && actionItem.actionFct ) {
        actionItem.actionFct(actionItem.actionData); // do it
    }
}

