# Decode a base64 text file back into a keystore (.jks/.keystore)
$in  = "C:\path\to\your\keystore.base64.txt"
$out = "C:\path\to\your\keystore.decoded.jks"

# Read the base64 as a single string (handles huge files + keeps it clean)
$b64 = (Get-Content -Path $in -Raw).Trim()

# Convert base64 -> bytes
$bytes = [System.Convert]::FromBase64String($b64)

# Write bytes -> keystore file
[System.IO.File]::WriteAllBytes($out, $bytes)

Write-Host "Wrote decoded keystore to: $out"