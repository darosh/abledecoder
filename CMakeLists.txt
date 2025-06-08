cmake_minimum_required(VERSION 3.10)

# Project name and version
project(abledecoder VERSION 1.0.0)

# Set C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add compiler flags for better error checking
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")

# Debug/Release configurations
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Find required packages
find_package(OpenSSL REQUIRED)

# Source files
set(SOURCES
    main.cpp
    AbleChunk.cpp
    CommonChunk.cpp
    FileChunk.cpp
    FormChunk.cpp
    FormatVersionChunk.cpp
    SoundDataChunk.cpp
)

# Header files (for IDE support)
set(HEADERS
    AbleChunk.h
    Array.h
    CommonChunk.h
    FileChunk.h
    FormChunk.h
    FormatVersionChunk.h
    SoundDataChunk.h
    Utils.h
)

# Create the executable
add_executable(abledecoder ${SOURCES} ${HEADERS})

# Link libraries
target_link_libraries(abledecoder PRIVATE OpenSSL::SSL OpenSSL::Crypto)

# Installation
install(TARGETS abledecoder
    RUNTIME DESTINATION bin
)

# Optional: Enable testing if you plan to add tests
# enable_testing()

# Print build information
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "C++ flags: ${CMAKE_CXX_FLAGS}")

