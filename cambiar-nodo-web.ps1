# ============================================================================
# SCRIPT PARA CAMBIAR EL NODO MySQL QUE USA LA WEB
# ============================================================================
# Este script permite cambiar dinámicamente a qué nodo MySQL se conecta
# la aplicación web, bypaseando el MySQL Router.
#
# Uso:
#   .\cambiar-nodo-web.ps1           # Menú interactivo
#   .\cambiar-nodo-web.ps1 -Nodo 1   # Cambiar directamente al nodo 1
#   .\cambiar-nodo-web.ps1 -Nodo 2   # Cambiar directamente al nodo 2
#   .\cambiar-nodo-web.ps1 -Nodo 3   # Cambiar directamente al nodo 3
#   .\cambiar-nodo-web.ps1 -Router   # Volver a usar MySQL Router (automático)
# ============================================================================

param(
    [int]$Nodo,
    [switch]$Router,
    [switch]$Status
)

# Configurar codificación UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ColorTitulo = "Cyan"
$ColorExito = "Green"
$ColorError = "Red"
$ColorInfo = "Yellow"

function Write-Banner {
    Write-Host @"

    ╔═══════════════════════════════════════════════════════════════╗
    ║         CAMBIO DE NODO MySQL PARA APLICACIÓN WEB              ║
    ╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor $ColorTitulo
}

function Get-CurrentConnection {
    Write-Host "  📡 Conexión actual de la web:" -ForegroundColor $ColorInfo
    
    # Verificar a qué está conectada la web actualmente
    $webContainer = docker inspect web 2>$null | ConvertFrom-Json
    if ($webContainer) {
        $dbHost = ($webContainer.Config.Env | Where-Object { $_ -match "^DB_HOST=" }) -replace "DB_HOST=", ""
        $dbPort = ($webContainer.Config.Env | Where-Object { $_ -match "^DB_PORT=" }) -replace "DB_PORT=", ""
        
        if (-not $dbHost) { $dbHost = "mysql-router" }
        if (-not $dbPort) { $dbPort = "6446" }
        
        Write-Host "     Host: " -NoNewline -ForegroundColor White
        Write-Host $dbHost -ForegroundColor Magenta
        Write-Host "     Puerto: " -NoNewline -ForegroundColor White
        Write-Host $dbPort -ForegroundColor Magenta
        
        # Verificar qué servidor está respondiendo realmente
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8091" -TimeoutSec 5 -UseBasicParsing 2>$null
            if ($response.Content -match 'Servidor Actual:.*?<span[^>]*>([^<]+)</span>') {
                $servidor = $matches[1].Trim()
                Write-Host "     Servidor MySQL: " -NoNewline -ForegroundColor White
                Write-Host $servidor -ForegroundColor Green
            }
        } catch {
            Write-Host "     ⚠️  No se pudo verificar el servidor actual" -ForegroundColor Yellow
        }
        
        return @{ Host = $dbHost; Port = $dbPort }
    }
    return $null
}

function Get-NodesStatus {
    Write-Host "`n  📊 Estado de los nodos MySQL:" -ForegroundColor $ColorInfo
    Write-Host "  ─────────────────────────────────" -ForegroundColor Gray
    
    $nodes = @()
    foreach ($i in 1..3) {
        $node = "mysql$i"
        $containerStatus = docker inspect -f '{{.State.Status}}' $node 2>$null
        $available = $false
        
        if ($containerStatus -eq "running") {
            $ping = docker exec $node mysqladmin ping -uroot -p1234 2>$null
            if ($ping -match "alive") {
                $available = $true
                Write-Host "     ✅ $node : ONLINE (disponible)" -ForegroundColor Green
            } else {
                Write-Host "     ⚠️  $node : Iniciando..." -ForegroundColor Yellow
            }
        } else {
            Write-Host "     ❌ $node : OFFLINE" -ForegroundColor Red
        }
        
        $nodes += @{ Name = $node; Number = $i; Available = $available }
    }
    
    return $nodes
}

function Set-WebNode($nodeNumber) {
    if ($nodeNumber -lt 1 -or $nodeNumber -gt 3) {
        Write-Host "  ❌ Número de nodo inválido. Debe ser 1, 2 o 3" -ForegroundColor $ColorError
        return $false
    }
    
    $nodeName = "mysql$nodeNumber"
    
    # Verificar si el nodo está disponible
    $containerStatus = docker inspect -f '{{.State.Status}}' $nodeName 2>$null
    if ($containerStatus -ne "running") {
        Write-Host "  ❌ El nodo $nodeName no está corriendo" -ForegroundColor $ColorError
        return $false
    }
    
    $ping = docker exec $nodeName mysqladmin ping -uroot -p1234 2>$null
    if ($ping -notmatch "alive") {
        Write-Host "  ❌ El nodo $nodeName no está respondiendo" -ForegroundColor $ColorError
        return $false
    }
    
    Write-Host "`n  🔄 Cambiando conexión web a $nodeName..." -ForegroundColor $ColorInfo
    
    # Detener el contenedor web actual
    Write-Host "     Deteniendo contenedor web..." -ForegroundColor Gray
    docker stop web 2>$null | Out-Null
    docker rm web 2>$null | Out-Null
    
    # Recrear el contenedor web con conexión directa al nodo
    Write-Host "     Creando nuevo contenedor web conectado a $nodeName..." -ForegroundColor Gray
    
    $result = docker run -d `
        --name web `
        --network docker_backend `
        -p 8091:80 `
        -e "DB_HOST=$nodeName" `
        -e "DB_PORT=3306" `
        -e "DB_USER=app" `
        -e "DB_PASSWORD=1234" `
        -e "DB_NAME=appdb" `
        --restart unless-stopped `
        docker-web 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 2
        Write-Host "`n  ✅ Web ahora conectada directamente a $nodeName" -ForegroundColor $ColorExito
        
        # Verificar la conexión
        Start-Sleep -Seconds 2
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8091" -TimeoutSec 10 -UseBasicParsing 2>$null
            if ($response.StatusCode -eq 200) {
                Write-Host "  ✅ Aplicación web respondiendo correctamente" -ForegroundColor $ColorExito
                if ($response.Content -match 'Servidor Actual:.*?<span[^>]*>([^<]+)</span>') {
                    Write-Host "  📍 Servidor actual: $($matches[1].Trim())" -ForegroundColor Magenta
                }
            }
        } catch {
            Write-Host "  ⚠️  Esperando que la web esté lista..." -ForegroundColor Yellow
        }
        
        return $true
    } else {
        Write-Host "  ❌ Error al crear el contenedor: $result" -ForegroundColor $ColorError
        return $false
    }
}

function Set-WebRouter {
    Write-Host "`n  🔄 Restaurando conexión via MySQL Router..." -ForegroundColor $ColorInfo
    
    # Detener el contenedor web actual
    Write-Host "     Deteniendo contenedor web..." -ForegroundColor Gray
    docker stop web 2>$null | Out-Null
    docker rm web 2>$null | Out-Null
    
    # Recrear el contenedor web con conexión al Router
    Write-Host "     Creando nuevo contenedor web conectado al Router..." -ForegroundColor Gray
    
    $result = docker run -d `
        --name web `
        --network docker_backend `
        -p 8091:80 `
        -e "DB_HOST=mysql-router" `
        -e "DB_PORT=6446" `
        -e "DB_USER=app" `
        -e "DB_PASSWORD=1234" `
        -e "DB_NAME=appdb" `
        --restart unless-stopped `
        docker-web 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep -Seconds 2
        Write-Host "`n  ✅ Web ahora conectada via MySQL Router (balanceo automático)" -ForegroundColor $ColorExito
        
        # Verificar la conexión
        Start-Sleep -Seconds 2
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8091" -TimeoutSec 10 -UseBasicParsing 2>$null
            if ($response.StatusCode -eq 200) {
                Write-Host "  ✅ Aplicación web respondiendo correctamente" -ForegroundColor $ColorExito
            }
        } catch {
            Write-Host "  ⚠️  Esperando que la web esté lista..." -ForegroundColor Yellow
        }
        
        return $true
    } else {
        Write-Host "  ❌ Error al crear el contenedor: $result" -ForegroundColor $ColorError
        return $false
    }
}

function Show-Menu {
    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "  │                  OPCIONES DISPONIBLES                   │" -ForegroundColor White
    Write-Host "  ├─────────────────────────────────────────────────────────┤" -ForegroundColor White
    Write-Host "  │  1. Conectar web a mysql1                               │" -ForegroundColor White
    Write-Host "  │  2. Conectar web a mysql2                               │" -ForegroundColor White
    Write-Host "  │  3. Conectar web a mysql3                               │" -ForegroundColor White
    Write-Host "  │  R. Restaurar conexión via Router (automático)          │" -ForegroundColor White
    Write-Host "  │  S. Ver estado actual                                   │" -ForegroundColor White
    Write-Host "  │  0. Salir                                               │" -ForegroundColor White
    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor White
}

# ============================================================================
# MAIN
# ============================================================================

Write-Banner

# Procesar parámetros de línea de comandos
if ($Status) {
    Get-CurrentConnection
    Get-NodesStatus
    exit
}

if ($Router) {
    Get-NodesStatus
    Set-WebRouter
    exit
}

if ($Nodo) {
    Get-NodesStatus
    Set-WebNode -nodeNumber $Nodo
    exit
}

# Modo interactivo
do {
    Get-CurrentConnection
    $nodes = Get-NodesStatus
    Write-Host ""
    Show-Menu
    Write-Host ""
    $opcion = Read-Host "  Selecciona una opción"
    
    switch ($opcion) {
        "1" { Set-WebNode -nodeNumber 1 }
        "2" { Set-WebNode -nodeNumber 2 }
        "3" { Set-WebNode -nodeNumber 3 }
        "R" { Set-WebRouter }
        "r" { Set-WebRouter }
        "S" { 
            Get-CurrentConnection
            Get-NodesStatus 
        }
        "s" { 
            Get-CurrentConnection
            Get-NodesStatus 
        }
        "0" { 
            Write-Host "`n  👋 ¡Hasta luego!" -ForegroundColor $ColorTitulo
            break 
        }
        default { Write-Host "  ⚠️  Opción no válida" -ForegroundColor $ColorError }
    }
    
    if ($opcion -ne "0") {
        Write-Host "`n  Presiona ENTER para continuar..." -ForegroundColor Gray
        Read-Host
        Clear-Host
        Write-Banner
    }
    
} while ($opcion -ne "0")
