project(luna-next-cardshell)

cmake_minimum_required(VERSION 2.8.8)

include(webOS/webOS)
webos_modules_init(1 0 0 QUALIFIER RC3)
webos_component(0 1 0)

find_package(Qt6 COMPONENTS ShaderTools)

set(CARDSHELL_FILES
	manifest.json
	qmldir)

set(CARDSHELL_DIRS
	qml)

qt6_add_shaders(luna-next-cardshell "cardshell_shaders"
    PREFIX
        "/"
    FILES
        "qml/Utils/corner_shader.vert"
        "qml/Utils/corner_shader.frag"
)

install (FILES ${CARDSHELL_FILES} DESTINATION ${LUNA_NEXT_SHELL_DIR})
install (DIRECTORY ${CARDSHELL_DIRS} DESTINATION ${LUNA_NEXT_SHELL_DIR})
