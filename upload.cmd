@ECHO OFF
REM *******************************************************************************
REM Copyright (C) 2016 Black Duck Software, Inc.
REM http://www.blackducksoftware.com/

REM Licensed to the Apache Software Foundation (ASF) under one
REM or more contributor license agreements. See the NOTICE file
REM distributed with this work for additional information
REM regarding copyright ownership. The ASF licenses this file
REM to you under the Apache License, Version 2.0 (the
REM "License"); you may not use this file except in compliance
REM with the License. You may obtain a copy of the License at

REM http://www.apache.org/licenses/LICENSE-2.0

REM Unless required by applicable law or agreed to in writing,
REM software distributed under the License is distributed on an
REM "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
REM KIND, either express or implied. See the License for the
REM specific language governing permissions and limitations
REM under the License.
REM *******************************************************************************/
ECHO hub-tfs upload
ECHO.
ECHO This script will acquire and install some dependant node modules. Each package 
ECHO is licensed to you by its owner. Black Duck Software is not responsible for, nor does it 
ECHO grant any licenses to, third-party packages. Some packages may include 
ECHO dependencies which are governed by additional licenses. Follow the package 
ECHO source URL (https://github.com/blackducksoftware/hub-tfs) to determine 
ECHO any dependencies.
ECHO.
SET /p YN="Continue [Y/n]? "
IF /I '%YN%'=='n' EXIT /B 1
ECHO.

CALL npm --version 1>NUL 2>NUL
IF NOT %ERRORLEVEL%==0 GOTO INSTALLFAILED

CALL tfx version 1>NUL 2>NUL
IF NOT %ERRORLEVEL%==0 GOTO TFXINSTALL

:NPMINSTALL
ECHO Installing dependencies...
CALL npm install --only=prod
IF NOT %ERRORLEVEL%==0 GOTO INSTALLFAILED

:EXEC
CALL node bin/tfxupload.js
IF NOT %ERRORLEVEL%==0 GOTO UPLOADFAILED
EXIT /B 0

:TFXINSTALL
ECHO Installing tfx-cli...
CALL npm install -g tfx-cli
IF NOT %ERRORLEVEL%==0 GOTO INSTALLFAILED
ECHO Log in to the VSTS/TFS collection you wish to deploy the tasks.
CALL tfx login --authType basic
IF NOT %ERRORLEVEL%==0 GOTO LOGINFAILED
GOTO NPMINSTALL

:UPLOADFAILED
ECHO Failed to upload! Ensure Node.js is installed and in your path and you are logged into a VSTS/TFS collection where you have build administration privileges.
EXIT /B %ERRORLEVEL%

:INSTALLFAILED
ECHO Failed to install npm packages. Ensure Node.js is installed and node and npm are in your path.
EXIT /B %ERRORLEVEL%

:LOGINFAILED
ECHO Login failed. Type "tfx login" to log in and then re-run this script.
EXIT /B %ERRORLEVEL%
