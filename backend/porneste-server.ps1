# Pornește baza de date PostgreSQL (portabilă, de pe D:) și serverul Patronette.
# Rulează din PowerShell:  powershell -ExecutionPolicy Bypass -File backend\porneste-server.ps1
# Documentația API-ului: http://localhost:8000/docs

$ErrorActionPreference = 'Stop'
$pg = 'D:\Postgres\pgsql\bin'
$data = 'D:\Postgres\data'

if (-not (Test-Path $pg)) {
    Write-Host 'Nu găsesc PostgreSQL în D:\Postgres. E conectat discul D:?' -ForegroundColor Red
    exit 1
}

& "$pg\pg_isready.exe" -h localhost -p 5432 -q
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Pornesc PostgreSQL...'
    & "$pg\pg_ctl.exe" -D $data -l 'D:\Postgres\server.log' -o '-p 5432 -c listen_addresses=localhost' start -w | Out-Null
}

Set-Location $PSScriptRoot
if (-not (Test-Path '.venv')) {
    Write-Host 'Creez mediul Python...'
    python -m venv .venv
    .\.venv\Scripts\python.exe -m pip install -r requirements.txt
}

# 0.0.0.0: telefonul din aceeași rețea Wi-Fi poate ajunge la server.
Write-Host 'Serverul pornește pe http://localhost:8000 (Ctrl+C ca să-l oprești)'
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
