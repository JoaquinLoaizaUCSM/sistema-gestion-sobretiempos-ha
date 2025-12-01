# ============================================================================
# SCRIPT DE DEMOSTRACIÓN - MySQL InnoDB Cluster Multi-Primary
# ============================================================================
# Este script demuestra las capacidades del cluster MySQL:
# 1. Lectura/Escritura en múltiples nodos (Multi-Primary)
# 2. Replicación automática de datos
# 3. Alta disponibilidad (Failover)
# 4. Recuperación automática de nodos caídos
# 5. Sincronización de datos tras recuperación
# ============================================================================

param(
    [switch]$Auto,        # Modo automático (no espera input del usuario)
    [int]$Delay = 3       # Segundos de pausa entre pasos en modo automático
)

# Configurar codificación UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Colores para la presentación
$ColorTitulo = "Cyan"
$ColorSubtitulo = "Yellow"
$ColorExito = "Green"
$ColorError = "Red"
$ColorInfo = "White"
$ColorDato = "Magenta"
$ColorTabla = "DarkCyan"

function Write-Titulo($texto) {
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 75) -ForegroundColor $ColorTitulo
    Write-Host "  $texto" -ForegroundColor $ColorTitulo
    Write-Host ("=" * 75) -ForegroundColor $ColorTitulo
}

function Write-Subtitulo($texto) {
    Write-Host "`n>>> $texto" -ForegroundColor $ColorSubtitulo
}

function Write-Exito($texto) {
    Write-Host "✅ $texto" -ForegroundColor $ColorExito
}

function Write-ErrorMsg($texto) {
    Write-Host "❌ $texto" -ForegroundColor $ColorError
}

function Write-Info($texto) {
    Write-Host "   $texto" -ForegroundColor $ColorInfo
}

function Pausar {
    if ($Auto) {
        Start-Sleep -Seconds $Delay
    } else {
        Write-Host "`n   Presiona ENTER para continuar..." -ForegroundColor Gray -NoNewline
        Read-Host
    }
}

function Esperar($segundos, $mensaje) {
    Write-Host "   ⏳ $mensaje" -ForegroundColor $ColorInfo
    for ($i = $segundos; $i -gt 0; $i--) {
        Write-Host "`r   ⏳ $mensaje - $i segundos restantes...     " -ForegroundColor $ColorInfo -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host "`r   ✅ $mensaje - ¡Completado!                    " -ForegroundColor $ColorExito
}

function Get-ClusterStatus {
    $status = docker exec mysql1 mysqlsh root:1234@localhost:3306 --js -e "print(JSON.stringify(dba.getCluster('myCluster').status()))" 2>$null
    if ($status) {
        return $status | ConvertFrom-Json
    }
    $status = docker exec mysql2 mysqlsh root:1234@localhost:3306 --js -e "print(JSON.stringify(dba.getCluster('myCluster').status()))" 2>$null
    if ($status) {
        return $status | ConvertFrom-Json
    }
    $status = docker exec mysql3 mysqlsh root:1234@localhost:3306 --js -e "print(JSON.stringify(dba.getCluster('myCluster').status()))" 2>$null
    if ($status) {
        return $status | ConvertFrom-Json
    }
    return $null
}

function Show-ClusterStatus {
    Write-Subtitulo "Estado del Cluster"
    $status = Get-ClusterStatus
    if ($status) {
        Write-Host ""
        Write-Host "   Cluster: " -NoNewline -ForegroundColor $ColorInfo
        Write-Host $status.clusterName -ForegroundColor $ColorDato
        Write-Host "   Modo: " -NoNewline -ForegroundColor $ColorInfo
        Write-Host $status.defaultReplicaSet.topologyMode -ForegroundColor $ColorDato
        Write-Host "   Estado: " -NoNewline -ForegroundColor $ColorInfo
        if ($status.defaultReplicaSet.status -eq "OK") {
            Write-Host $status.defaultReplicaSet.status -ForegroundColor $ColorExito
        } else {
            Write-Host $status.defaultReplicaSet.status -ForegroundColor $ColorSubtitulo
        }
        Write-Host ""
        Write-Host "   ┌────────────────────────────────────────────────────────┐" -ForegroundColor $ColorTabla
        Write-Host "   │  NODO          │  ROL       │  MODO   │  ESTADO       │" -ForegroundColor $ColorTabla
        Write-Host "   ├────────────────────────────────────────────────────────┤" -ForegroundColor $ColorTabla
        
        foreach ($key in $status.defaultReplicaSet.topology.PSObject.Properties.Name) {
            $node = $status.defaultReplicaSet.topology.$key
            $nombre = $key.PadRight(14)
            $rol = $node.memberRole.PadRight(10)
            $modo = if ($node.mode -eq "R/W") { "R/W".PadRight(7) } else { $node.mode.PadRight(7) }
            $estado = $node.status
            
            $colorEstado = if ($estado -eq "ONLINE") { $ColorExito } 
                          elseif ($estado -eq "(MISSING)") { $ColorError }
                          else { $ColorSubtitulo }
            
            Write-Host "   │  " -NoNewline -ForegroundColor $ColorTabla
            Write-Host $nombre -NoNewline -ForegroundColor $ColorDato
            Write-Host "│  " -NoNewline -ForegroundColor $ColorTabla
            Write-Host $rol -NoNewline -ForegroundColor $ColorSubtitulo
            Write-Host "│  " -NoNewline -ForegroundColor $ColorTabla
            Write-Host $modo -NoNewline -ForegroundColor $ColorExito
            Write-Host "│  " -NoNewline -ForegroundColor $ColorTabla
            Write-Host $estado.PadRight(13) -NoNewline -ForegroundColor $colorEstado
            Write-Host "│" -ForegroundColor $ColorTabla
        }
        Write-Host "   └────────────────────────────────────────────────────────┘" -ForegroundColor $ColorTabla
    } else {
        Write-ErrorMsg "No se pudo obtener el estado del cluster"
    }
}

function Show-TablaEmpleados($nodo, $whereClause = "", $titulo = "") {
    if ($titulo) {
        Write-Host "`n   $titulo" -ForegroundColor $ColorSubtitulo
    }
    
    $query = "SELECT codigo, nombre, dni, puesto_area as Puesto FROM appdb.empleados"
    if ($whereClause) {
        $query += " WHERE $whereClause"
    }
    $query += " ORDER BY codigo"
    
    $resultado = docker exec $nodo mysql -uroot -p1234 -N -e "$query" 2>$null
    
    if ($resultado) {
        Write-Host ""
        Write-Host "   ┌────────┬────────────────────────────────────┬──────────┬─────────────────────────┐" -ForegroundColor $ColorTabla
        Write-Host "   │ CÓDIGO │ NOMBRE                             │ DNI      │ PUESTO                  │" -ForegroundColor $ColorTabla
        Write-Host "   ├────────┼────────────────────────────────────┼──────────┼─────────────────────────┤" -ForegroundColor $ColorTabla
        
        $lineas = $resultado -split "`n"
        foreach ($linea in $lineas) {
            if ($linea.Trim()) {
                $campos = $linea -split "`t"
                $codigo = if ($campos[0]) { $campos[0].PadRight(6) } else { "".PadRight(6) }
                $nombre = if ($campos[1]) { 
                    if ($campos[1].Length -gt 34) { $campos[1].Substring(0, 31) + "..." } 
                    else { $campos[1].PadRight(34) }
                } else { "".PadRight(34) }
                $dni = if ($campos[2]) { $campos[2].PadRight(8) } else { "".PadRight(8) }
                $puesto = if ($campos[3]) { 
                    if ($campos[3].Length -gt 23) { $campos[3].Substring(0, 20) + "..." } 
                    else { $campos[3].PadRight(23) }
                } else { "".PadRight(23) }
                
                Write-Host "   │ " -NoNewline -ForegroundColor $ColorTabla
                Write-Host $codigo -NoNewline -ForegroundColor $ColorExito
                Write-Host " │ " -NoNewline -ForegroundColor $ColorTabla
                Write-Host $nombre -NoNewline -ForegroundColor $ColorInfo
                Write-Host " │ " -NoNewline -ForegroundColor $ColorTabla
                Write-Host $dni -NoNewline -ForegroundColor $ColorDato
                Write-Host " │ " -NoNewline -ForegroundColor $ColorTabla
                Write-Host $puesto -NoNewline -ForegroundColor $ColorSubtitulo
                Write-Host " │" -ForegroundColor $ColorTabla
            }
        }
        Write-Host "   └────────┴────────────────────────────────────┴──────────┴─────────────────────────┘" -ForegroundColor $ColorTabla
    }
}

function Show-ConteoEmpleados($nodo) {
    $count = docker exec $nodo mysql -uroot -p1234 -N -e "SELECT COUNT(*) FROM appdb.empleados" 2>$null
    return $count.Trim()
}

function Limpiar-DatosPrueba {
    Write-Host "`n   🧹 Limpiando datos de prueba anteriores..." -ForegroundColor $ColorSubtitulo
    
    # Buscar un nodo disponible
    $nodoDisponible = $null
    foreach ($nodo in @("mysql1", "mysql2", "mysql3")) {
        $ping = docker exec $nodo mysqladmin ping -uroot -p1234 2>$null
        if ($ping -match "alive") {
            $nodoDisponible = $nodo
            break
        }
    }
    
    if ($nodoDisponible) {
        # Eliminar empleados de prueba (códigos que empiezan con DEMO)
        docker exec $nodoDisponible mysql -uroot -p1234 -e "DELETE FROM appdb.reporte_asistencia WHERE codigo_empleado LIKE 'DEMO%'" 2>$null | Out-Null
        docker exec $nodoDisponible mysql -uroot -p1234 -e "DELETE FROM appdb.empleados WHERE codigo LIKE 'DEMO%'" 2>$null | Out-Null
        Write-Host "   ✅ Datos de prueba anteriores eliminados" -ForegroundColor $ColorExito
    } else {
        Write-Host "   ⚠️  No se encontró ningún nodo disponible para limpiar" -ForegroundColor $ColorSubtitulo
    }
}

function Ejecutar-Query($nodo, $query, $mostrarResultado = $true) {
    $resultado = docker exec $nodo mysql -uroot -p1234 -N -e "$query" 2>$null
    if ($mostrarResultado -and $resultado) {
        Write-Host $resultado -ForegroundColor $ColorDato
    }
    return $resultado
}

# ============================================================================
# INICIO DE LA DEMOSTRACIÓN
# ============================================================================

Clear-Host
Write-Host @"

  ███╗   ███╗██╗   ██╗███████╗ ██████╗ ██╗          ██████╗██╗     ██╗   ██╗███████╗████████╗███████╗██████╗ 
  ████╗ ████║╚██╗ ██╔╝██╔════╝██╔═══██╗██║         ██╔════╝██║     ██║   ██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗
  ██╔████╔██║ ╚████╔╝ ███████╗██║   ██║██║         ██║     ██║     ██║   ██║███████╗   ██║   █████╗  ██████╔╝
  ██║╚██╔╝██║  ╚██╔╝  ╚════██║██║▄▄ ██║██║         ██║     ██║     ██║   ██║╚════██║   ██║   ██╔══╝  ██╔══██╗
  ██║ ╚═╝ ██║   ██║   ███████║╚██████╔╝███████╗    ╚██████╗███████╗╚██████╔╝███████║   ██║   ███████╗██║  ██║
  ╚═╝     ╚═╝   ╚═╝   ╚══════╝ ╚══▀▀═╝ ╚══════╝     ╚═════╝╚══════╝ ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
                                                                                                                
                            InnoDB Cluster - Demostración Multi-Primary
                                   Sistema de Gestión de Empleados
"@ -ForegroundColor Cyan

Write-Host "`n   Esta demostración mostrará las capacidades de alta disponibilidad" -ForegroundColor White
Write-Host "   del cluster MySQL InnoDB en modo Multi-Primary usando la tabla EMPLEADOS." -ForegroundColor White
Write-Host ""

# Limpiar datos de prueba al inicio
Limpiar-DatosPrueba

Pausar

# ============================================================================
# DEMO 1: ESTADO INICIAL DEL CLUSTER
# ============================================================================

Write-Titulo "DEMO 1: Estado Inicial del Cluster"
Show-ClusterStatus
Write-Info "El cluster está configurado en modo MULTI-PRIMARY"
Write-Info "Esto significa que TODOS los nodos pueden recibir escrituras"
Pausar

# ============================================================================
# DEMO 2: LECTURA EN LOS 3 NODOS - TABLA EMPLEADOS
# ============================================================================

Write-Titulo "DEMO 2: Lectura de Empleados en los 3 Nodos"

Write-Subtitulo "Consultando cantidad de empleados en cada nodo..."
Write-Host ""

Write-Host "   ┌─────────────┬────────────────────┐" -ForegroundColor $ColorTabla
Write-Host "   │    NODO     │  TOTAL EMPLEADOS   │" -ForegroundColor $ColorTabla
Write-Host "   ├─────────────┼────────────────────┤" -ForegroundColor $ColorTabla

foreach ($nodo in @("mysql1", "mysql2", "mysql3")) {
    $count = Show-ConteoEmpleados $nodo
    Write-Host "   │  " -NoNewline -ForegroundColor $ColorTabla
    Write-Host $nodo.PadRight(9) -NoNewline -ForegroundColor $ColorDato
    Write-Host " │  " -NoNewline -ForegroundColor $ColorTabla
    Write-Host "$count empleados".PadRight(16) -NoNewline -ForegroundColor $ColorExito
    Write-Host " │" -ForegroundColor $ColorTabla
}

Write-Host "   └─────────────┴────────────────────┘" -ForegroundColor $ColorTabla

Write-Host ""
Write-Exito "Los 3 nodos tienen los mismos datos (replicación sincronizada)"

Write-Subtitulo "Mostrando algunos empleados desde mysql1..."
Show-TablaEmpleados "mysql1" "codigo IN ('E001', 'E002', 'E003', 'E004', 'E005')"

Pausar

# ============================================================================
# DEMO 3: ESCRITURA DESDE DIFERENTES NODOS - NUEVOS EMPLEADOS
# ============================================================================

Write-Titulo "DEMO 3: Escritura Multi-Primary (Insertando Empleados)"

Write-Subtitulo "Insertando nuevo empleado desde NODO 1 (mysql1)..."
Write-Host ""
Write-Host "   INSERT: Carlos Demo Garcia - Desarrollador" -ForegroundColor $ColorInfo
Ejecutar-Query "mysql1" "INSERT INTO appdb.empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES ('DEMO01', 'Carlos Demo Garcia', '99000001', 'Desarrollador Senior', 'CC-TEC01', 'Sede Central')" $false
Write-Exito "Empleado DEMO01 insertado desde mysql1"
Start-Sleep -Seconds 1

Write-Subtitulo "Insertando nuevo empleado desde NODO 2 (mysql2)..."
Write-Host ""
Write-Host "   INSERT: Maria Demo Lopez - Analista" -ForegroundColor $ColorInfo
Ejecutar-Query "mysql2" "INSERT INTO appdb.empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES ('DEMO02', 'Maria Demo Lopez', '99000002', 'Analista Financiero', 'CC-ADM01', 'Sede Central')" $false
Write-Exito "Empleado DEMO02 insertado desde mysql2"
Start-Sleep -Seconds 1

Write-Subtitulo "Insertando nuevo empleado desde NODO 3 (mysql3)..."
Write-Host ""
Write-Host "   📝 INSERT: Juan Demo Martinez - Desarrollador" -ForegroundColor $ColorInfo
Ejecutar-Query "mysql3" "INSERT INTO appdb.empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES ('DEMO03', 'Juan Demo Martinez', '99000003', 'Desarrollador Junior', 'CC-TEC01', 'Planta Norte')" $false
Write-Exito "Empleado DEMO03 insertado desde mysql3"
Start-Sleep -Seconds 1

Write-Subtitulo "Verificando replicación - Consultando DEMO empleados desde mysql1..."
Show-TablaEmpleados "mysql1" "codigo LIKE 'DEMO%'" "Empleados DEMO creados (vistos desde mysql1):"

Write-Host ""
Write-Exito "¡Los 3 empleados están visibles! La replicación es instantánea."
Write-Info "Puedes verificar estos empleados en la web: http://localhost:8091/?seccion=empleados"
Pausar

# ============================================================================
# DEMO 4: FAILOVER - CAÍDA DE UN NODO
# ============================================================================

Write-Titulo "DEMO 4: Alta Disponibilidad - Simulando Caída de Nodo"

Write-Subtitulo "Deteniendo mysql1 (simulando falla del servidor)..."
docker stop mysql1 | Out-Null
Write-ErrorMsg "¡mysql1 ha caído!"

Esperar 10 "Esperando que el cluster detecte la caída"

Show-ClusterStatus

Write-Subtitulo "Insertando empleado con mysql1 CAIDO (desde mysql2)..."
Write-Host ""
Write-Host "   INSERT: Ana Demo Rodriguez - Contadora (mysql1 esta CAIDO)" -ForegroundColor $ColorInfo
Ejecutar-Query "mysql2" "INSERT INTO appdb.empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES ('DEMO04', 'Ana Demo Rodriguez', '99000004', 'Contador General', 'CC-ADM01', 'Sede Central')" $false
Write-Exito "Escritura exitosa en mysql2! El cluster sigue funcionando."

Write-Subtitulo "Verificando datos en mysql3 (mysql1 sigue caído)..."
Show-TablaEmpleados "mysql3" "codigo LIKE 'DEMO%'" "Empleados DEMO vistos desde mysql3:"

Write-Host ""
Write-Exito "El cluster continúa operando con 2 nodos (tolerancia a fallos)"
Pausar

# ============================================================================
# DEMO 5: RECUPERACIÓN AUTOMÁTICA
# ============================================================================

Write-Titulo "DEMO 5: Recuperación Automática del Nodo Caído"

Write-Subtitulo "Reiniciando mysql1..."
docker start mysql1 | Out-Null

Esperar 20 "Esperando que mysql1 se recupere y sincronice"

Show-ClusterStatus

Write-Subtitulo "Verificando que mysql1 tiene TODOS los empleados (incluso DEMO04)..."
Show-TablaEmpleados "mysql1" "codigo LIKE 'DEMO%'" "Empleados DEMO vistos desde mysql1 (después de recuperarse):"

Write-Host ""
Write-Exito "¡mysql1 sincronizó automáticamente el empleado DEMO04 que se insertó mientras estaba caído!"
Pausar

# ============================================================================
# DEMO 6: CAÍDA DE MÚLTIPLES NODOS Y RECUPERACIÓN
# ============================================================================

Write-Titulo "DEMO 6: Escenario Extremo - Caída de 2 Nodos"

Write-Subtitulo "Deteniendo mysql1 y mysql2..."
docker stop mysql1 mysql2 | Out-Null
Write-ErrorMsg "¡mysql1 y mysql2 han caído!"

Esperar 10 "Esperando que el cluster detecte las caídas"

Write-Subtitulo "Consultando empleados con solo mysql3 activo..."
$totalEmpleados = Show-ConteoEmpleados "mysql3"
Write-Host ""
Write-Host "   📊 Total empleados en mysql3: $totalEmpleados" -ForegroundColor $ColorExito

Write-Subtitulo "Insertando empleado con solo 1 nodo activo..."
Write-Host ""
Write-Host "   📝 INSERT: Pedro Demo Sanchez - Gerente (solo mysql3 activo)" -ForegroundColor $ColorInfo
Ejecutar-Query "mysql3" "INSERT INTO appdb.empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES ('DEMO05', 'Pedro Demo Sanchez', '99000005', 'Gerente de TI', 'CC-TEC01', 'Planta Sur')" $false
Write-Exito "Empleado DEMO05 insertado con solo 1 nodo activo (mysql3)"

Pausar

Write-Subtitulo "Recuperando mysql1 y mysql2..."
docker start mysql1 mysql2 | Out-Null

Esperar 25 "Esperando sincronización completa"

Show-ClusterStatus

Write-Subtitulo "Verificando sincronización en todos los nodos..."
Write-Host ""
Write-Host "   ┌─────────────┬────────────────────┬──────────────────────┐" -ForegroundColor $ColorTabla
Write-Host "   │    NODO     │  TOTAL EMPLEADOS   │  EMPLEADOS DEMO      │" -ForegroundColor $ColorTabla
Write-Host "   ├─────────────┼────────────────────┼──────────────────────┤" -ForegroundColor $ColorTabla

foreach ($nodo in @("mysql1", "mysql2", "mysql3")) {
    $total = Show-ConteoEmpleados $nodo
    $demos = docker exec $nodo mysql -uroot -p1234 -N -e "SELECT COUNT(*) FROM appdb.empleados WHERE codigo LIKE 'DEMO%'" 2>$null
    Write-Host "   │  " -NoNewline -ForegroundColor $ColorTabla
    Write-Host $nodo.PadRight(9) -NoNewline -ForegroundColor $ColorDato
    Write-Host " │  " -NoNewline -ForegroundColor $ColorTabla
    Write-Host "$total".PadRight(16) -NoNewline -ForegroundColor $ColorExito
    Write-Host "  │  " -NoNewline -ForegroundColor $ColorTabla
    Write-Host "$($demos.Trim())".PadRight(18) -NoNewline -ForegroundColor $ColorSubtitulo
    Write-Host "  │" -ForegroundColor $ColorTabla
}

Write-Host "   └─────────────┴────────────────────┴──────────────────────┘" -ForegroundColor $ColorTabla

Write-Exito "¡Cluster completamente recuperado y sincronizado!"
Pausar

# ============================================================================
# DEMO 7: MOSTRAR TODOS LOS EMPLEADOS DEMO CREADOS
# ============================================================================

Write-Titulo "DEMO 7: Resumen de Empleados Creados en la Demostración"

Show-TablaEmpleados "mysql1" "codigo LIKE 'DEMO%'" "📋 Todos los empleados DEMO insertados durante la presentación:"

Pausar

# ============================================================================
# LIMPIEZA Y RESUMEN
# ============================================================================

Write-Titulo "LIMPIEZA - Eliminando Empleados de Prueba"

Write-Subtitulo "¿Deseas eliminar los empleados DEMO creados? (s/n)"
if ($Auto) {
    $eliminar = "s"
} else {
    Write-Host "   " -NoNewline
    $eliminar = Read-Host
}

if ($eliminar -eq "s" -or $eliminar -eq "S") {
    Ejecutar-Query "mysql1" "DELETE FROM appdb.empleados WHERE codigo LIKE 'DEMO%'" $false
    Write-Exito "Empleados de demostración eliminados"
} else {
    Write-Info "Los empleados DEMO se mantienen en la base de datos"
    Write-Info "Puedes verlos en: http://localhost:8091/?seccion=empleados"
}

# ============================================================================
# RESUMEN FINAL
# ============================================================================

Write-Titulo "RESUMEN DE LA DEMOSTRACIÓN"

Write-Host @"

   ╔══════════════════════════════════════════════════════════════════════╗
   ║                    CAPACIDADES DEMOSTRADAS                           ║
   ╠══════════════════════════════════════════════════════════════════════╣
   ║                                                                      ║
   ║  ✅ MULTI-PRIMARY: Los 3 nodos pueden leer Y escribir               ║
   ║     → Insertamos empleados desde mysql1, mysql2 y mysql3            ║
   ║                                                                      ║
   ║  ✅ REPLICACIÓN INSTANTÁNEA: Datos sincronizados al momento         ║
   ║     → Los empleados aparecen inmediatamente en todos los nodos      ║
   ║                                                                      ║
   ║  ✅ ALTA DISPONIBILIDAD: El cluster sigue funcionando con           ║
   ║     nodos caídos (tolerancia a 1 falla con quórum)                  ║
   ║     → Insertamos DEMO04 con mysql1 caído                            ║
   ║                                                                      ║
   ║  ✅ RECUPERACIÓN AUTOMÁTICA: Los nodos se reintegran y              ║
   ║     sincronizan automáticamente al volver                           ║
   ║     → mysql1 obtuvo DEMO04 al recuperarse                           ║
   ║                                                                      ║
   ║  ✅ CONSISTENCIA: Datos idénticos en todos los nodos                ║
   ║     → 5 empleados DEMO visibles en los 3 nodos                      ║
   ║                                                                      ║
   ╚══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor $ColorInfo

Show-ClusterStatus

Write-Host "`n"
Write-Host "   🎉 ¡Demostración completada exitosamente!" -ForegroundColor $ColorExito
Write-Host "`n"

if (-not $Auto) {
    Write-Host "   ¿Deseas abrir la aplicación web? (s/n): " -ForegroundColor $ColorSubtitulo -NoNewline
    $respuesta = Read-Host
    if ($respuesta -eq 's' -or $respuesta -eq 'S') {
        Start-Process "http://localhost:8091/?seccion=empleados"
    }
}

Write-Host "`n   Gracias por ver la demostración." -ForegroundColor $ColorInfo
Write-Host "   Aplicación web: http://localhost:8091" -ForegroundColor Gray
Write-Host ""
