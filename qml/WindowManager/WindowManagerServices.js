/// Window Manager services

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

