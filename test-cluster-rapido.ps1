# ============================================================================
# SCRIPT DE PRUEBAS RÁPIDAS - MySQL InnoDB Cluster
# ============================================================================
# Ejecutar: .\test-cluster-rapido.ps1
# 
# Este script permite probar rápidamente:
# - Lectura/Escritura en cada nodo
# - Failover y recuperación
# - Replicación de datos
# ============================================================================

# Configurar codificación UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

function Show-Banner {
    Clear-Host
    Write-Host @"
    
    ╔═══════════════════════════════════════════════════════════════╗
    ║       MySQL InnoDB Cluster - Pruebas de Replicación           ║
    ║                     Modo: Multi-Primary                        ║
    ╚═══════════════════════════════════════════════════════════════╝
    
"@ -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "  │                    MENÚ DE PRUEBAS                      │" -ForegroundColor White
    Write-Host "  ├─────────────────────────────────────────────────────────┤" -ForegroundColor White
    Write-Host "  │  1. Ver estado del cluster                              │" -ForegroundColor White
    Write-Host "  │  2. Probar LECTURA en los 3 nodos                       │" -ForegroundColor White
    Write-Host "  │  3. Probar ESCRITURA en los 3 nodos                     │" -ForegroundColor White
    Write-Host "  │  4. Apagar un nodo (mysql1)                             │" -ForegroundColor White
    Write-Host "  │  5. Apagar un nodo (mysql2)                             │" -ForegroundColor White
    Write-Host "  │  6. Apagar un nodo (mysql3)                             │" -ForegroundColor White
    Write-Host "  │  7. Encender todos los nodos                            │" -ForegroundColor White
    Write-Host "  │  8. Insertar empleado de prueba (seleccionar nodo)      │" -ForegroundColor White
    Write-Host "  │  9. Ver empleados de prueba en todos los nodos          │" -ForegroundColor White
    Write-Host "  │ 10. Limpiar empleados de prueba                         │" -ForegroundColor White
    Write-Host "  │ 11. Ejecutar demo automática completa                   │" -ForegroundColor White
    Write-Host "  │  0. Salir                                               │" -ForegroundColor White
    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor White
    Write-Host ""
}

function Test-NodeAvailable($node) {
    $result = docker exec $node mysqladmin ping -uroot -p1234 2>$null
    return $result -match "alive"
}

function Get-NodeStatus {
    Write-Host "`n  📊 Estado de los nodos:" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
    
    foreach ($node in @("mysql1", "mysql2", "mysql3")) {
        $containerStatus = docker inspect -f '{{.State.Status}}' $node 2>$null
        if ($containerStatus -eq "running") {
            if (Test-NodeAvailable $node) {
                Write-Host "  ✅ $node : ONLINE (R/W)" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  $node : Iniciando..." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ❌ $node : OFFLINE" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # Intentar obtener estado del cluster
    $availableNode = $null
    foreach ($node in @("mysql1", "mysql2", "mysql3")) {
        if (Test-NodeAvailable $node) {
            $availableNode = $node
            break
        }
    }
    
    if ($availableNode) {
        Write-Host "  📋 Estado del Cluster (desde $availableNode):" -ForegroundColor Yellow
        Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
        $status = docker exec $availableNode mysqlsh root:1234@localhost:3306 --js -e "var s=dba.getCluster('myCluster').status(); print('Cluster: ' + s.clusterName); print('Estado: ' + s.defaultReplicaSet.status); print('Modo: ' + s.defaultReplicaSet.topologyMode);" 2>$null
        Write-Host "  $status" -ForegroundColor Cyan
    }
}

function Test-ReadAllNodes {
    Write-Host "`n  📖 Probando LECTURA en los 3 nodos:" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
    
    foreach ($node in @("mysql1", "mysql2", "mysql3")) {
        Write-Host "`n  [$node] " -NoNewline -ForegroundColor Cyan
        if (Test-NodeAvailable $node) {
            $result = docker exec $node mysql -uroot -p1234 -N -e "SELECT CONCAT('Empleados: ', COUNT(*), ' | De prueba: ', (SELECT COUNT(*) FROM appdb.empleados WHERE codigo LIKE 'T%' OR codigo LIKE 'U%')) FROM appdb.empleados" 2>$null
            Write-Host "✅ $result" -ForegroundColor Green
        } else {
            Write-Host "❌ Nodo no disponible" -ForegroundColor Red
        }
    }
}

function Test-WriteAllNodes {
    Write-Host "`n  ✏️  Probando ESCRITURA en los 3 nodos:" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
    
    $timestamp = Get-Date -Format "mmss"
    $puestos = @("Desarrollador Senior", "Analista Financiero", "Contador General")
    $centros = @("CC-TEC01", "CC-ADM01", "CC-ADM01")
    $i = 0
    
    foreach ($node in @("mysql1", "mysql2", "mysql3")) {
        Write-Host "`n  [$node] " -NoNewline -ForegroundColor Cyan
        if (Test-NodeAvailable $node) {
            $codigo = "T$($node[-1])$timestamp"
            $dni = "9$($node[-1])$timestamp" + "$i$i"
            $puesto = $puestos[$i]
            $centro = $centros[$i]
            $resultado = docker exec $node mysql -uroot -p1234 -e "INSERT INTO appdb.empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES ('$codigo', 'Test $node', '$dni', '$puesto', '$centro', 'Sede Central'); SELECT 'OK: $codigo' as Resultado;" 2>$null
            if ($resultado) {
                Write-Host "✅ $resultado" -ForegroundColor Green
            }
            $i++
        } else {
            Write-Host "❌ Nodo no disponible" -ForegroundColor Red
        }
    }
    
    Write-Host "`n  🔄 Verificando replicación..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    
    $availableNode = $null
    foreach ($node in @("mysql1", "mysql2", "mysql3")) {
        if (Test-NodeAvailable $node) {
            $availableNode = $node
            break
        }
    }
    
    if ($availableNode) {
        $count = docker exec $availableNode mysql -uroot -p1234 -N -e "SELECT COUNT(*) FROM appdb.empleados WHERE codigo LIKE 'T%'" 2>$null
        Write-Host "  ✅ Total empleados de prueba replicados: $count" -ForegroundColor Green
    }
}

function Stop-Node($node) {
    Write-Host "`n  🔴 Apagando $node..." -ForegroundColor Red
    docker stop $node | Out-Null
    Write-Host "  ✅ $node detenido" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    Get-NodeStatus
}

function Start-AllNodes {
    Write-Host "`n  🟢 Encendiendo todos los nodos..." -ForegroundColor Green
    docker start mysql1 mysql2 mysql3 | Out-Null
    Write-Host "  ⏳ Esperando que los nodos estén listos (20 segundos)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 20
    Get-NodeStatus
}

function Insert-TestData {
    Write-Host "`n  Selecciona el nodo para insertar:"
    Write-Host "  1. mysql1"
    Write-Host "  2. mysql2"
    Write-Host "  3. mysql3"
    $opcion = Read-Host "  Opción"
    
    $node = switch ($opcion) {
        "1" { "mysql1" }
        "2" { "mysql2" }
        "3" { "mysql3" }
        default { return }
    }
    
    if (-not (Test-NodeAvailable $node)) {
        Write-Host "  ❌ $node no está disponible" -ForegroundColor Red
        return
    }
    
    $nombre = Read-Host "  Nombre del empleado"
    $timestamp = Get-Date -Format "mmss"
    $random = Get-Random -Minimum 10 -Maximum 99
    $codigo = "U$($node[-1])$timestamp"
    $dni = "8$($node[-1])$timestamp$random"
    
    # Puestos válidos disponibles
    Write-Host "`n  Puestos disponibles:"
    Write-Host "  1. Desarrollador Senior"
    Write-Host "  2. Desarrollador Junior"
    Write-Host "  3. Analista Financiero"
    Write-Host "  4. Contador General"
    Write-Host "  5. Gerente de TI"
    $puestoOp = Read-Host "  Selecciona puesto (1-5)"
    
    $puesto = switch ($puestoOp) {
        "1" { "Desarrollador Senior" }
        "2" { "Desarrollador Junior" }
        "3" { "Analista Financiero" }
        "4" { "Contador General" }
        "5" { "Gerente de TI" }
        default { "Desarrollador Junior" }
    }
    
    $centro = if ($puesto -match "Desarrollador|Gerente") { "CC-TEC01" } else { "CC-ADM01" }
    
    docker exec $node mysql -uroot -p1234 -e "INSERT INTO appdb.empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES ('$codigo', '$nombre', '$dni', '$puesto', '$centro', 'Sede Central'); SELECT 'Insertado exitosamente: $codigo' as Resultado;" 2>$null
    
    Write-Host "`n  🔄 Verificando replicación en todos los nodos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    
    foreach ($n in @("mysql1", "mysql2", "mysql3")) {
        Write-Host "  [$n] " -NoNewline -ForegroundColor Cyan
        if (Test-NodeAvailable $n) {
            $existe = docker exec $n mysql -uroot -p1234 -N -e "SELECT IF(COUNT(*)>0, '✅ Datos replicados', '❌ Sin replicar') FROM appdb.empleados WHERE codigo = '$codigo'" 2>$null
            Write-Host $existe -ForegroundColor Green
        } else {
            Write-Host "❌ Nodo no disponible" -ForegroundColor Red
        }
    }
}

function Show-TestData {
    Write-Host "`n  📋 Empleados de prueba en todos los nodos:" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────" -ForegroundColor Gray
    
    foreach ($node in @("mysql1", "mysql2", "mysql3")) {
        Write-Host "`n  === $node ===" -ForegroundColor Cyan
        if (Test-NodeAvailable $node) {
            docker exec $node mysql -uroot -p1234 -e "SELECT codigo as Codigo, nombre as Nombre, puesto_area as Puesto FROM appdb.empleados WHERE codigo LIKE 'T%' OR codigo LIKE 'U%' OR codigo LIKE 'DEMO%' ORDER BY codigo" 2>$null
        } else {
            Write-Host "  ❌ Nodo no disponible" -ForegroundColor Red
        }
    }
}

function Clear-TestData {
    Write-Host "`n  🗑️  Limpiando empleados de prueba..." -ForegroundColor Yellow
    
    $availableNode = $null
    foreach ($node in @("mysql1", "mysql2", "mysql3")) {
        if (Test-NodeAvailable $node) {
            $availableNode = $node
            break
        }
    }
    
    if ($availableNode) {
        docker exec $availableNode mysql -uroot -p1234 -e "DELETE FROM appdb.empleados WHERE codigo LIKE 'T%' OR codigo LIKE 'U%' OR codigo LIKE 'DEMO%'" 2>$null
        Write-Host "  ✅ Empleados de prueba eliminados (T*, U*, DEMO*)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ No hay nodos disponibles" -ForegroundColor Red
    }
}

function Run-AutoDemo {
    Write-Host "`n  🎬 Ejecutando demostración automática completa..." -ForegroundColor Magenta
    & "$PSScriptRoot\demo-cluster-presentacion.ps1" -Auto -Delay 2
}

# ============================================================================
# MAIN LOOP
# ============================================================================

do {
    Show-Banner
    Show-Menu
    $opcion = Read-Host "  Selecciona una opción"
    
    switch ($opcion) {
        "1" { Get-NodeStatus }
        "2" { Test-ReadAllNodes }
        "3" { Test-WriteAllNodes }
        "4" { Stop-Node "mysql1" }
        "5" { Stop-Node "mysql2" }
        "6" { Stop-Node "mysql3" }
        "7" { Start-AllNodes }
        "8" { Insert-TestData }
        "9" { Show-TestData }
        "10" { Clear-TestData }
        "11" { Run-AutoDemo }
        "0" { 
            Write-Host "`n  👋 ¡Hasta luego!" -ForegroundColor Cyan
            break 
        }
        default { Write-Host "  ⚠️  Opción no válida" -ForegroundColor Red }
    }
    
    if ($opcion -ne "0" -and $opcion -ne "11") {
        Write-Host "`n  Presiona ENTER para continuar..." -ForegroundColor Gray
        Read-Host
    }
    
} while ($opcion -ne "0")
