<<<<<<< Updated upstream
@echo off
=======
﻿@echo off
chcp 65001 >nul
>>>>>>> Stashed changes
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\serve.ps1"
