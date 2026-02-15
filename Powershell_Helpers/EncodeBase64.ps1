# Encode a file to base64 and write it to a text file.
$in  = "C:\Users\zholl\AppData\Local\Xamarin\Mono for Android\Keystore\AniSprinkles\AniSprinkles.keystore"
$out = "C:\Users\zholl\Downloads\AniSprinkles.keystore.base64.txt"

# Read the keystore as raw bytes (important: do NOT treat it as text)
$bytes = [System.IO.File]::ReadAllBytes($in)

# Convert the bytes into a Base64 string
$b64 = [System.Convert]::ToBase64String($bytes)

# Write the Base64 string to disk with no trailing newline
Set-Content -Path $out -Value $b64 -NoNewline
Write-Host "Wrote base64 to: $out"