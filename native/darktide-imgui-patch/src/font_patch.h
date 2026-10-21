#pragma once

extern "C" __declspec(dllexport) int ImguiPatch_ConfigureFonts();
extern "C" __declspec(dllexport) int ImguiPatch_InstallTextCapture();
extern "C" __declspec(dllexport) int ImguiPatch_PollTextCapture();
extern "C" __declspec(dllexport) int ImguiPatch_UninstallTextCapture();
extern "C" __declspec(dllexport) int ImguiPatch_WantsTextInput();
extern "C" __declspec(dllexport) const char* ImguiPatch_LastError();
