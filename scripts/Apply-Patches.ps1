param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    # owner/repo whose releases the patched app should update from.
    [Parameter(Mandatory = $true)]
    [string]$UpdateRepo
)

$ErrorActionPreference = 'Stop'
$patchDir = Join-Path $PSScriptRoot '..' 'patches'

foreach ($patch in Get-ChildItem -Path $patchDir -Filter '*.patch' | Sort-Object Name) {
    Write-Host "Applying $($patch.Name)"
    git -C $SourceDir apply --3way --whitespace=nowarn $patch.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "$($patch.Name) no longer applies cleanly. Upstream changed patched code; review and refresh the patch."
    }
}

# Repo slug is substituted rather than patched so the same patches work for any fork of this repo.
$updateServicePath = Join-Path $SourceDir 'VrcTwitchOscBridge/Services/ApplicationUpdateService.cs'
$upstreamReleases = 'repos/seluvia/crystal-relay-public/releases'
$updateServiceText = [System.IO.File]::ReadAllText($updateServicePath)
$occurrences = ([regex]::Matches($updateServiceText, [regex]::Escape($upstreamReleases))).Count
if ($occurrences -ne 1) {
    throw "Expected exactly one '$upstreamReleases' in ApplicationUpdateService.cs, found $occurrences."
}
[System.IO.File]::WriteAllText($updateServicePath, $updateServiceText.Replace($upstreamReleases, "repos/$UpdateRepo/releases"))

function Get-SourceMatches {
    param([string]$Pattern)

    Get-ChildItem -Path (Join-Path $SourceDir 'VrcTwitchOscBridge') -Recurse -File -Include '*.cs', '*.csproj', '*.xaml' |
        Select-String -Pattern $Pattern
}

# Guards catch upstream re-adding the behavior somewhere the patches don't touch.
$failures = @()

$heartbeatServiceRefs = @(Get-SourceMatches -Pattern 'LiveFeedbackHeartbeatService')
if ($heartbeatServiceRefs.Count -gt 0) {
    $failures += "LiveFeedbackHeartbeatService is referenced again:`n$($heartbeatServiceRefs -join "`n")"
}

$endpointRefs = @(Get-SourceMatches -Pattern 'LiveFeedbackHeartbeatEndpoint' |
    Where-Object { (Split-Path -Leaf $_.Path) -ne 'RuntimeConfig.cs' })
if ($endpointRefs.Count -gt 0) {
    $failures += "The heartbeat endpoint is consumed outside RuntimeConfig.cs:`n$($endpointRefs -join "`n")"
}

$devDispatchRefs = @(Get-SourceMatches -Pattern 'TryHandleDevChatCommandAsync\(')
if ($devDispatchRefs.Count -gt 1) {
    $failures += "The !screm dev command handler is called again:`n$($devDispatchRefs -join "`n")"
}

if ($failures.Count -gt 0) {
    throw "Patched source failed guards:`n$($failures -join "`n`n")"
}

Write-Host "Patches applied; updates will come from $UpdateRepo."
