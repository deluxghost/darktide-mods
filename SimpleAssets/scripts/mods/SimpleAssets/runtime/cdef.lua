local ffi = Mods.lua.ffi

if pcall(ffi.typeof, "SimpleAssetsRuntime_CDEF") then
	return true
end

ffi.cdef([[
		typedef void* SimpleAssets_HANDLE;
		typedef unsigned long SimpleAssets_DWORD;
		typedef int SimpleAssets_BOOL;
		typedef unsigned short SimpleAssets_WCHAR;

		typedef struct {
			SimpleAssets_DWORD dwLowDateTime;
			SimpleAssets_DWORD dwHighDateTime;
		} SimpleAssets_FILETIME;

		typedef struct {
			SimpleAssets_DWORD dwFileAttributes;
			SimpleAssets_FILETIME ftCreationTime;
			SimpleAssets_FILETIME ftLastAccessTime;
			SimpleAssets_FILETIME ftLastWriteTime;
			SimpleAssets_DWORD nFileSizeHigh;
			SimpleAssets_DWORD nFileSizeLow;
			SimpleAssets_DWORD dwReserved0;
			SimpleAssets_DWORD dwReserved1;
			SimpleAssets_WCHAR cFileName[260];
			SimpleAssets_WCHAR cAlternateFileName[14];
		} SimpleAssets_WIN32_FIND_DATAW;

		int SimpleAssetsRuntime_Start(void);
		int SimpleAssetsRuntime_DetectImageFormat(const char* path);
		int SimpleAssetsRuntime_AnimationLoad(const char* asset_path);
		int SimpleAssetsRuntime_AnimationReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_FontLoad(const char* asset_path);
		int SimpleAssetsRuntime_FontReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_MaterialLoad(const char* asset_path);
		int SimpleAssetsRuntime_MaterialReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_MouseCursorLoad(const char* asset_path, unsigned int hotspot_x, unsigned int hotspot_y);
		int SimpleAssetsRuntime_MouseCursorReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_ParticlesLoad(const char* asset_path);
		int SimpleAssetsRuntime_ParticlesReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_ResourceState(const char* resource_type, const char* asset_path);
		int SimpleAssetsRuntime_SlugAlbumLoad(const char* asset_path);
		int SimpleAssetsRuntime_SlugAlbumReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_TextureLoad(const char* asset_path);
		int SimpleAssetsRuntime_TextureReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_UnitLoad(const char* asset_path);
		int SimpleAssetsRuntime_UnitReplace(const char* target_resource_path, const char* source_asset_path);
		int SimpleAssetsRuntime_VideoLoad(const char* asset_path);
		int SimpleAssetsRuntime_VideoReplace(const char* target_resource_path, const char* source_asset_path);
		const char* SimpleAssetsRuntime_GameDir(void);
		const char* SimpleAssetsRuntime_UserDir(void);
		const char* SimpleAssetsRuntime_CanonicalAssetPath(const char* path);
		const char* SimpleAssetsRuntime_AssetUrl(const char* path);
		const char* SimpleAssetsRuntime_LastError(void);
		void SimpleAssetsRuntime_Shutdown(void);
		SimpleAssets_DWORD SimpleAssetsRuntime_GetLastError(void);
		SimpleAssets_DWORD SimpleAssetsRuntime_GetFileAttributesW(const SimpleAssets_WCHAR* lpFileName);
		int SimpleAssetsRuntime_MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, SimpleAssets_WCHAR* lpWideCharStr, int cchWideChar);
		int SimpleAssetsRuntime_WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const SimpleAssets_WCHAR* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, SimpleAssets_BOOL* lpUsedDefaultChar);
		SimpleAssets_HANDLE SimpleAssetsRuntime_FindFirstFileW(const SimpleAssets_WCHAR* lpFileName, SimpleAssets_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAssets_BOOL SimpleAssetsRuntime_FindNextFileW(SimpleAssets_HANDLE hFindFile, SimpleAssets_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAssets_BOOL SimpleAssetsRuntime_FindClose(SimpleAssets_HANDLE hFindFile);

		typedef struct { int unused; } SimpleAssetsRuntime_CDEF;
]])

return true
