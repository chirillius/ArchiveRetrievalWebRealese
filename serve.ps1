$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$distDir = Join-Path $scriptDir 'dist'

if (-not (Test-Path $distDir)) {
    Write-Host "Папка dist не найдена рядом со скриптом." -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

function Get-FreePort {
    param(
        [int]$StartPort = 4173,
        [int]$EndPort = 4190
    )

    for ($port = $StartPort; $port -le $EndPort; $port++) {
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
            $listener.Start()
            $listener.Stop()
            return $port
        } catch {
        }
    }

    throw "Не удалось найти свободный порт в диапазоне $StartPort-$EndPort."
}

function Get-ContentType {
    param([string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.html' { 'text/html; charset=utf-8' }
        '.js'   { 'application/javascript; charset=utf-8' }
        '.mjs'  { 'application/javascript; charset=utf-8' }
        '.css'  { 'text/css; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        '.svg'  { 'image/svg+xml' }
        '.png'  { 'image/png' }
        '.jpg'  { 'image/jpeg' }
        '.jpeg' { 'image/jpeg' }
        '.gif'  { 'image/gif' }
        '.webp' { 'image/webp' }
        '.ico'  { 'image/x-icon' }
        '.woff' { 'font/woff' }
        '.woff2'{ 'font/woff2' }
        '.ttf'  { 'font/ttf' }
        '.map'  { 'application/json; charset=utf-8' }
        '.txt'  { 'text/plain; charset=utf-8' }
        default { 'application/octet-stream' }
    }
}

$port = Get-FreePort
$prefix = "http://localhost:$port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "ArchiveRetrieval запущен: $prefix" -ForegroundColor Green
Start-Process $prefix | Out-Null

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $requestPath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($requestPath)) {
                $requestPath = 'index.html'
            }

            $candidatePath = Join-Path $distDir $requestPath.Replace('/', '\')
            $fullDistPath = [System.IO.Path]::GetFullPath($distDir)

            if ((Test-Path $candidatePath) -and -not (Get-Item $candidatePath).PSIsContainer) {
                $filePath = [System.IO.Path]::GetFullPath($candidatePath)
            } else {
                $filePath = Join-Path $distDir 'index.html'
            }

            if (-not $filePath.StartsWith($fullDistPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $context.Response.StatusCode = 403
                $context.Response.Close()
                continue
            }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $context.Response.StatusCode = 200
            $context.Response.ContentType = Get-ContentType $filePath
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.OutputStream.Close()
        } catch {
            try {
                $message = [System.Text.Encoding]::UTF8.GetBytes("Internal server error")
                $context.Response.StatusCode = 500
                $context.Response.ContentType = 'text/plain; charset=utf-8'
                $context.Response.ContentLength64 = $message.Length
                $context.Response.OutputStream.Write($message, 0, $message.Length)
                $context.Response.OutputStream.Close()
            } catch {
            }
        }
    }
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
