@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

CALL node ./bin/tick-task-patch-version.js
IF NOT %ERRORLEVEL%==0 GOTO FAILED

CALL node ./bin/tick-vsts-patch-version.js
IF NOT %ERRORLEVEL%==0 GOTO FAILED

CALL makevsix.cmd
IF NOT %ERRORLEVEL%==0 GOTO FAILED


:FAILED
ECHO Vsix creation failed
pause
EXIT /B 1