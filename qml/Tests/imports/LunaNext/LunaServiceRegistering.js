.pragma library

var _listRegisteredMethods = new Array

function addRegisteredMethod(name, fct) {
    _listRegisteredMethods.push({"name": name, "fct": fct});
}

function executeMethod(name, args) {
    var index = 0;

    for (var n = _listRegisteredMethods.length-1; n >= 0; n--) {
        var methodItem = _listRegisteredMethods[n];
        if( methodItem.name === name ) {
            methodItem.fct(args);
            return true;
        }
    }

    return false;
}
