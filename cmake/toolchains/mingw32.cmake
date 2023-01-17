## For GUI cross-compilation, use:
##   cmake --toolchain ../cmake/toolchains/mingw32.cmake -DBUILD_TESTING=ON -DENABLE_GUI=ON -DCMAKE_BUILD_TYPE=Debug -DGLFW3_ROOT=/home/alberto/dll/glfw-3.3.8.bin.WIN64 -DUSE_GUI_THREADS=OFF ..
##

set(CMAKE_SYSTEM_NAME Windows)
set(TOOLCHAIN_PREFIX x86_64-w64-mingw32)
set(CMAKE_CROSSCOMPILING_EMULATOR wine)

set(_WIN32 1)
set(CMAKE_Fortran_COMPILER ${TOOLCHAIN_PREFIX}-gfortran)
set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)

set(CMAKE_FIND_ROOT_PATH /usr/${TOOLCHAIN_PREFIX})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
