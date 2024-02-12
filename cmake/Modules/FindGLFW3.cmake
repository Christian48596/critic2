## From learnopengl:
##
## https://github.com/JoeyDeVries/LearnOpenGL/blob/master/cmake/modules/FindGLFW3.cmake
##
## All code samples, unless explicitly stated otherwise, are licensed
## under the terms of the CC BY-NC 4.0 license as published by
## Creative Commons, either version 4 of the License, or (at your
## option) any later version.
## See https://learnopengl.com/About for more information.

# Locate the glfw3 library
#
# This module defines the following variables:
#
# GLFW3_LIBRARY the name of the library;
# GLFW3_INCLUDE_DIR where to find glfw include files.
# GLFW3_FOUND true if both the GLFW3_LIBRARY and GLFW3_INCLUDE_DIR have been found.
#
# To help locate the library and include file, you can define a
# variable called GLFW3_ROOT which points to the root of the glfw library
# installation.
#
# default search dirs
#
# Cmake file from: https://github.com/daw42/glslcookbook
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)

set( _glfw3_HEADER_SEARCH_DIRS
"/usr/include"
"/usr/local/include"
"${CMAKE_SOURCE_DIR}/includes"
"C:/Program Files (x86)/glfw/include" )
set( _glfw3_LIB_SEARCH_DIRS
"/usr/lib"
"/usr/local/lib"
"${CMAKE_SOURCE_DIR}/lib"
"C:/Program Files (x86)/glfw/lib-msvc110" )

# Check environment for root search directory
set( _glfw3_ENV_ROOT $ENV{GLFW3_ROOT} )
if( NOT GLFW3_ROOT AND _glfw3_ENV_ROOT )
	set(GLFW3_ROOT ${_glfw3_ENV_ROOT} )
endif()

# Put user specified location at beginning of search
if( GLFW3_ROOT )
	list( INSERT _glfw3_HEADER_SEARCH_DIRS 0 "${GLFW3_ROOT}/include" )
	list( INSERT _glfw3_LIB_SEARCH_DIRS 0 "${GLFW3_ROOT}/lib" )
endif()

# Search for the header
find_path(GLFW3_INCLUDE_DIR "GLFW/glfw3.h" PATHS ${_glfw3_HEADER_SEARCH_DIRS})

# Search for the library
FIND_LIBRARY(GLFW3_LIBRARY NAMES glfw3 glfw PATHS ${_glfw3_LIB_SEARCH_DIRS} )
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(GLFW3 DEFAULT_MSG GLFW3_LIBRARY GLFW3_INCLUDE_DIR)
mark_as_advanced(GLFW3_INCLUDE_DIR GLFW3_LIBRARY)
