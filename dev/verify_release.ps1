param([string]$Executable = 'build/Hyperscale Datacenter Tycoon.exe')
$ErrorActionPreference = 'Stop'
$releaseExe = (Resolve-Path -LiteralPath $Executable).Path
$workspacePath = (Get-Location).Path
$suites = @('test_simulation','test_progression','test_economy','test_operations','test_civic','test_geography','test_research','test_workforce','test_scenarios','test_balance','test_release','test_clients','test_frontdoor','test_tutorial','test_interface','test_visual_review','test_presentation','fullscreen_probe','packaged_journey')
$nativeSuites = @('test_frontdoor','test_tutorial','test_interface','test_visual_review','test_presentation','fullscreen_probe','packaged_journey')
$results = @()
foreach ($suite in $suites) {
    $scriptPath = Join-Path $workspacePath "tests/$suite.gd"
    $logPath = Join-Path $workspacePath "build/final12-$suite.log"
    $arguments = @('--log-file',$logPath,'--script',$scriptPath)
    if ($suite -notin $nativeSuites) { $arguments = @('--headless','--audio-driver','Dummy') + $arguments }
    $arguments += @('--','--qa')
    if ($suite -eq 'packaged_journey') { $arguments += '--front-menu' }
    & $releaseExe @arguments | Out-Null
    $resultCode = $LASTEXITCODE
    $logText = Get-Content -LiteralPath $logPath -Raw
    $match = [regex]::Match($logText,'(\d+) checks, (\d+) failures')
    $passed = $resultCode -eq 0 -and $match.Success -and $match.Groups[2].Value -eq '0' -and $logText -notmatch '(?m)^(SCRIPT ERROR|ERROR|FAIL:)'
    $row = [ordered]@{suite=$suite;passed=$passed;exitCode=$resultCode;checks=if($match.Success){[int]$match.Groups[1].Value}else{0};mode=if($suite -in $nativeSuites){'native Windows'}else{'headless'};log=$logPath;shutdownWarning=$logText.Contains('ObjectDB instances leaked')}
    $results += $row
    Write-Output "$suite : $($row.checks) checks; passed=$passed"
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'build/final12-tests.json' -Encoding utf8
    if (-not $passed) { throw "Release suite failed: $suite. Inspect $logPath" }
}
