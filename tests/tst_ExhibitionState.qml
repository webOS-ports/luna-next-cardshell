import QtQuick 2.0
import QtTest 1.0

import "../qml/DockMode"

/*
 * ExhibitionState.pickWindow: which of an application's windows exhibition
 * mode takes. An application running as a card that is also launched for
 * exhibition (Music, playing) has a card and a dock window; the carousel
 * must take the dock window, or it would adopt the user's card and close it
 * again on undocking.
 */
TestCase {
    name: "ExhibitionState"

    function win(appId, type) {
        return { appId: appId, type: type };
    }

    function test_dock_window_wins_over_card() {
        var card = win("org.webosports.app.music", "_WEBOS_WINDOW_TYPE_CARD");
        var dock = win("org.webosports.app.music", ExhibitionState.dockWindowType);
        compare(ExhibitionState.pickWindow([card, dock], "org.webosports.app.music"), dock);
        compare(ExhibitionState.pickWindow([dock, card], "org.webosports.app.music"), dock);
    }

    function test_card_when_there_is_no_dock_window() {
        // A runtime that knows nothing of dock mode shows a card.
        var card = win("org.webosarchive.flyingtoasters", "_WEBOS_WINDOW_TYPE_CARD");
        compare(ExhibitionState.pickWindow([card], "org.webosarchive.flyingtoasters"), card);
    }

    function test_other_apps_and_nothing() {
        var other = win("com.palm.app.clock", ExhibitionState.dockWindowType);
        compare(ExhibitionState.pickWindow([other, null], "org.webosports.app.music"), null);
        compare(ExhibitionState.pickWindow([], "org.webosports.app.music"), null);
    }
}
