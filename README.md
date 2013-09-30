Luna Next Cardshell
===================

Summary
-------
The new webOS UI of the webOS ports project.

Description
-----------
This is the repository of a prototype for a next generation webOS UI. Together with Luna Next, it's meant to be a
complete replacement for LunaSysMgr/WebAppMgr and is completely based on well known open
source technologies like Qt 5 and Wayland.

The Luna Next Cardshell is the default UI for Luna Next.

For building Luna Next, please refer to the instructions on https://github.com/webOS-ports/luna-next-cardshell.

CAUTION: At the moment it's not meant to be usable in any kind!

Development on a desktop machine
--------------------------------

### Requirements
A standard Qt 5.1 SDK installation is sufficient, as long as QtCreator and the QML toolchain are present.

### Working with the QML description of Luna Next card UI
First, get a copy of the luna-next-cardshell repository:
git clone https://github.com/webOS-ports/luna-next-cardshell

Then, simply open the qmlproject file in the qml subdirectory. You should be able to run the QML description of luna-next out of the box.

### Expect results
The QML description of luna-next does '''not''' include the C++ module which lets it communicate with other components of WebOS. Do not expect any realistic result for the answers provided by the "LunaNext" QML module, as this desktop environment actually uses a fake stub LunaNext module for testing purposes.

Contributing
------------

If you want to contribute you can just start with cloning the repository and make your
contributions. We're using a pull-request based development and utilizing github for the
management of those. All developers must provide their contributions as pull-request and
github and at least one of the core developers needs to approve the pull-request before it
can be merged.

Please refer to http://www.webos-ports.org/wiki/Communications for information about how to
contact the developers of this project.
