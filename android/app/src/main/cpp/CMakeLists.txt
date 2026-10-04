cmake_minimum_required(VERSION 3.22.1)
project(car_presence_discord)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(DISCORD_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/discord-social-sdk")

if(EXISTS "${DISCORD_SDK_ROOT}/discord_social_sdk/include/discordpp.h")
  set(DISCORD_INCLUDE "${DISCORD_SDK_ROOT}/discord_social_sdk/include")
elseif(EXISTS "${DISCORD_SDK_ROOT}/include/discordpp.h")
  set(DISCORD_INCLUDE "${DISCORD_SDK_ROOT}/include")
elseif(EXISTS "${DISCORD_SDK_ROOT}/discordpp.h")
  set(DISCORD_INCLUDE "${DISCORD_SDK_ROOT}")
else()
  message(FATAL_ERROR "Discord Social SDK 1.10.19337 not found at ${DISCORD_SDK_ROOT}")
endif()

list(APPEND CMAKE_PREFIX_PATH
  "${DISCORD_SDK_ROOT}"
  "${DISCORD_SDK_ROOT}/lib/cmake"
  "${DISCORD_SDK_ROOT}/share/cmake"
)
find_package(discord_partner_sdk CONFIG QUIET)

add_library(car_presence_discord SHARED discord_bridge.cpp)
target_include_directories(car_presence_discord PRIVATE "${DISCORD_INCLUDE}")
target_compile_definitions(car_presence_discord PRIVATE DISCORDPP_IMPLEMENTATION)

if(discord_partner_sdk_FOUND)
  target_link_libraries(car_presence_discord discord_partner_sdk::discord_partner_sdk log android)
else()
  file(GLOB_RECURSE DISCORD_SO LIST_DIRECTORIES false "${DISCORD_SDK_ROOT}/*.so")
  set(DISCORD_MATCH "")
  foreach(candidate ${DISCORD_SO})
    if(candidate MATCHES "${ANDROID_ABI}/libdiscord_partner_sdk\\.so$" AND NOT candidate MATCHES "krisp")
      set(DISCORD_MATCH "${candidate}")
    endif()
  endforeach()
  if(DISCORD_MATCH STREQUAL "")
    message(FATAL_ERROR "libdiscord_partner_sdk.so for ${ANDROID_ABI} not found under ${DISCORD_SDK_ROOT}")
  endif()
  add_library(discord_partner_sdk_prebuilt SHARED IMPORTED)
  set_target_properties(discord_partner_sdk_prebuilt PROPERTIES
    IMPORTED_LOCATION "${DISCORD_MATCH}"
  )
  target_link_libraries(car_presence_discord discord_partner_sdk_prebuilt log android)
endif()
