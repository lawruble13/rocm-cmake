
include(CMakeParseArguments)
include(GNUInstallDirs)

find_program(MAKE_NSIS_EXE makensis)

macro(rocm_create_package)
    set(options LDCONFIG)
    set(oneValueArgs NAME DESCRIPTION SECTION MAINTAINER LDCONFIG_DIR PREFIX)
    set(multiValueArgs DEB_DEPENDS)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(CPACK_PACKAGE_NAME ${PARSE_NAME})
    set(CPACK_PACKAGE_VENDOR "Advanced Micro Devices, Inc")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${PARSE_DESCRIPTION})
    set(CPACK_SET_DESTDIR On)
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER ${PARSE_MAINTAINER})
    set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
    set(CPACK_NSIS_MODIFY_PATH On)
    set(CPACK_NSIS_PACKAGE_NAME ${PARSE_NAME})
    
    set(CPACK_GENERATOR "DEB")
    if(EXISTS ${MAKE_NSIS_EXE})
        list(APPEND CPACK_GENERATOR "NSIS")
    endif()

    if(PARSE_DEB_DEPENDS)
        set(CPACK_DEBIAN_PACKAGE_DEPENDS ${PARSE_DEB_DEPENDS})
    endif()

    if(PARSE_LDCONFIG)
        set(LDCONFIG_DIR ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
        if(PARSE_LDCONFIG_DIR)
            set(LDCONFIG_DIR ${PARSE_LDCONFIG_DIR})
        elseif(PARSE_PREFIX)
            set(LDCONFIG_DIR ${CMAKE_INSTALL_PREFIX}/${PARSE_PREFIX}/${CMAKE_INSTALL_LIBDIR})
        endif()
        file(WRITE ${PROJECT_BINARY_DIR}/debian/postinst "
            echo \"${LDCONFIG_DIR}\" > /etc/ld.so.conf.d/${PARSE_NAME}.conf
            ldconfig
        ")

        file(WRITE ${PROJECT_BINARY_DIR}/debian/prerm "
            rm /etc/ld.so.conf.d/${PARSE_NAME}.conf
            ldconfig
        ")

        set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA "${PROJECT_BINARY_DIR}/debian/postinst;${PROJECT_BINARY_DIR}/debian/prerm")
        set(CPACK_RPM_POST_INSTALL_SCRIPT_FILE "${PROJECT_BINARY_DIR}/debian/postinst")
        set(CPACK_RPM_PRE_UNINSTALL_SCRIPT_FILE "${PROJECT_BINARY_DIR}/debian/prerm")
    endif()
    include(CPack)
endmacro()