$source = "D:\projects_shit\ais_taxi\frontend\lib"
$dest = "D:\projects_shit\aisCopy\frontend\lib"
Get-ChildItem -Path $source -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring($source.Length + 1)
    $destPath = Join-Path -Path $dest -ChildPath $relativePath
    if ($_.PSIsContainer) {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    } else {
        New-Item -ItemType File -Path $destPath -Force | Out-Null
    }
}
