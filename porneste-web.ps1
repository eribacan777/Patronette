# Pornește aplicația Patronette în Chrome.
# Rulare: powershell -ExecutionPolicy Bypass -File porneste-web.ps1

# Pachetele Flutter stau într-un folder obișnuit, nu în AppData.
[Environment]::SetEnvironmentVariable('PUB_CACHE', 'C:\Users\use\.pub-cache', 'User')
$env:PUB_CACHE = 'C:\Users\use\.pub-cache'

Set-Location $PSScriptRoot
& 'C:\Users\use\flutter\bin\flutter.bat' pub get
# --no-web-resources-cdn: motorul de desenare vine cu aplicația,
# nu se mai descarcă de pe internet la fiecare pornire.
& 'C:\Users\use\flutter\bin\flutter.bat' run -d chrome --release --no-web-resources-cdn
