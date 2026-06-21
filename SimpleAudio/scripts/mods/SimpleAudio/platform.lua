local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local platform = {}

local CP_UTF8 = 65001
local ERROR_FILE_NOT_FOUND = 2
local ERROR_PATH_NOT_FOUND = 3
local ERROR_NO_MORE_FILES = 18
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local CREATE_NO_WINDOW = 0x08000000
local STARTF_USESHOWWINDOW = 0x00000001
local WAIT_OBJECT_0 = 0
local WAIT_TIMEOUT = 0x00000102
local WAIT_FAILED = 0xFFFFFFFF
local PROCESS_CLEANUP_INTERVAL = 1

local instances = mod:persistent_table("instances")

if not pcall(ffi.typeof, "SimpleAudio_WIN32_FIND_DATAW") then
	ffi.cdef([[
		typedef void* SimpleAudio_HANDLE;
		typedef unsigned long SimpleAudio_DWORD;
		typedef int SimpleAudio_BOOL;
		typedef unsigned short SimpleAudio_WCHAR;

		typedef struct {
			SimpleAudio_DWORD dwLowDateTime;
			SimpleAudio_DWORD dwHighDateTime;
		} SimpleAudio_FILETIME;

		typedef struct {
			SimpleAudio_DWORD dwFileAttributes;
			SimpleAudio_FILETIME ftCreationTime;
			SimpleAudio_FILETIME ftLastAccessTime;
			SimpleAudio_FILETIME ftLastWriteTime;
			SimpleAudio_DWORD nFileSizeHigh;
			SimpleAudio_DWORD nFileSizeLow;
			SimpleAudio_DWORD dwReserved0;
			SimpleAudio_DWORD dwReserved1;
			SimpleAudio_WCHAR cFileName[260];
			SimpleAudio_WCHAR cAlternateFileName[14];
		} SimpleAudio_WIN32_FIND_DATAW;

		SimpleAudio_HANDLE FindFirstFileW(const SimpleAudio_WCHAR* lpFileName, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL FindNextFileW(SimpleAudio_HANDLE hFindFile, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL FindClose(SimpleAudio_HANDLE hFindFile);
		SimpleAudio_DWORD GetLastError(void);
		int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, SimpleAudio_WCHAR* lpWideCharStr, int cchWideChar);
		int WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const SimpleAudio_WCHAR* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, SimpleAudio_BOOL* lpUsedDefaultChar);
	]])
end

if not pcall(ffi.typeof, "SimpleAudio_PROCESS_INFORMATION") then
	ffi.cdef([[
		typedef unsigned char SimpleAudio_BYTE;
		typedef unsigned short SimpleAudio_WORD;

		typedef struct {
			SimpleAudio_DWORD cb;
			SimpleAudio_WCHAR* lpReserved;
			SimpleAudio_WCHAR* lpDesktop;
			SimpleAudio_WCHAR* lpTitle;
			SimpleAudio_DWORD dwX;
			SimpleAudio_DWORD dwY;
			SimpleAudio_DWORD dwXSize;
			SimpleAudio_DWORD dwYSize;
			SimpleAudio_DWORD dwXCountChars;
			SimpleAudio_DWORD dwYCountChars;
			SimpleAudio_DWORD dwFillAttribute;
			SimpleAudio_DWORD dwFlags;
			SimpleAudio_WORD wShowWindow;
			SimpleAudio_WORD cbReserved2;
			SimpleAudio_BYTE* lpReserved2;
			SimpleAudio_HANDLE hStdInput;
			SimpleAudio_HANDLE hStdOutput;
			SimpleAudio_HANDLE hStdError;
		} SimpleAudio_STARTUPINFOW;

		typedef struct {
			SimpleAudio_HANDLE hProcess;
			SimpleAudio_HANDLE hThread;
			SimpleAudio_DWORD dwProcessId;
			SimpleAudio_DWORD dwThreadId;
		} SimpleAudio_PROCESS_INFORMATION;

		SimpleAudio_BOOL CloseHandle(SimpleAudio_HANDLE hObject);
		SimpleAudio_BOOL CreateProcessW(const SimpleAudio_WCHAR* lpApplicationName, SimpleAudio_WCHAR* lpCommandLine, void* lpProcessAttributes, void* lpThreadAttributes, SimpleAudio_BOOL bInheritHandles, SimpleAudio_DWORD dwCreationFlags, void* lpEnvironment, const SimpleAudio_WCHAR* lpCurrentDirectory, SimpleAudio_STARTUPINFOW* lpStartupInfo, SimpleAudio_PROCESS_INFORMATION* lpProcessInformation);
		SimpleAudio_BOOL TerminateProcess(SimpleAudio_HANDLE hProcess, unsigned int uExitCode);
		SimpleAudio_DWORD WaitForSingleObject(SimpleAudio_HANDLE hHandle, SimpleAudio_DWORD dwMilliseconds);
	]])
end

if instances.kernel32 == nil then
	instances.kernel32 = ffi.load("kernel32")
end

instances.audio = nil
instances.error_buffer = nil
instances.processes = instances.processes or {}
instances.process_id = instances.process_id or 0
instances.cleanup_delta = instances.cleanup_delta or 0

local INVALID_HANDLE_VALUE = ffi.cast("SimpleAudio_HANDLE", -1)

local function windows_path(path)
	return path:gsub("/", "\\")
end

local function last_windows_error()
	return tonumber(instances.kernel32.GetLastError())
end

local function utf8_to_wide(text)
	local length = instances.kernel32.MultiByteToWideChar(CP_UTF8, 0, text, -1, nil, 0)

	if length == 0 then
		error(string.format("Failed to convert path to UTF-16: Windows error %d", last_windows_error()))
	end

	local buffer = ffi.new("SimpleAudio_WCHAR[?]", length)
	local result = instances.kernel32.MultiByteToWideChar(CP_UTF8, 0, text, -1, buffer, length)

	if result == 0 then
		error(string.format("Failed to convert path to UTF-16: Windows error %d", last_windows_error()))
	end

	return buffer
end

local function wide_to_utf8(text)
	local length = instances.kernel32.WideCharToMultiByte(CP_UTF8, 0, text, -1, nil, 0, nil, nil)

	if length == 0 then
		error(string.format("Failed to convert file name to UTF-8: Windows error %d", last_windows_error()))
	end

	local buffer = ffi.new("char[?]", length)
	local result = instances.kernel32.WideCharToMultiByte(CP_UTF8, 0, text, -1, buffer, length, nil, nil)

	if result == 0 then
		error(string.format("Failed to convert file name to UTF-8: Windows error %d", last_windows_error()))
	end

	return ffi.string(buffer)
end

local function quote_command_argument(argument)
	local result = '"'
	local backslashes = 0

	for i = 1, #argument do
		local char = argument:sub(i, i)

		if char == "\\" then
			backslashes = backslashes + 1
		elseif char == '"' then
			result = result .. string.rep("\\", backslashes * 2 + 1) .. char
			backslashes = 0
		else
			result = result .. string.rep("\\", backslashes) .. char
			backslashes = 0
		end
	end

	return result .. string.rep("\\", backslashes * 2) .. '"'
end

local function command_line(executable_path, arguments)
	local parts = {
		quote_command_argument(windows_path(executable_path)),
	}

	for i = 1, #arguments do
		parts[#parts + 1] = quote_command_argument(arguments[i])
	end

	return table.concat(parts, " ")
end

local function close_process_handle(id, process)
	if instances.kernel32.CloseHandle(process.handle) == 0 then
		mod:error(string.format("Failed to close audio process handle for %s: Windows error %d", process.path, last_windows_error()))
	end

	instances.processes[id] = nil
end

local function has_file_attribute(attributes, attribute)
	return math.floor(attributes / attribute) % 2 == 1
end

platform.find_files = function(search_pattern, file_path_prefix)
	local find_data = ffi.new("SimpleAudio_WIN32_FIND_DATAW[1]")
	local handle = instances.kernel32.FindFirstFileW(utf8_to_wide(windows_path(search_pattern)), find_data)

	if handle == INVALID_HANDLE_VALUE then
		local last_error = last_windows_error()

		if last_error == ERROR_FILE_NOT_FOUND or last_error == ERROR_PATH_NOT_FOUND then
			return nil
		end

		error(string.format("Failed to glob audio files for %s: Windows error %d", search_pattern, last_error))
	end

	local files = {}
	local last_error

	while true do
		local attributes = tonumber(find_data[0].dwFileAttributes)

		if not has_file_attribute(attributes, FILE_ATTRIBUTE_DIRECTORY) then
			files[#files + 1] = file_path_prefix .. wide_to_utf8(find_data[0].cFileName)
		end

		if instances.kernel32.FindNextFileW(handle, find_data) == 0 then
			last_error = last_windows_error()
			break
		end
	end

	if instances.kernel32.FindClose(handle) == 0 then
		error(string.format("Failed to close audio glob handle: Windows error %d", last_windows_error()))
	end

	if last_error ~= ERROR_NO_MORE_FILES then
		error(string.format("Failed to glob audio files for %s: Windows error %d", search_pattern, last_error))
	end

	table.sort(files)

	return files
end

platform.start_process = function(executable_path, arguments, audio_path)
	local startup_info = ffi.new("SimpleAudio_STARTUPINFOW[1]")
	local process_info = ffi.new("SimpleAudio_PROCESS_INFORMATION[1]")
	local application_name = utf8_to_wide(windows_path(executable_path))
	local command_buffer = utf8_to_wide(command_line(executable_path, arguments))

	startup_info[0].cb = ffi.sizeof("SimpleAudio_STARTUPINFOW")
	startup_info[0].dwFlags = STARTF_USESHOWWINDOW
	startup_info[0].wShowWindow = 0

	if instances.kernel32.CreateProcessW(
		application_name,
		command_buffer,
		nil,
		nil,
		0,
		CREATE_NO_WINDOW,
		nil,
		nil,
		startup_info,
		process_info
	) == 0 then
		return false, string.format("Windows error %d", last_windows_error())
	end

	instances.process_id = instances.process_id + 1
	instances.processes[instances.process_id] = {
		handle = process_info[0].hProcess,
		path = audio_path,
	}

	if instances.kernel32.CloseHandle(process_info[0].hThread) == 0 then
		mod:error(string.format("Failed to close audio process thread handle for %s: Windows error %d", audio_path, last_windows_error()))
	end

	return true
end

platform.cleanup_finished_processes = function()
	local finished_processes = {}

	for id, process in pairs(instances.processes) do
		local wait_result = tonumber(instances.kernel32.WaitForSingleObject(process.handle, 0))
		local should_close = wait_result == WAIT_OBJECT_0

		if wait_result == WAIT_TIMEOUT then
			-- Still playing.
		elseif wait_result == WAIT_FAILED then
			mod:error(string.format("Failed to query audio process for %s: Windows error %d", process.path, last_windows_error()))
			should_close = true
		elseif not should_close then
			mod:error(string.format("Unexpected audio process wait result for %s: %d", process.path, wait_result))
			should_close = true
		end

		if should_close then
			finished_processes[#finished_processes + 1] = {
				id = id,
				process = process,
			}
		end
	end

	for i = 1, #finished_processes do
		local item = finished_processes[i]

		close_process_handle(item.id, item.process)
	end
end

platform.terminate_active_processes = function()
	platform.cleanup_finished_processes()

	local active_processes = {}

	for id, process in pairs(instances.processes) do
		active_processes[#active_processes + 1] = {
			id = id,
			process = process,
		}
	end

	for i = 1, #active_processes do
		local item = active_processes[i]
		local id = item.id
		local process = item.process

		if instances.kernel32.TerminateProcess(process.handle, 1) == 0 then
			mod:error(string.format("Failed to terminate audio process for %s: Windows error %d", process.path, last_windows_error()))
		end

		close_process_handle(id, process)
	end
end

platform.update = function(dt)
	instances.cleanup_delta = instances.cleanup_delta + dt

	if instances.cleanup_delta < PROCESS_CLEANUP_INTERVAL then
		return
	end

	instances.cleanup_delta = 0
	platform.cleanup_finished_processes()
end

return platform
