@echo off
setlocal enabledelayedexpansion

:: 배치 파일 경로 설정
set "batchFilePath=%~dpnx0"

:: WMIC를 활용하여 배치 파일의 PID 추출
	for /f %%a in ('wmic os get LocalDateTime ^| findstr [0-9]') do set NOW=%%a
	wmic process where "Name='wmic.exe' and CreationDate > '%NOW%'" get ParentProcessId | findstr [0-9] > temp.hng
	set /p batchPID=<temp.hng
	del temp.hng
	
	
	:: 텍스트(상태 저장)파일 및 감시자 powershell 스크립트 경로 지정
	set "statusFile=status.txt"
	set "watcherFile=watcher.ps1"
	
	:: 비정상 종료 감지
	if exist "%statusFile%" (
	echo 배치 파일 종료가 감지되었습니다.
	echo 배치 파일 종료 전 설치 파일은 설치가 정상적으로 완료되었습니까?[Y/N]
	set /p exitbefins=입력: 
	set /p extbefnum=<%statusFile%
	if "!exitbefins!"=="y" (
	set /a extbefnum+=1
	echo !exitbefins!>"!StatusFile!"
	)
	echo !extbefnum!
	)
	if exist "%statusFile%" goto skipmakewatcher
	:: 감시자 powershell 파일 생성
	echo param( > watcher.ps1
	echo [string]$batchFilePath, >> watcher.ps1
	echo [int]$batchPid >> watcher.ps1
	echo ) >> watcher.ps1
	echo [console]::WindowWidth=30; >> watcher.ps1
	echo [console]::WindowHeight=30; >> watcher.ps1
	echo [console]::BufferWidth=[console]::WindowWidth >> watcher.ps1
	echo write-host "---------배치파일 감시자---------"  >> watcher.ps1
	echo write-host "배치파일 종료 감시중..."  >> watcher.ps1
	echo while($true) { >> watcher.ps1
	echo $statusFilePath = Join-Path $PSScriptRoot "status.txt" >> watcher.ps1
	echo if (-not(Test-Path $statusFilePath) -or ((Get-Content $statusFilePath) -eq "done")) {  >> watcher.ps1
	echo write-host "배치파일 작업 완료 감지. 종료합니다." >> watcher.ps1
	echo break >> watcher.ps1
	echo } >> watcher.ps1
	echo if (-not (Get-Process -Id $batchPid -ErrorAction SilentlyContinue)) {  >> watcher.ps1
	echo write-host "배치파일 종료 감지. 다시 실행합니다."  >> watcher.ps1
	echo $process = Start-Process "cmd.exe" "/c $batchFilePath" -PassThru >> watcher.ps1
	echo $batchPid = $process.Id    >> watcher.ps1
	echo write-host "재실행 되었습니다. 새로운 PID: " $batchPid  >> watcher.ps1
	echo } else {  >> watcher.ps1
	echo } >> watcher.ps1
	echo Start-Sleep -Seconds 1 >> watcher.ps1
	echo } >> watcher.ps1
	
	:: 감시자 powershell 파일 생성 후 실행과 함께 필요한 매개변수 전달
	start powershell -ExecutionPolicy Bypass -File watcher.ps1 -WindowStyle hidden -batchFilePath "!batchFilePath!" -batchPid !batchPID!
	
	echo 0 > "%statusFile%"
	
	echo 감시자 powershell 생성 완료.
	pause
	:skipmakewatcher
	set /a counter=0
	:: 순차적으로 파일 설치
for /f %%i in ('dir /b *.exe') do (
	set execute_prog=y
    set /a counter+=1
    if !counter! lss !extbefnum! set execute_prog=n
	if "!execute_prog!"=="y" (
	echo !counter!>"!StatusFile!"
	echo !counter! 번 파일 실행시작.
    echo 설치 프로그램 실행: %%i
    start /wait %%i
	)
)

	echo done>"%statusFile%"
	echo 설치완료.
	set lastStatus=done
	pause
:: 모든 작업 완료 시 watcher.ps1 및 status.txt 삭제
if "!lastStatus!"=="done" (
    if exist "%watcherFile%" (
        del "%watcherFile%"
    )
    if exist "%statusFile%" (
        del "%statusFile%"
    )
)
