param(
  [Parameter(Mandatory = $true)]
  [string]$Repo,

  [Parameter(Mandatory = $true)]
  [string]$TeamId,

  [Parameter(Mandatory = $true)]
  [string]$CertP12Path,

  [Parameter(Mandatory = $true)]
  [string]$CertPassword,

  [Parameter(Mandatory = $true)]
  [string]$AppProfilePath,

  [Parameter(Mandatory = $true)]
  [string]$ShareProfilePath,

  [string]$AppBundleId = "ai.openclaw.ios",
  [string]$ShareBundleId = "ai.openclaw.ios.share"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI (gh) is required."
}

foreach ($path in @($CertP12Path, $AppProfilePath, $ShareProfilePath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "File not found: $path"
  }
}

function To-Base64([string]$Path) {
  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
  return [Convert]::ToBase64String($bytes)
}

$certB64 = To-Base64 $CertP12Path
$appProfB64 = To-Base64 $AppProfilePath
$shareProfB64 = To-Base64 $ShareProfilePath

$secretMap = @{
  IOS_TEAM_ID = $TeamId
  IOS_CERT_P12_BASE64 = $certB64
  IOS_CERT_PASSWORD = $CertPassword
  IOS_PROFILE_APP_BASE64 = $appProfB64
  IOS_PROFILE_SHARE_BASE64 = $shareProfB64
  IOS_APP_BUNDLE_ID = $AppBundleId
  IOS_SHARE_BUNDLE_ID = $ShareBundleId
}

foreach ($entry in $secretMap.GetEnumerator()) {
  $name = $entry.Key
  $value = [string]$entry.Value
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Secret value empty: $name"
  }

  $tmp = New-TemporaryFile
  try {
    [System.IO.File]::WriteAllText($tmp.FullName, $value)
    gh secret set $name -R $Repo -f $tmp.FullName | Out-Null
    Write-Host "Set $name"
  } finally {
    Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Done. iOS signing secrets are configured for $Repo."
