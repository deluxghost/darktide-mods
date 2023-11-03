@REM @echo off
setlocal

set source=%~dp0.
set target=E:\SteamLibrary\steamapps\common\Warhammer 40,000 DARKTIDE\mods
set exclude=.git

forfiles /P "%source%" /C "cmd /c if @isdir==TRUE (if not @file==\"%exclude%\" (if not exist @file\.symignore mklink /d \"%target%\@file\" @path))"
