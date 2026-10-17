cmake_minimum_required(VERSION 3.24)
project(RealmsAudioDependencies LANGUAGES C)
include(FetchContent)

set(OPUS_BUILD_SHARED_LIBRARY OFF CACHE BOOL "" FORCE)
set(OPUS_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(OPUS_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(OPUS_STATIC_RUNTIME ON CACHE BOOL "" FORCE)
FetchContent_Declare(opus
    URL https://github.com/xiph/opus/releases/download/v1.5.2/opus-1.5.2.tar.gz
    URL_HASH SHA256=65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(opus)

FetchContent_Declare(miniaudio
    URL https://raw.githubusercontent.com/mackron/miniaudio/0.11.25/miniaudio.h
    URL_HASH SHA256=ac7af4de748b7e26b777f37e01cee313a308a7296a3eb080e2906b320cc55c89
    DOWNLOAD_NO_EXTRACT TRUE)
FetchContent_MakeAvailable(miniaudio)

FetchContent_Declare(webrtc
    URL https://gstreamer.freedesktop.org/src/mirror/webrtc-audio-processing/webrtc-audio-processing-2.1.tar.gz
    URL_HASH SHA256=35e86b986d02ea15f3d04741a1a5a735ba399bc0fac0ee089c39480e35fc3253
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    PATCH_COMMAND "${CMAKE_COMMAND}" -DWEBRTC_SOURCE_DIR=<SOURCE_DIR>
        -P "${CMAKE_CURRENT_LIST_DIR}/webrtc-static.cmake")
FetchContent_MakeAvailable(webrtc)

# 0.11.25 leaks stopEvent when backend device initialization fails.
file(READ "${miniaudio_SOURCE_DIR}/miniaudio.h" miniaudio_header)
set(cleanup_before [=[result = pContext->callbacks.onDeviceInit(pDevice, pConfig, &descriptorPlayback, &descriptorCapture);
    if (result != MA_SUCCESS) {
        ma_event_uninit(&pDevice->startEvent);]=])
set(cleanup_after [=[result = pContext->callbacks.onDeviceInit(pDevice, pConfig, &descriptorPlayback, &descriptorCapture);
    if (result != MA_SUCCESS) {
        ma_event_uninit(&pDevice->stopEvent);
        ma_event_uninit(&pDevice->startEvent);]=])
string(REPLACE "${cleanup_before}" "${cleanup_after}" patched_header "${miniaudio_header}")
if(patched_header STREQUAL miniaudio_header)
    message(FATAL_ERROR "miniaudio stopEvent cleanup patch did not match")
endif()
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/include")
file(WRITE "${CMAKE_BINARY_DIR}/include/miniaudio.h" "${patched_header}")
