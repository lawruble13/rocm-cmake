# ######################################################################################################################
# Copyright (C) 2021 Advanced Micro Devices, Inc.
# ######################################################################################################################

if(${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.12.0")
    function(rocm_join_if_set glue inout_variable)
        string(JOIN "${glue}" to_set_parent ${ARGN})
        if(DEFINED ${inout_variable} AND NOT ${inout_variable} STREQUAL "")
            set(${inout_variable} "${${inout_variable}}${glue}${to_set_parent}" PARENT_SCOPE)
        else()
            set(${inout_variable} "${to_set_parent}" PARENT_SCOPE)
        endif()
    endfunction()
else()
    function(rocm_join_if_set glue inout_variable)
        set(accumulator "")
        if(DEFINED ${inout_variable} AND NOT ${inout_variable} STREQUAL "")
            set(accumulator "${${inout_variable}}")
        endif()
        foreach(ITEM IN LISTS ARGN)
            if(NOT accumulator STREQUAL "" AND NOT ITEM STREQUAL "")
                string(CONCAT accumulator "${accumulator}" "${glue}" "${ITEM}")
            elseif(NOT ITEM STREQUAL "")
                set(accumulator "${ITEM}")
            endif()
        endforeach()
        set(${inout_variable} "${accumulator}" PARENT_SCOPE)
    endfunction()
endif()

function(rocm_add_rpm_dependencies)
    cmake_parse_arguments(PARSE "" "COMPONENT" "" ${ARGN})
    if(DEFINED PARSE_COMPONENT)
        string(TOUPPER "${PARSE_COMPONENT}" COMPONENT_VAR)
        set(REQ_VAR "CPACK_RPM_${COMPONENT_VAR}_PACKAGE_REQUIRES")
    else()
        set(REQ_VAR "CPACK_RPM_PACKAGE_REQUIRES")
    endif()
    set(RPM_DEPENDS "${${REQ_VAR}}")
    string(REPLACE ";" ", " NEW_DEPENDS "${PARSE_UNPARSED_ARGUMENTS}")
    rocm_join_if_set(", " RPM_DEPENDS "${NEW_DEPENDS}")
    set(${REQ_VAR} "${RPM_DEPENDS}" PARENT_SCOPE)
endfunction()

function(rocm_add_deb_dependencies)
    cmake_parse_arguments(PARSE "" "COMPONENT" "" ${ARGN})
    if(DEFINED PARSE_COMPONENT)
        string(TOUPPER "${PARSE_COMPONENT}" COMPONENT_VAR)
        set(REQ_VAR "CPACK_DEBIAN_${COMPONENT_VAR}_PACKAGE_DEPENDS")
    else()
        set(REQ_VAR "CPACK_DEBIAN_PACKAGE_DEPENDS")
    endif()
    set(DEB_DEPENDS "${${REQ_VAR}}")
    foreach(DEP IN LISTS PARSE_UNPARSED_ARGUMENTS)
        string(FIND "${DEP}" " " VERSION_POSITION)
        if(VERSION_POSITION GREATER "-1")
            string(SUBSTRING "${DEP}" 0 ${VERSION_POSITION} DEP_NAME)
            math(EXPR VERSION_POSITION "${VERSION_POSITION}+1")
            string(SUBSTRING "${DEP}" ${VERSION_POSITION} -1 DEP_VERSION)
            rocm_join_if_set(", " DEB_DEPENDS "${DEP_NAME} (${DEP_VERSION})")
        else()
            rocm_join_if_set(", " DEB_DEPENDS "${DEP}")
        endif()
    endforeach()
    set(${REQ_VAR} "${DEB_DEPENDS}" PARENT_SCOPE)
endfunction()

macro(rocm_add_dependencies)
    rocm_add_deb_dependencies(${ARGN})
    rocm_add_rpm_dependencies(${ARGN})
endmacro()

function(rocm_find_program_version PROGRAM)
    set(options QUIET REQUIRED)
    set(oneValueArgs GREATER GREATER_EQUAL LESS LESS_EQUAL EQUAL OUTPUT_VARIABLE)
    set(multiValueArgs)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT DEFINED PARSE_OUTPUT_VARIABLE)
        set(PARSE_OUTPUT_VARIABLE "${PROGRAM}_VERSION")
    endif()

    execute_process(
        COMMAND ${PROGRAM} --version
        RESULT_VARIABLE PROC_RESULT
        OUTPUT_VARIABLE EVAL_RESULT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(NOT PROC_RESULT EQUAL "0")
        set(${PARSE_OUTPUT_VARIABLE} "0.0.0" PARENT_SCOPE)
        set(${PARSE_OUTPUT_VARIABLE}_OK FALSE PARENT_SCOPE)
        if(PARSE_REQUIRED)
            message(FATAL_ERROR "Could not determine the version of required program ${PROGRAM}.")
        elseif(NOT PARSE_QUIET)
            message(WARNING "Could not determine the version of program ${PROGRAM}.")
        endif()
    else()
        string(REGEX MATCH [=[[0-9]+(\.[0-9]+)*$]=] PROGRAM_VERSION "${EVAL_RESULT}")
        set(${PARSE_OUTPUT_VARIABLE} "${PROGRAM_VERSION}" PARENT_SCOPE)
        set(${PARSE_OUTPUT_VARIABLE}_OK TRUE PARENT_SCOPE)
        foreach(COMP GREATER GREATER_EQUAL LESS LESS_EQUAL EQUAL)
            if(DEFINED PARSE_${COMP} AND NOT PROGRAM_VERSION VERSION_${COMP} PARSE_${COMP})
                set(${PARSE_OUTPUT_VARIABLE}_OK FALSE PARENT_SCOPE)
            endif()
        endforeach()
    endif()
endfunction()

function(rocm_get_path_items PATH OUTPUT_VARIABLE)
    string(REPLACE ";" "\\;" PATH "${PATH}")
    if(WIN32)
        string(REGEX REPLACE "[\\/]" ";" PATH "${PATH}")
    else()
        string(REPLACE "/" ";" PATH "${PATH}")
    endif()
    if(IS_ABSOLUTE "${PATH}")
        set(PATH_ITEMS "/")
    else()
        set(PATH_ITEMS ".")
    endif()
    foreach(ITEM IN LISTS PATH)
        if(ITEM STREQUAL "." OR ITEM STREQUAL "")
            # Do nothing
        elseif(ITEM STREQUAL "..")
            list(GET PATH_ITEMS -1 LAST_ITEM)
            if(LAST_ITEM STREQUAL "." OR LAST_ITEM STREQUAL "..")
                list(APPEND PATH_ITEMS "..")
            elseif(LAST_ITEM STREQUAL "/")
                # Do nothing
            else()
                list(REMOVE_AT PATH_ITEMS "-1")
            endif()
        else()
            list(APPEND PATH_ITEMS "${ITEM}")
        endif()
    endforeach()
    set(${OUTPUT_VARIABLE} "${PATH_ITEMS}" PARENT_SCOPE)
endfunction()

function(rocm_find_relative_path SRC DEST OUTPUT_VARIABLE)
    if(IS_ABSOLUTE "${SRC}" AND NOT IS_ABSOLUTE "${DEST}" OR
        IS_ABSOLUTE "${DEST}" AND NOT IS_ABSOLUTE "${SRC}")
        message(FATAL_ERROR "Can't determine the relative path between relative and absolute paths.")
    endif()
    rocm_get_path_items(SRC SRC_ITEMS)
    rocm_get_path_items(DEST DEST_ITEMS)
    while(SRC_ITEMS AND DEST_ITEMS)
        list(GET SRC_ITEMS 0 SRC_NEXT)
        list(GET DEST_ITEMS 0 DEST_NEXT)
        if(SRC_NEXT STREQUAL DEST_NEXT)
            list(REMOVE_AT SRC_ITEMS 0)
            list(REMOVE_AT DEST_ITEMS 0)
        else()
            break()
        endif()
    endwhile(SRC_ITEMS AND DEST_ITEMS)
    set(REL_PATH ".")
    foreach(ITEM IN LISTS SRC_ITEMS)
        string(APPEND REL_PATH "/..")
    endforeach()
    foreach(ITEM IN LISTS DEST_ITEMS)
        string(APPEND REL_PATH "/${ITEM}")
    endforeach()
    set(${OUTPUT_VARIABLE} "${REL_PATH}" PARENT_SCOPE)
endfunction()