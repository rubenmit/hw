
find_package(SDL REQUIRED)
include_directories(${PHYSFS_INCLUDE_DIR})
include_directories(${SDL_INCLUDE_DIR})
include_directories(${LUA_INCLUDE_DIR})

## extra functions needed by Hedgewars
## TODO: maybe it's better to have them in a separate library?
set(PHYSLAYER_SRCS
    physfsrwops.c
    physfslualoader.c
    hwpacksmounter.c
)

#compiles and links actual library
add_library (physlayer ${PHYSLAYER_SRCS})
#TODO: find good VERSION and SOVERSION values
target_link_libraries(physlayer ${SDL_LIBRARY} lua physfs)
install(TARGETS physlayer RUNTIME DESTINATION ${target_binary_install_dir}
                          LIBRARY DESTINATION ${target_library_install_dir}
                          ARCHIVE DESTINATION ${target_library_install_dir})
get_target_property(physlayer_fullpath physlayer LOCATION)


## added standard variables (FORCE or cmake won't pick 'em)
set(PHYSLAYER_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR} CACHE STRING "Physlayer include dir" FORCE)
set(PHYSLAYER_LIBRARY ${physlayer_fullpath} CACHE STRING "Physlayer library" FORCE)

