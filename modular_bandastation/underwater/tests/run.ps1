param([string]$ByondBin = (Join-Path ${env:ProgramFiles(x86)} 'BYOND/bin'))
$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$projectPath = Join-Path $PSScriptRoot 'compile.test.dme'
$project = Get-Content -Raw -LiteralPath (Join-Path $repository 'tgstation.dme')
$project = $project.Replace('#define FILE_DIR .', ('#define FILE_DIR "' + $repository.Replace('\', '/') + '"'))
# A nested headless build cannot resolve the skin's own relative resources; the game code is unchanged.
$project = $project.Replace('#include "interface\skin.dmf"', '// Headless test build')
$project = [regex]::Replace($project, '(?m)^#include "([^"]+)"', {
	param($match)
	'#include "' + (Join-Path $repository $match.Groups[1].Value).Replace('\', '/') + '"'
})
$project = '#define FORCE_MAP "runtimestation_minimal"' + "`n" + $project
[System.IO.File]::WriteAllText($projectPath, $project)
$logName = 'underwater-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
Push-Location $repository
try {
	& (Join-Path $ByondBin 'dm.exe') -DCBT -DCIBUILDING -DFLOODWATER_TEST_ONLY $projectPath
	if($LASTEXITCODE -ne 0) { throw 'Water test compilation failed.' }
	& (Join-Path $ByondBin 'dd.exe') ([System.IO.Path]::ChangeExtension($projectPath, '.dmb')) -cd $repository -console -invisible -trusted -log (Join-Path $PSScriptRoot 'runtime.log') -params "log-directory=$logName"
	if(!(Test-Path -LiteralPath (Join-Path $repository "data/logs/$logName/clean_run.lk"))) {
		throw "Water tests failed; see data/logs/$logName and tests/runtime.log."
	}
	Write-Output 'Water tests passed.'
} finally {
	Pop-Location
}
