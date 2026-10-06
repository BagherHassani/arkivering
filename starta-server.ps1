# ============================================================
#  Runriket - lokal offline-webbserver (kräver INGEN installation)
#  Använder Windows inbyggda .NET (HttpListener). Fungerar på
#  vanlig användare utan admin, så länge du binder till localhost.
#
#  STARTA:  Öppna PowerShell i den här mappen och kör:
#           powershell -ExecutionPolicy Bypass -File .\starta-server.ps1
#
#  Eller högerklicka på filen -> "Kör med PowerShell".
#  STOPPA:  Tryck Ctrl + C i fönstret, eller stäng det.
# ============================================================

$ErrorActionPreference = "Stop"

# Webbroten = mappen där detta skript ligger
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

$port = 8000
$prefix = "http://localhost:$port/"

# MIME-typer
$mime = @{
    ".html"="text/html; charset=utf-8"; ".htm"="text/html; charset=utf-8";
    ".css"="text/css; charset=utf-8";   ".js"="application/javascript; charset=utf-8";
    ".json"="application/json";          ".svg"="image/svg+xml";
    ".png"="image/png"; ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"; ".gif"="image/gif";
    ".webp"="image/webp"; ".ico"="image/x-icon";
    ".mp3"="audio/mpeg"; ".mp4"="video/mp4"; ".pdf"="application/pdf";
    ".woff"="font/woff"; ".woff2"="font/woff2"; ".ttf"="font/ttf"; ".eot"="application/vnd.ms-fontobject";
    ".txt"="text/plain; charset=utf-8"; ".xml"="application/xml"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    Write-Host "Kunde inte starta pa port $port. Provar port 8080..." -ForegroundColor Yellow
    $port = 8080; $prefix = "http://localhost:$port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    $listener.Start()
}

Write-Host ""
Write-Host "  Runriket koras nu lokalt!" -ForegroundColor Green
Write-Host "  Oppna i webblasaren:  $prefix" -ForegroundColor Cyan
Write-Host "  Webbrot: $root"
Write-Host "  Stoppa med Ctrl + C." -ForegroundColor DarkGray
Write-Host ""

# Oppna webblasaren automatiskt
try { Start-Process $prefix } catch {}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
    } catch { break }

    $req = $context.Request
    $res = $context.Response

    # Avkoda och rensa sokvagen
    $relPath = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
    if ($relPath -eq "/" -or $relPath -eq "") { $relPath = "/index.html" }
    if ($relPath.EndsWith("/")) { $relPath = $relPath + "index.html" }

    # Bygg filsokvag (byt / mot \ och ta bort inledande /)
    $safe = $relPath.TrimStart("/").Replace("/", "\")
    $filePath = Join-Path $root $safe

    # Om det ar en mapp -> index.html
    if ((Test-Path $filePath) -and (Get-Item $filePath).PSIsContainer) {
        $filePath = Join-Path $filePath "index.html"
    }

    if (Test-Path $filePath -PathType Leaf) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            if ($mime.ContainsKey($ext)) { $res.ContentType = $mime[$ext] }
            else { $res.ContentType = "application/octet-stream" }
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } catch {
            $res.StatusCode = 500
        }
    } else {
        $res.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes("404 - hittades inte: $relPath")
        $res.OutputStream.Write($msg, 0, $msg.Length)
    }
    $res.OutputStream.Close()
}

$listener.Stop()
