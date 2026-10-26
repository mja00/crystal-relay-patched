param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [Parameter(Mandatory = $true)]
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
# Upstream scripts don't check dotnet exit codes; a failed publish must not ship a half-built zip.
$PSNativeCommandUseErrorActionPreference = $true

# The patches leave the tree dirty; upstream's build scripts refuse that without this opt-out.
$env:CR_SKIP_GIT_CHECK = '1'

Push-Location $SourceDir
try {
    if ($Tag -match '^v(\d+\.\d+\.\d+)-bugfix(\d+)$') {
        $assetName = "CrystalRelayBugFix-$Tag-win-x64.zip"
        & ./Build-Crystal-Relay-BugFix.ps1 -Version $Matches[1] -BugFix ([int]$Matches[2])
    }
    elseif ($Tag -match '^v(\d+\.\d+\.\d+)-beta(\d+)$') {
        $assetName = "CrystalRelayTwitchOsc-$Tag-win-x64.zip"
        & ./Build-Crystal-Relay-Beta.ps1 -Version $Matches[1] -Beta ([int]$Matches[2])
    }
    elseif ($Tag -match '^v(\d+\.\d+\.\d+)$') {
        $assetName = "CrystalRelayTwitchOsc-$Tag-win-x64.zip"
        & ./Build-Crystal-Relay-Release.ps1 -Version $Matches[1]
    }
    else {
        throw "Unrecognized upstream tag format '$Tag'."
    }
}
finally {
    Pop-Location
}

# The in-app updater only accepts an asset with this exact name.
$zip = Get-ChildItem -Path (Join-Path $SourceDir 'Releases') -Recurse -File -Filter $assetName | Select-Object -First 1
if ($null -eq $zip) {
    throw "Build did not produce the expected asset '$assetName'."
}

# Script stdout also carries dotnet build output, so the path goes through the Actions output file instead.
Write-Host "Package: $($zip.FullName)"
if ($env:GITHUB_OUTPUT) {
    "zip=$($zip.FullName)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
