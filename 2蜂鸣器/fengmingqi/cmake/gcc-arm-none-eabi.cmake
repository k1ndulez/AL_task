set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          arm)

set(CMAKE_C_COMPILER_ID GNU)
set(CMAKE_CXX_COMPILER_ID GNU)

# Some default GCC settings
set(TOOLCHAIN_PREFIX                arm-none-eabi-)

# Locate the GNU Arm toolchain.
# The STM32 VS Code extension installs it into
#   %LOCALAPPDATA%\stm32cube\bundles\gnu-tools-for-stm32\<version>\bin
# Resolving it to an absolute path keeps the build working even when that folder
# is not on PATH (that is what produced "arm-none-eabi-gcc ... is not a full
# path and was not found in the PATH"). If no bundle is installed we fall back
# to the plain executable name, i.e. a normal PATH lookup.
file(GLOB _STM32_TOOLCHAIN_HINTS
     "$ENV{LOCALAPPDATA}/stm32cube/bundles/gnu-tools-for-stm32/*/bin")
find_program(STM32_TOOLCHAIN_GCC NAMES ${TOOLCHAIN_PREFIX}gcc HINTS ${_STM32_TOOLCHAIN_HINTS})
unset(_STM32_TOOLCHAIN_HINTS)

if(STM32_TOOLCHAIN_GCC)
    get_filename_component(STM32_TOOLCHAIN_DIR "${STM32_TOOLCHAIN_GCC}" DIRECTORY)
    set(TOOLCHAIN_BIN "${STM32_TOOLCHAIN_DIR}/")
    # A full path on Windows must carry the .exe suffix, otherwise CMake rejects
    # it as "not a full path to an existing compiler tool".
    if(CMAKE_HOST_WIN32)
        set(TOOLCHAIN_EXE ".exe")
    else()
        set(TOOLCHAIN_EXE "")
    endif()
    message(STATUS "GNU Arm toolchain: ${STM32_TOOLCHAIN_GCC}")
else()
    set(TOOLCHAIN_BIN "")
    set(TOOLCHAIN_EXE "")
    message(STATUS "GNU Arm toolchain: ${TOOLCHAIN_PREFIX}gcc (from PATH)")
endif()

set(CMAKE_C_COMPILER                ${TOOLCHAIN_BIN}${TOOLCHAIN_PREFIX}gcc${TOOLCHAIN_EXE})
set(CMAKE_ASM_COMPILER              ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER              ${TOOLCHAIN_BIN}${TOOLCHAIN_PREFIX}g++${TOOLCHAIN_EXE})
set(CMAKE_LINKER                    ${CMAKE_CXX_COMPILER})
set(CMAKE_OBJCOPY                   ${TOOLCHAIN_BIN}${TOOLCHAIN_PREFIX}objcopy${TOOLCHAIN_EXE})
set(CMAKE_SIZE                      ${TOOLCHAIN_BIN}${TOOLCHAIN_PREFIX}size${TOOLCHAIN_EXE})
set(CMAKE_AR                        ${TOOLCHAIN_BIN}${TOOLCHAIN_PREFIX}ar${TOOLCHAIN_EXE})
set(CMAKE_RANLIB                    ${TOOLCHAIN_BIN}${TOOLCHAIN_PREFIX}ranlib${TOOLCHAIN_EXE})

set(CMAKE_EXECUTABLE_SUFFIX_ASM     ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_C       ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_CXX     ".elf")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# MCU specific flags
set(TARGET_FLAGS "-mcpu=cortex-m3 ")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${TARGET_FLAGS}")
set(CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS} -x assembler-with-cpp -MMD -MP")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -fdata-sections -ffunction-sections -fstack-usage")

# The cyclomatic-complexity parameter must be defined for the Cyclomatic complexity feature in STM32CubeIDE to work.
# However, most GCC toolchains do not support this option, which causes a compilation error; for this reason, the feature is disabled by default.
# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fcyclomatic-complexity")

set(CMAKE_C_FLAGS_DEBUG "-O0 -g3")
set(CMAKE_C_FLAGS_RELEASE "-Os -g0")
set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g3")
set(CMAKE_CXX_FLAGS_RELEASE "-Os -g0")

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -fno-rtti -fno-exceptions -fno-threadsafe-statics")

set(CMAKE_EXE_LINKER_FLAGS "${TARGET_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -T \"${CMAKE_SOURCE_DIR}/STM32F103xx_FLASH.ld\"")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --specs=nano.specs")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-Map=${CMAKE_PROJECT_NAME}.map -Wl,--gc-sections")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--print-memory-usage")
set(TOOLCHAIN_LINK_LIBRARIES "m")
