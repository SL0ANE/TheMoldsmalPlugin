@echo off
echo 正在打包文件...

REM 获取当前目录名称
for %%I in (.) do set DIRNAME=%%~nxI

REM 先打包成.zip文件（包含所有.lua文件和package.json）
powershell -Command "Compress-Archive -Path '**.lua','**.png','**.ase','package.json' -DestinationPath '%DIRNAME%.zip' -Force"

REM 删除旧的.aseprite-extension文件
if exist "%DIRNAME%.aseprite-extension" del "%DIRNAME%.aseprite-extension"

REM 重命名为.aseprite-extension
ren "%DIRNAME%.zip" "%DIRNAME%.aseprite-extension"

echo 打包完成: %DIRNAME%.aseprite-extension
