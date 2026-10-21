package gameinstance

import "fmt"

const pipePrefix = `\\.\pipe\darktide.lua_exec`

func ExecPipeName(pid uint32) string {
	return fmt.Sprintf("%s.exec.pid-%d", pipePrefix, pid)
}

func LogsPipeName(pid uint32) string {
	return fmt.Sprintf("%s.logs.pid-%d", pipePrefix, pid)
}
