/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

.pragma library

// Titles of the launcher tabs this file has an opinion about. Of the four tabs
// the launcher always shows (Apps, Downloads, Favorites, Prefs) only Android is
// optional, see the showAndroidTab tweak.
var APPS_TAB = "Apps";
var PREFS_TAB = "Prefs";
var ANDROID_TAB = "Android";

// Waydroid gives every launchable Android package a webOS app of its own,
// with the id "waydroid.<packageName>" (the same name hwcomposer puts in the
// Wayland app_id). "Waydroid" itself is the full-UI launcher, and
// "id.waydro.container" the container service app.
function isAndroidApp(appId) {
    if (!appId) return false;
    return appId.indexOf("waydroid.") === 0 ||
           appId.indexOf("id.waydro.") === 0 ||
           appId === "Waydroid";
}

// True for an Android app that carries its own Android icon, i.e. one that
// should be badged so it is recognizable as running inside Waydroid. The
// Waydroid app and its container already show the Waydroid logo themselves.
function needsAndroidBadge(appId) {
    return !!appId && appId.indexOf("waydroid.") === 0;
}

// The settings app was split up into one app per category
// ("org.webosports.app.settings.wifi", ".bluetooth", ...), and new ones keep
// being added, so match on the prefix instead of listing them one by one.
function isPrefsApp(appId) {
    if (!appId) return false;
    return appId.indexOf("org.webosports.app.settings") === 0 ||
           appId === "com.palm.app.backup";
}

// The tab an app belongs to by rule, or "" when no rule applies and the
// default layout (/etc/palm/default-launcher-page-layout.json) decides.
// Rules lose against an explicit placement the user made in the launcher.
function tabForApp(appId, androidTabEnabled) {
    if (isAndroidApp(appId))
        return androidTabEnabled ? ANDROID_TAB : "";
    if (isPrefsApp(appId))
        return PREFS_TAB;
    return "";
}
