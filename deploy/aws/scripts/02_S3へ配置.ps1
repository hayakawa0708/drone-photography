[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BucketName,
    [string]$DistributionId,
    [switch]$Invalidate
)

$ErrorActionPreference = 'Stop'
if ($BucketName -notmatch '^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$') {
    throw 'Invalid S3 bucket name.'
}
if ($DistributionId -and $DistributionId -notmatch '^[A-Z0-9]+$') {
    throw 'Invalid CloudFront distribution ID.'
}
if ($Invalidate -and -not $DistributionId) {
    throw 'DistributionId is required when Invalidate is selected.'
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI was not found.'
}

& (Join-Path $PSScriptRoot '01_配布フォルダ作成.ps1')
if ($LASTEXITCODE) { throw 'Release verification failed.' }

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$siteRoot = Join-Path $projectRoot '.aws-build\drone-site'
Write-Host "Upload source: $siteRoot"
Write-Host "Upload destination: s3://$BucketName/"
Write-Host 'Existing remote files will not be deleted automatically.'
$confirmation = Read-Host 'Type DEPLOY to upload the public site files'
if ($confirmation -cne 'DEPLOY') {
    Write-Host 'Upload cancelled.'
    exit 0
}

& aws s3 sync $siteRoot "s3://$BucketName/" --sse AES256 --cache-control 'public,max-age=3600'
if ($LASTEXITCODE) { throw 'S3 upload failed.' }

& aws s3api head-object --bucket $BucketName --key 'drone_checker.html' | Out-Null
if ($LASTEXITCODE) { throw 'Uploaded HTML verification failed.' }

if ($Invalidate) {
    & aws cloudfront create-invalidation --distribution-id $DistributionId --paths '/*'
    if ($LASTEXITCODE) { throw 'CloudFront invalidation failed.' }
} else {
    Write-Host 'CloudFront invalidation was skipped. Allow up to the configured cache TTL for normal updates.'
}
Write-Host 'S3 upload completed.'
