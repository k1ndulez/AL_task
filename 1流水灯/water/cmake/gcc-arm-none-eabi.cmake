set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          arm)

set(CMAKE_C_COMPILER_ID GNU)
set(CMAKE_CXX_COMPILER_ID GNU)

# ---------------------------------------------------------------------------
# Locate the GNU Arm Embedded toolchain (arm-none-eabi-gcc).
#
# The compiler is resolved to an absolute path, so a configure started
# without the toolchain on PATH still works (Visual Studio CMake integration,
# plain "cmake -B build", CMake Tools, ...).
#
# Resolution order:
#   1. -DTOOLCHAIN_PATH=<bin dir or install root>   (cache / command line)
#   2. environment variable TOOLCHAIN_PATH
#   3. arm-none-eabi-gcc already available on PATH
#   4. STM32Cube bundles installed by the STM32 VS Code extension (Windows)
#   5. usual GNU Arm Embedded / STM32CubeIDE install locations
# ---------------------------------------------------------------------------
set(TOOLCHAIN_PREFIX                arm-none-eabi-)

if(NOT TOOLCHAIN_PATH AND NOT "$ENV{TOOLCHAIN_PATH}" STREQUAL "")
    set(TOOLCHAIN_PATH "$ENV{TOOLCHAIN_PATH}")
endif()

# 1./2. explicit path (accept both the bin directory and the install root)
if(TOOLCHAIN_PATH)
    file(TO_CMAKE_PATH "${TOOLCHAIN_PATH}" TOOLCHAIN_PATH)
    if(EXISTS "${TOOLCHAIN_PATH}/arm-none-eabi-gcc" OR EXISTS "${TOOLCHAIN_PATH}/arm-none-eabi-gcc.exe")
        set(ARM_TOOLCHAIN_BIN "${TOOLCHAIN_PATH}")
    elseif(EXISTS "${TOOLCHAIN_PATH}/bin/arm-none-eabi-gcc" OR EXISTS "${TOOLCHAIN_PATH}/bin/arm-none-eabi-gcc.exe")
        set(ARM_TOOLCHAIN_BIN "${TOOLCHAIN_PATH}/bin")
    else()
        message(FATAL_ERROR
            "TOOLCHAIN_PATH='${TOOLCHAIN_PATH}' does not contain arm-none-eabi-gcc. "
            "Point it to the directory that holds arm-none-eabi-gcc(.exe).")
    endif()
endif()

# 3. compiler on PATH
if(NOT ARM_TOOLCHAIN_BIN)
    find_program(ARM_NONE_EABI_GCC NAMES arm-none-eabi-gcc NO_CACHE)
    if(ARM_NONE_EABI_GCC)
        get_filename_component(ARM_TOOLCHAIN_BIN "${ARM_NONE_EABI_GCC}" DIRECTORY)
    endif()
endif()

# 4. STM32Cube bundles (STM32 VS Code extension), newest version first
if(NOT ARM_TOOLCHAIN_BIN AND WIN32)
    file(GLOB _stm32cube_bins
        "$ENV{LOCALAPPDATA}/stm32cube/bundles/gnu-tools-for-stm32/*/bin")
    if(_stm32cube_bins)
        list(SORT _stm32cube_bins COMPARE NATURAL ORDER DESCENDING)
        foreach(_bin IN LISTS _stm32cube_bins)
            if(EXISTS "${_bin}/arm-none-eabi-gcc.exe")
                set(ARM_TOOLCHAIN_BIN "${_bin}")
                break()
            endif()
        endforeach()
    endif()
endif()

# 5. common install locations
if(NOT ARM_TOOLCHAIN_BIN)
    foreach(_pattern
            "$ENV{ProgramFiles}/GNU Arm Embedded Toolchain/*/bin"
            "/opt/arm-gnu-toolchain*/bin"
            "C:/ST/STM32CubeIDE*/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.*/tools/bin")
        file(GLOB _bins "${_pattern}")
        if(_bins)
            list(SORT _bins COMPARE NATURAL ORDER DESCENDING)
            foreach(_bin IN LISTS _bins)
                if(EXISTS "${_bin}/arm-none-eabi-gcc" OR EXISTS "${_bin}/arm-none-eabi-gcc.exe")
                    set(ARM_TOOLCHAIN_BIN "${_bin}")
                    break()
                endif()
            endforeach()
        endif()
        if(ARM_TOOLCHAIN_BIN)
            break()
        endif()
    endforeach()
endif()

if(NOT ARM_TOOLCHAIN_BIN)
    message(FATAL_ERROR
        "arm-none-eabi-gcc was not found.\n"
        "Install the GNU Arm toolchain (the STM32 VS Code extension bundles are "
        "detected automatically), or configure with "
        "-DTOOLCHAIN_PATH=<directory containing arm-none-eabi-gcc>.")
endif()

# Normalise to forward slashes: the path is written into generated CMake files,
# where a "C:\..." prefix would be parsed as an invalid escape sequence ("\U").
file(TO_CMAKE_PATH "${ARM_TOOLCHAIN_BIN}" ARM_TOOLCHAIN_BIN)

message(STATUS "Using GNU Arm toolchain: ${ARM_TOOLCHAIN_BIN}")

# Full path, so that the compiler no longer has to be on PATH
set(TOOLCHAIN_PREFIX                "${ARM_TOOLCHAIN_BIN}/arm-none-eabi-")

# CMake verifies that CMAKE_<LANG>_COMPILER names an existing file, so on
# Windows the ".exe" suffix has to be part of the path.
set(ARM_EXE_SUFFIX "")
if(EXISTS "${TOOLCHAIN_PREFIX}gcc.exe")
    set(ARM_EXE_SUFFIX ".exe")
endif()

set(CMAKE_C_COMPILER                "${TOOLCHAIN_PREFIX}gcc${ARM_EXE_SUFFIX}")
set(CMAKE_ASM_COMPILER              ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER              "${TOOLCHAIN_PREFIX}g++${ARM_EXE_SUFFIX}")
set(CMAKE_LINKER                    "${TOOLCHAIN_PREFIX}g++${ARM_EXE_SUFFIX}")
set(CMAKE_OBJCOPY                   "${TOOLCHAIN_PREFIX}objcopy${ARM_EXE_SUFFIX}")
set(CMAKE_SIZE                      "${TOOLCHAIN_PREFIX}size${ARM_EXE_SUFFIX}")

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
