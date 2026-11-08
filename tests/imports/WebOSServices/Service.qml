import QtQuick 2.0

// webOS OSE's Service, with nothing on the other end.
QtObject {
    property string appId
    property string service
    signal response(string method, string payload, int token)
    function call(service, method, payload) { return 0; }
    function cancel(token) {}
}
