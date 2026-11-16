# THE XPCE KERNEL LIBRARY (DESIGN-PLAN prolog-xpce step 1, the cio 2026-11-16; skill prolog reference, THE XPCE FACILITY).
# XPCE's C kernel of tag V9.0.4, read where it stands (/home/resources/xpce-V9.0.4) with no source line changed, built as ONE shared
# library with no SWI-Prolog in it. The sources and the configure checks are the tree's own cmake/XPCESources.cmake and
# cmake/XPCEConfig.cmake; what is left out is the oracle's host interface (swipl/interface.c, swipl/pcecall.c) and -DSWI.
# The 29 stream functions the kernel asks of its host are the oracle's own pl-stream.c and pl-utf8.c of swipl 9.0.4, compiled in
# unchanged behind four seam headers (seams/) and one seams file (xpce_stream_seams.c). xpce_host.c exports the three kernel entries
# the kernel's own headers hide. The library exports the names of EXPORTS.txt and no other. Built by scripts/util_xpce_kernel_build.sh.
cmake_minimum_required(VERSION 3.5)
project(xpce-kernel C)

set(XPCE_TREE /home/resources/xpce-V9.0.4 CACHE PATH "the XPCE source tree")
set(SWIPL_TREE /home/resources/swipl-devel-master CACHE PATH "a SWI-Prolog tree, read for three cmake helper files only")
set(SWIPL_OS_TREE /home/resources/swipl-V9.0.4-os CACHE PATH "swipl-devel tag V9.0.4, read for pl-stream.c and pl-utf8.c")
list(APPEND CMAKE_MODULE_PATH ${XPCE_TREE}/cmake ${SWIPL_TREE}/cmake ${SWIPL_TREE}/packages/cmake)

include(CheckIncludeFile)
include(CheckFunctionExists)
include(CheckLibraryExists)
include(CheckStructHasMember)
include(CheckTypeSize)
include(Utils)

find_package(X11 REQUIRED)
find_package(Freetype REQUIRED)
find_package(FontConfig REQUIRED)
find_package(JPEG REQUIRED)
if(NOT X11_Xpm_LIB)
  message(FATAL_ERROR "no libXpm")
endif()

set(HAVE_GUI 1)
set(GUI_LIBRARIES ${X11_Xpm_LIB} ${X11_Xext_LIB} ${X11_Xt_LIB} ${X11_X11_LIB} ${X11_SM_LIB} ${X11_ICE_LIB}
    ${X11_Xft_LIB} ${FREETYPE_LIBRARIES} ${FONTCONFIG_LIBRARIES})
set(GUI_INCLUDE_DIRS ${X11_INCLUDE_DIR} ${FREETYPE_INCLUDE_DIRS} ${FONTCONFIG_INCLUDE_DIR} ${JPEG_INCLUDE_DIR})

include(XPCESources)
include(XPCEConfig)
if(HAVE_X11_EXTENSIONS_XINERAMA_H)
  set(GUI_LIBRARIES ${X11_Xinerama_LIB} ${GUI_LIBRARIES})
endif()
set(PCE_MACHINE x86_64-linux)
set(PCE_OS ${CMAKE_HOST_SYSTEM_NAME})
set(PCE_VERSION 6.6.6)
if(XPCE_PLMT)
  set(O_PLMT 1)
endif()
# Values the parent SWI-Prolog build hands down and the tree's own checks never set. MEASURED: without RETSIGTYPE
# ker/conversion.c refuses to compile. The other two are read by md.h and h/unix.h only.
# MEASURED: without the dirent.h check unx/directory.c refuses (the parent's Config.cmake runs these header checks
# and their cached results reach XPCE's config.h). Left undefined on purpose: O_PLMT and _REENTRANT (no thread in
# the kernel's host here; the lock of ker/passing.c compiles out).
set(RETSIGTYPE void)
set(HAVE_VISIBILITY_ATTRIBUTE 1)
set(STDC_HEADERS 1)
set(TIME_WITH_SYS_TIME 1)
AC_CHECK_HEADERS(dirent.h inttypes.h stdlib.h strings.h sys/stat.h sys/dir.h alloca.h)
configure_file(${XPCE_TREE}/config.h.cmake config.h)

add_compile_options(-DHAVE_CONFIG_H)

set(KERNEL_SOURCES)
foreach(f ${XPCE_SOURCES})
  list(APPEND KERNEL_SOURCES ${XPCE_TREE}/${f})
endforeach()

add_executable(find_names ${XPCE_TREE}/src/find_names.c)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/h/names.ih ${CMAKE_CURRENT_BINARY_DIR}/h/names.ic
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/h
    COMMAND sh -c "$<TARGET_FILE:find_names> ${CMAKE_CURRENT_BINARY_DIR}/h/names.ic ${CMAKE_CURRENT_BINARY_DIR}/h/names.ih -- h/*.h adt/*.c ari/*.c box/*.c evt/*.c fmt/*.c gnu/*.c gra/*.c img/*.c itf/*.c ker/*.c men/*.c msg/*.c msw/*.c prg/*.c rel/*.c rgx/*.c txt/*.c unx/*.c win/*.c x11/*.c"
    WORKING_DIRECTORY ${XPCE_TREE}/src
    DEPENDS find_names
    COMMENT "Collecting NAME_ declarations")
add_custom_target(xpce_names DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/h/names.ih)

# THE 29 STREAM FUNCTIONS (HOSTING 3.9, road S3): pl-stream.c and pl-utf8.c of swipl 9.0.4, copied as they stand into the build so that
# their one relative include ("../pl-mutex.h") reads the seam header; the other seams are headers found first on the include path and
# one C file. No line of either source is changed. They are compiled hidden: the library exports no S name.
set(STREAM_DIR ${CMAKE_CURRENT_BINARY_DIR}/streams)
foreach(f pl-stream.c pl-utf8.c pl-utf8.h pl-stream.h SWI-Stream.h)
  configure_file(${SWIPL_OS_TREE}/src/os/${f} ${STREAM_DIR}/os/${f} COPYONLY)
endforeach()
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/seams/pl-mutex.h ${STREAM_DIR}/pl-mutex.h COPYONLY)
add_library(xpce_streams OBJECT ${STREAM_DIR}/os/pl-stream.c ${STREAM_DIR}/os/pl-utf8.c ${CMAKE_CURRENT_SOURCE_DIR}/xpce_stream_seams.c)
target_include_directories(xpce_streams BEFORE PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/seams ${STREAM_DIR}/os ${SWIPL_OS_TREE}/src)
target_compile_options(xpce_streams PRIVATE -fvisibility=hidden -UHAVE_CONFIG_H)
set_property(TARGET xpce_streams PROPERTY POSITION_INDEPENDENT_CODE ON)

add_library(xpce SHARED ${KERNEL_SOURCES} ${CMAKE_CURRENT_SOURCE_DIR}/xpce_host.c $<TARGET_OBJECTS:xpce_streams>)
add_dependencies(xpce xpce_names)
target_include_directories(xpce BEFORE PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${XPCE_TREE}/src ${GUI_INCLUDE_DIRS})
target_link_libraries(xpce ${GUI_LIBRARIES} ${JPEG_LIBRARIES} m)
