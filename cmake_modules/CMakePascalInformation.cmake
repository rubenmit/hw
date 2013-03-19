# This file sets the basic flags for the Pascal language in CMake.
# It also loads the available platform file for the system-compiler
# if it exists.

GET_FILENAME_COMPONENT(CMAKE_BASE_NAME ${CMAKE_Pascal_COMPILER} NAME_WE)
SET(CMAKE_SYSTEM_AND_Pascal_COMPILER_INFO_FILE
  ${CMAKE_ROOT}/Modules/Platform/${CMAKE_SYSTEM_NAME}-${CMAKE_BASE_NAME}.cmake)
INCLUDE(Platform/${CMAKE_SYSTEM_NAME}-${CMAKE_BASE_NAME} OPTIONAL)

# This should be included before the _INIT variables are
# used to initialize the cache.  Since the rule variables
# have if blocks on them, users can still define them here.
# But, it should still be after the platform file so changes can
# be made to those values.

IF(CMAKE_USER_MAKE_RULES_OVERRIDE)
   INCLUDE(${CMAKE_USER_MAKE_RULES_OVERRIDE})
ENDIF(CMAKE_USER_MAKE_RULES_OVERRIDE)

IF(CMAKE_USER_MAKE_RULES_OVERRIDE_Pascal)
   INCLUDE(${CMAKE_USER_MAKE_RULES_OVERRIDE_Pascal})
ENDIF(CMAKE_USER_MAKE_RULES_OVERRIDE_Pascal)


# for most systems a module is the same as a shared library
# so unless the variable CMAKE_MODULE_EXISTS is set just
# copy the values from the LIBRARY variables
IF(NOT CMAKE_MODULE_EXISTS)
  SET(CMAKE_SHARED_MODULE_Pascal_FLAGS ${CMAKE_SHARED_LIBRARY_Pascal_FLAGS})
  SET(CMAKE_SHARED_MODULE_CREATE_Pascal_FLAGS ${CMAKE_SHARED_LIBRARY_CREATE_Pascal_FLAGS})
ENDIF(NOT CMAKE_MODULE_EXISTS)

# Create a set of shared library variable specific to Pascal
# For 90% of the systems, these are the same flags as the C versions
# so if these are not set just copy the flags from the c version
#IF(NOT CMAKE_SHARED_LIBRARY_CREATE_Ada_FLAGS)
#-dynamiclib -Wl,-headerpad_max_install_names for C
#  SET(CMAKE_SHARED_LIBRARY_CREATE_Ada_FLAGS ${CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS})
#ENDIF(NOT CMAKE_SHARED_LIBRARY_CREATE_Ada_FLAGS)

IF(NOT CMAKE_SHARED_LIBRARY_Pascal_FLAGS)
  #another similarity, fpc: -fPIC  Same as -Cg
  SET(CMAKE_SHARED_LIBRARY_Pascal_FLAGS ${CMAKE_SHARED_LIBRARY_C_FLAGS})
ENDIF(NOT CMAKE_SHARED_LIBRARY_Pascal_FLAGS)

IF(NOT CMAKE_SHARED_LIBRARY_LINK_Pascal_FLAGS)
  SET(CMAKE_SHARED_LIBRARY_LINK_Pascal_FLAGS ${CMAKE_SHARED_LIBRARY_LINK_C_FLAGS})
ENDIF(NOT CMAKE_SHARED_LIBRARY_LINK_Pascal_FLAGS)

#IF(NOT CMAKE_SHARED_LIBRARY_RUNTIME_Ada_FLAG)
#  SET(CMAKE_SHARED_LIBRARY_RUNTIME_Ada_FLAG ${CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG})
#ENDIF(NOT CMAKE_SHARED_LIBRARY_RUNTIME_Ada_FLAG)

#IF(NOT CMAKE_SHARED_LIBRARY_RUNTIME_Ada_FLAG_SEP)
#  SET(CMAKE_SHARED_LIBRARY_RUNTIME_Ada_FLAG_SEP ${CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG_SEP})
#ENDIF(NOT CMAKE_SHARED_LIBRARY_RUNTIME_Ada_FLAG_SEP)

if(NOT CMAKE_SHARED_LIBRARY_RPATH_LINK_Pascal_FLAG)
  set(CMAKE_SHARED_LIBRARY_RPATH_LINK_Pascal_FLAG ${CMAKE_SHARED_LIBRARY_RPATH_LINK_C_FLAG})
endif(NOT CMAKE_SHARED_LIBRARY_RPATH_LINK_Pascal_FLAG)

# for most systems a module is the same as a shared library
# so unless the variable CMAKE_MODULE_EXISTS is set just
# copy the values from the LIBRARY variables
if(NOT CMAKE_MODULE_EXISTS)
  set(CMAKE_SHARED_MODULE_Pascal_FLAGS ${CMAKE_SHARED_LIBRARY_Pascal_FLAGS})
  set(CMAKE_SHARED_MODULE_CREATE_Pascal_FLAGS ${CMAKE_SHARED_LIBRARY_CREATE_Pascal_FLAGS})
endif()

# repeat for modules
#IF(NOT CMAKE_SHARED_MODULE_CREATE_Ada_FLAGS)
#  SET(CMAKE_SHARED_MODULE_CREATE_Ada_FLAGS ${CMAKE_SHARED_MODULE_CREATE_C_FLAGS})
#ENDIF(NOT CMAKE_SHARED_MODULE_CREATE_Ada_FLAGS)

#IF(NOT CMAKE_SHARED_MODULE_Ada_FLAGS)
#  SET(CMAKE_SHARED_MODULE_Ada_FLAGS ${CMAKE_SHARED_MODULE_C_FLAGS})
#ENDIF(NOT CMAKE_SHARED_MODULE_Ada_FLAGS)

#IF(NOT CMAKE_SHARED_MODULE_RUNTIME_Ada_FLAG)
#  SET(CMAKE_SHARED_MODULE_RUNTIME_Ada_FLAG ${CMAKE_SHARED_MODULE_RUNTIME_C_FLAG})
#ENDIF(NOT CMAKE_SHARED_MODULE_RUNTIME_Ada_FLAG)

#IF(NOT CMAKE_SHARED_MODULE_RUNTIME_Ada_FLAG_SEP)
#  SET(CMAKE_SHARED_MODULE_RUNTIME_Ada_FLAG_SEP ${CMAKE_SHARED_MODULE_RUNTIME_C_FLAG_SEP})
#ENDIF(NOT CMAKE_SHARED_MODULE_RUNTIME_Ada_FLAG_SEP)

IF(NOT CMAKE_INCLUDE_FLAG_Pascal)
  #amazing, fpc: -I<x>  Add <x> to include path
  SET(CMAKE_INCLUDE_FLAG_Pascal ${CMAKE_INCLUDE_FLAG_C})
ENDIF(NOT CMAKE_INCLUDE_FLAG_Pascal)

IF(NOT CMAKE_INCLUDE_FLAG_SEP_Pascal)
  SET(CMAKE_INCLUDE_FLAG_SEP_Pascal ${CMAKE_INCLUDE_FLAG_SEP_C})
ENDIF(NOT CMAKE_INCLUDE_FLAG_SEP_Pascal)

# Copy C version of this flag which is normally determined in platform file.
IF(NOT CMAKE_SHARED_LIBRARY_SONAME_Pascal_FLAG)
  SET(CMAKE_SHARED_LIBRARY_SONAME_Pascal_FLAG ${CMAKE_SHARED_LIBRARY_SONAME_C_FLAG})
ENDIF(NOT CMAKE_SHARED_LIBRARY_SONAME_Pascal_FLAG)

SET(CMAKE_VERBOSE_MAKEFILE FALSE CACHE BOOL "If this value is on, makefiles will be generated without the .SILENT directive, and all commands will be echoed to the console during the make.  This is useful for debugging only. With Visual Studio IDE projects all commands are done without /nologo.")

SET (CMAKE_Pascal_FLAGS "$ENV{FPFLAGS} ${CMAKE_Pascal_FLAGS_INIT}" CACHE STRING
     "Flags for Pascal compiler.")

INCLUDE(CMakeCommonLanguageInclude)

# now define the following rule variables

# CMAKE_Ada_CREATE_SHARED_LIBRARY
# CMAKE_Ada_CREATE_SHARED_MODULE
# CMAKE_Ada_CREATE_STATIC_LIBRARY
# CMAKE_Ada_COMPILE_OBJECT
# CMAKE_Ada_LINK_EXECUTABLE

# variables supplied by the generator at use time
# <TARGET>
# <TARGET_BASE> the target without the suffix
# <OBJECTS>
# <OBJECT>
# <LINK_LIBRARIES>
# <FLAGS>
# <LINK_FLAGS>

# Ada compiler information
# <CMAKE_Ada_COMPILER>
# <CMAKE_SHARED_LIBRARY_CREATE_Ada_FLAGS>
# <CMAKE_SHARED_MODULE_CREATE_Ada_FLAGS>
# <CMAKE_Ada_LINK_FLAGS>

# Static library tools
# <CMAKE_AR>
# <CMAKE_RANLIB>

if (NOT EXECUTABLE_OUTPUT_PATH)
    set (EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR})
endif (NOT EXECUTABLE_OUTPUT_PATH)

# create an Ada shared library
IF(NOT CMAKE_Ada_CREATE_SHARED_LIBRARY)
    SET(CMAKE_Ada_CREATE_SHARED_LIBRARY
    "<CMAKE_Ada_COMPILER> <CMAKE_SHARED_LIBRARY_Ada_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_Ada_FLAGS> <CMAKE_SHARED_LIBRARY_SONAME_Ada_FLAG><TARGET_SONAME> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>"
    )
ENDIF(NOT CMAKE_Ada_CREATE_SHARED_LIBRARY)

# create an Ada shared module just copy the shared library rule
IF(NOT CMAKE_Ada_CREATE_SHARED_MODULE)
  SET(CMAKE_Ada_CREATE_SHARED_MODULE ${CMAKE_Ada_CREATE_SHARED_LIBRARY})
ENDIF(NOT CMAKE_Ada_CREATE_SHARED_MODULE)

# create an Ada static library
IF(NOT CMAKE_Ada_CREATE_STATIC_LIBRARY)
  SET(CMAKE_Ada_CREATE_STATIC_LIBRARY
      "<CMAKE_AR> cr <TARGET> <LINK_FLAGS> <OBJECTS> "
      "<CMAKE_RANLIB> <TARGET> ")
ENDIF(NOT CMAKE_Ada_CREATE_STATIC_LIBRARY)

# compile a Pascal file into an object file
IF(NOT CMAKE_Pascal_COMPILE_OBJECT)
  SET(CMAKE_Pascal_COMPILE_OBJECT
      "<CMAKE_Pascal_COMPILER> -Cn -FE${EXECUTABLE_OUTPUT_PATH} -FU${CMAKE_CURRENT_BINARY_DIR}/<OBJECT_DIR> -Fi${CMAKE_CURRENT_BINARY_DIR} <FLAGS> <SOURCE>")
ENDIF(NOT CMAKE_Pascal_COMPILE_OBJECT)


IF(NOT CMAKE_Pascal_LINK_EXECUTABLE)
#GET_FILENAME_COMPONENT(COMPILER_LOCATION "${CMAKE_Pascal_COMPILER}" PATH)
    set(CMAKE_Pascal_LINK_EXECUTABLE "${EXECUTABLE_OUTPUT_PATH}/ppas.sh")
#  SET(CMAKE_Pascal_LINK_EXECUTABLE "${CMAKE_Pascal_COMPILER} <CMAKE_Pascal_LINK_FLAGS> <LINK_FLAGS> <TARGET_BASE>.adb -cargs <FLAGS> -largs <LINK_LIBRARIES>")
ENDIF(NOT CMAKE_Pascal_LINK_EXECUTABLE)

IF(CMAKE_Ada_STANDARD_LIBRARIES_INIT)
  SET(CMAKE_Ada_STANDARD_LIBRARIES "${CMAKE_Ada_STANDARD_LIBRARIES_INIT}"
    CACHE STRING "Libraries linked by default with all Ada applications.")
  MARK_AS_ADVANCED(CMAKE_Ada_STANDARD_LIBRARIES)
ENDIF(CMAKE_Ada_STANDARD_LIBRARIES_INIT)

IF(NOT CMAKE_NOT_USING_CONFIG_FLAGS)
  SET (CMAKE_Ada_FLAGS_DEBUG "${CMAKE_Ada_FLAGS_DEBUG_INIT}" CACHE STRING
     "Flags used by the compiler during debug builds.")
  SET (CMAKE_Ada_FLAGS_MINSIZEREL "${CMAKE_Ada_FLAGS_MINSIZEREL_INIT}" CACHE STRING
     "Flags used by the compiler during release minsize builds.")
  SET (CMAKE_Ada_FLAGS_RELEASE "${CMAKE_Ada_FLAGS_RELEASE_INIT}" CACHE STRING
     "Flags used by the compiler during release builds (/MD /Ob1 /Oi /Ot /Oy /Gs will produce slightly less optimized but smaller files).")
  SET (CMAKE_Ada_FLAGS_RELWITHDEBINFO "${CMAKE_Ada_FLAGS_RELWITHDEBINFO_INIT}" CACHE STRING
     "Flags used by the compiler during Release with Debug Info builds.")
ENDIF(NOT CMAKE_NOT_USING_CONFIG_FLAGS)

MARK_AS_ADVANCED(
CMAKE_Pascal_FLAGS
CMAKE_Pascal_FLAGS_DEBUG
CMAKE_Pascal_FLAGS_MINSIZEREL
CMAKE_Pascal_FLAGS_RELEASE
CMAKE_Pascal_FLAGS_RELWITHDEBINFO
)
SET(CMAKE_Pascal_INFORMATION_LOADED 1)

