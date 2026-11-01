import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"

/*
 * TorchService: the system menu shows a Flashlight entry from this, so
 * "available" must be what torchd said and nothing else, and "on" must follow
 * torchd rather than what was asked for.
 */
TestCase {
    name: "TorchService"

    QtObject {
        id: fakeBus
        property var calls: []
        function call(uri, payload, onSuccess, onError) {
            calls.push(uri);
        }
    }

    TorchService {
        id: service
        bus: fakeBus
    }

    Component {
        id: fresh
        TorchService { }
    }

    function status(fields) {
        service.handleStatus({ payload: JSON.stringify(fields) });
    }

    function init() {
        service.available = false;
        service.on = false;
        fakeBus.calls = [];
    }

    function test_off_until_torchd_speaks() {
        var torch = createTemporaryObject(fresh, null);
        compare(torch.available, false);
        compare(torch.on, false);
    }

    function test_status() {
        status({ returnValue: true, available: true, on: false, brightness: 0 });
        compare(service.available, true);
        compare(service.on, false);

        status({ returnValue: true, available: true, on: true, brightness: 100 });
        compare(service.on, true);
    }

    function test_no_torch() {
        status({ returnValue: true, available: false, on: false });
        compare(service.available, false);
    }

    function test_partial_status_keeps_the_rest() {
        status({ available: true, on: true });
        status({ on: false });
        compare(service.available, true);
        compare(service.on, false);
    }

    function test_toggle_leaves_state_to_torchd() {
        status({ available: true, on: false });
        service.toggle();
        compare(fakeBus.calls.length, 1);
        compare(fakeBus.calls[0], "luna://org.webosports.service.torch/toggle");
        compare(service.on, false);
    }

    function test_toggle_without_a_torch_does_nothing() {
        service.toggle();
        compare(fakeBus.calls.length, 0);
        compare(service.on, false);
    }
}
