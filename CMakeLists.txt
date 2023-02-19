project(luna-next-cardshell)

cmake_minimum_required(VERSION 2.8.8)

include(webOS/webOS)
webos_modules_init(1 0 0 QUALIFIER RC3)
webos_component(0 1 0)

set(CARDSHELL_FILES
	manifest.json
	qmldir)

set(CARDSHELL_DIRS
	qml)

install (FILES ${CARDSHELL_FILES} DESTINATION ${LUNA_NEXT_SHELL_DIR})
install (DIRECTORY ${CARDSHELL_DIRS} DESTINATION ${LUNA_NEXT_SHELL_DIR})
