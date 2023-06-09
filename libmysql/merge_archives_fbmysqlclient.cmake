# Copyright (c) 2009 Sun Microsystems, Inc.
# Use is subject to license terms.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA 

# This script merges many static libraries into
# one big library on Unix.
SET(TARGET_LOCATION "/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/libmysql/libfbmysqlclient.a")
SET(TARGET "fbmysqlclient")
SET(STATIC_LIBS "/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/libmysql/libclientlib.a;/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/dbug/libdbug.a;/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/strings/libstrings.a;/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/vio/libvio.a;/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/mysys/libmysys.a;/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/mysys_ssl/libmysys_ssl.a")
SET(CMAKE_CURRENT_BINARY_DIR "/mnt/c/Users/Nando/Documents/GarudaAce/Works/mysql-5.6/libmysql")
SET(CMAKE_AR "/usr/bin/ar")
SET(CMAKE_RANLIB "/usr/bin/ranlib")

FIND_PROGRAM(SORT_EXECUTABLE sort DOC "path to the sort executable")
FIND_PROGRAM(UNIQ_EXECUTABLE uniq DOC "path to the uniq executable")
FIND_PROGRAM(SED_EXECUTABLE sed DOC "path to the sed executable")

SET(TEMP_DIR ${CMAKE_CURRENT_BINARY_DIR}/merge_archives_${TARGET})
MAKE_DIRECTORY(${TEMP_DIR})
# Extract each archive to its own subdirectory(avoid object filename clashes)
FOREACH(LIB ${STATIC_LIBS})
  GET_FILENAME_COMPONENT(NAME_NO_EXT ${LIB} NAME_WE)
  SET(TEMP_SUBDIR ${TEMP_DIR}/${NAME_NO_EXT})
  SET(LIB_FILES_FILE ${NAME_NO_EXT}_files.txt)
  MAKE_DIRECTORY(${TEMP_SUBDIR})

  # We have to avoid name clashes within the same archive
  # because ar -x libX.a extracts only one of the files
  # with the same name. We first determine the filenames
  # in libX.a and how many times they occur. Then we extract
  # each instance for that filename using the -N parameter.

  # Write the object file names along with how many times
  # they occur into an output file.
  EXECUTE_PROCESS(
    COMMAND ${CMAKE_AR} -t ${LIB}
    COMMAND ${SORT_EXECUTABLE}
    COMMAND ${UNIQ_EXECUTABLE} -c
    COMMAND ${SED_EXECUTABLE} -e "s/^ *//g"
    OUTPUT_FILE ${LIB_FILES_FILE}
    WORKING_DIRECTORY ${TEMP_SUBDIR}
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  # read output file into a list.
  FILE(STRINGS ${TEMP_SUBDIR}/${LIB_FILES_FILE} LIB_FILES)
  # remove the output file.
  FILE(REMOVE ${TEMP_SUBDIR}/${LIB_FILES_FILE})
  FOREACH(COUNT_FILE ${LIB_FILES})
     SEPARATE_ARGUMENTS(COUNT_FILE)
     LIST(GET COUNT_FILE 0 COUNT)
     LIST(GET COUNT_FILE 1 OBJ_FILE)
     GET_FILENAME_COMPONENT(OBJ_FILE_NO_EXT ${OBJ_FILE} NAME_WE)
     GET_FILENAME_COMPONENT(OBJ_FILE_EXT ${OBJ_FILE} EXT)

     WHILE(COUNT GREATER 0)
       EXECUTE_PROCESS(
         COMMAND ${CMAKE_AR} -x -N ${COUNT} ${LIB} ${OBJ_FILE}
         WORKING_DIRECTORY ${TEMP_SUBDIR}
       )

       # Add the count prefix to the filename to avoid filename clashes
       # if there is more than one file with the same name.
       IF (COUNT GREATER 1)
         FILE(RENAME ${TEMP_SUBDIR}/${OBJ_FILE} ${TEMP_SUBDIR}/${OBJ_FILE_NO_EXT}-${COUNT}${OBJ_FILE_EXT})
       ENDIF()
       MATH( EXPR COUNT "${COUNT} - 1" )
     ENDWHILE()
  ENDFOREACH()
  FILE(GLOB_RECURSE LIB_OBJECTS "${TEMP_SUBDIR}/*")
  SET(OBJECTS ${OBJECTS} ${LIB_OBJECTS})
ENDFOREACH()

# Use relative paths, makes command line shorter.
GET_FILENAME_COMPONENT(ABS_TEMP_DIR ${TEMP_DIR} ABSOLUTE)
FOREACH(OBJ ${OBJECTS})
  FILE(RELATIVE_PATH OBJ ${ABS_TEMP_DIR} ${OBJ})
  FILE(TO_NATIVE_PATH ${OBJ} OBJ)
  SET(ALL_OBJECTS ${ALL_OBJECTS} ${OBJ})
ENDFOREACH()

FILE(TO_NATIVE_PATH ${TARGET_LOCATION} ${TARGET_LOCATION})
# Now pack the objects into library with ar.
EXECUTE_PROCESS(
  COMMAND ${CMAKE_AR} -r ${TARGET_LOCATION} ${ALL_OBJECTS}
  WORKING_DIRECTORY ${TEMP_DIR}
)
EXECUTE_PROCESS(
  COMMAND ${CMAKE_RANLIB} ${TARGET_LOCATION}
  WORKING_DIRECTORY ${TEMP_DIR}
)

# Cleanup
FILE(REMOVE_RECURSE ${TEMP_DIR})
