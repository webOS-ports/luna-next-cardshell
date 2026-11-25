import QtQuick 2.0
import QtTest 1.0

import "../qml/StatusBar/Indicators"

/*
 * The WAN indicator shows an icon for every network type telephonyd reports in
 * com.palm.wan/getstatus, 5G included, and every icon it points at is there.
 */
Item {
    width: 200
    height: 40

    WanStatusIndicator {
        id: wan
        height: 40
    }

    TestCase {
        name: "WanStatusIndicator"
        when: windowShown

        // What src/wanservice.c's wan_network_type_to_string() can say
        readonly property var reported: ["gprs", "edge", "umts", "hsdpa", "lte", "1x", "evdo", "5g"]

        function image() {
            for (var i = 0; i < wan.children.length; i++) {
                var c = wan.children[i];
                if (c.hasOwnProperty("fillMode"))
                    return c;
            }
            return null;
        }

        function test_5g_has_its_own_icon() {
            wan.technology = "5g";
            verify(wan.imageVisible);
            compare(wan.imageSource, "../../images/statusbar/network/network-5g-connected.png");
        }

        function test_every_reported_type_loads_an_icon() {
            for (var i = 0; i < reported.length; i++) {
                wan.technology = reported[i];
                verify(wan.imageVisible, reported[i]);
                tryCompare(image(), "status", Image.Ready, 2000, reported[i]);
            }
        }

        function test_nothing_for_no_network() {
            wan.technology = "none";
            verify(!wan.imageVisible);
            wan.technology = "nr";      // ofono's word, never telephonyd's
            verify(!wan.imageVisible);
        }
    }
}
