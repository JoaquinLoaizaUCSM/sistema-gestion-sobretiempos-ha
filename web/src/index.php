<?php
/**
 * Sistema de Gestión de Sobretiempos
 * Industrias San Miguel del Sur SAC (Kola Real)
 * 
 * Aplicativo web para gestionar el registro de horas extras de los trabajadores
 */

// Configuración de conexión a MySQL via Router
$cfg = [
  'host' => getenv('DB_HOST') ?: 'mysql-router',
  'port' => (int)(getenv('DB_PORT') ?: 6446),
  'user' => getenv('DB_USER') ?: 'app',
  'pass' => getenv('DB_PASSWORD') ?: '1234',
  'db'   => getenv('DB_NAME') ?: 'appdb',
];

function db_connect($cfg, $retries = 10, $sleep = 3) {
  // Conectar via Router - En modo Multi-Primary todos los nodos pueden R/W
  $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $cfg['host'], $cfg['port'], $cfg['db']);
  
  $lastError = null;
  for ($i = 0; $i < $retries; $i++) {
    try {
      $pdo = new PDO($dsn, $cfg['user'], $cfg['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_PERSISTENT => false,
        PDO::ATTR_TIMEOUT => 10,
        PDO::ATTR_EMULATE_PREPARES => false,
        PDO::MYSQL_ATTR_INIT_COMMAND => "SET SESSION wait_timeout=300",
        // Configuración crítica para manejar reconexiones
        // Usamos valores enteros directos si las constantes no están definidas para evitar errores
        // 1000 => 10, // PDO::MYSQL_ATTR_CONNECT_TIMEOUT
        // 1001 => 10, // PDO::MYSQL_ATTR_READ_TIMEOUT
        // 1002 => 10, // PDO::MYSQL_ATTR_WRITE_TIMEOUT
      ]);
      
      // Test de conexión
      $pdo->query('SELECT 1');
      return $pdo;
      
    } catch (PDOException $e) {
      $lastError = $e;
      $errorCode = $e->getCode();
      
      // Errores de conexión que justifican reintentar
      $retryableCodes = ['HY000', '2002', '2003', '2006', '2013'];
      
      if (in_array($errorCode, $retryableCodes) && $i < $retries - 1) {
        // Esperar antes de reintentar (backoff exponencial limitado)
        $waitTime = min($sleep * ($i + 1), 15); // Máximo 15 segundos
        sleep($waitTime);
        continue;
      }
      
      // Si es el último intento o error no recuperable, lanzar excepción
      if ($i === $retries - 1) {
        throw new PDOException(
          sprintf('No se pudo conectar al Router MySQL después de %d intentos. Último error: %s [%s]', 
                  $retries, $e->getMessage(), $errorCode),
          (int)$errorCode
        );
      }
    }
  }
  
  throw $lastError;
}

// Iniciar sesión para mensajes flash
session_start();

$error = $_SESSION['error'] ?? null;
$info = $_SESSION['info'] ?? null;
unset($_SESSION['error'], $_SESSION['info']);

$serverInfo = ['host' => 'N/A', 'role' => 'Standalone', 'is_primary' => true, 'server_id' => 'N/A'];
$seccion = $_GET['seccion'] ?? 'dashboard';
$pdo = null;

try {
  $pdo = db_connect($cfg);

  // Obtener información del servidor actual (via Router)
  try {
    $stmt = $pdo->query("SELECT @@hostname as hostname, @@server_id as server_id");
    $serverData = $stmt->fetch();
    $serverInfo['host'] = $serverData['hostname'] ?? 'Unknown';
    $serverInfo['server_id'] = $serverData['server_id'] ?? 'Unknown';
    
    // Obtener rol del servidor en el cluster (Solo si existe la tabla, para compatibilidad con Single Node)
    try {
        $stmt = $pdo->query("SELECT member_role FROM performance_schema.replication_group_members WHERE member_id = @@server_uuid");
        $roleData = $stmt->fetch();
        if ($roleData && isset($roleData['member_role'])) {
          $serverInfo['role'] = $roleData['member_role'];
          $serverInfo['is_primary'] = ($roleData['member_role'] === 'PRIMARY');
        }
    } catch (PDOException $e) {
        // Ignorar error si la tabla no existe (entorno no clusterizado)
        $serverInfo['role'] = 'Standalone';
        $serverInfo['is_primary'] = true;
    }
  } catch (PDOException $e) {
    $serverInfo['role'] = 'Unknown';
    $serverInfo['error_detail'] = $e->getMessage();
  }

  // Manejar acciones POST
  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    // EMPLEADOS
    if ($action === 'add_employee') {
      $codigo = trim($_POST['codigo'] ?? '');
      $nombre = trim($_POST['nombre'] ?? '');
      $dni = trim($_POST['dni'] ?? '');
      $puesto = trim($_POST['puesto_area'] ?? '');
      $centro = trim($_POST['codigo_centrocoste'] ?? '');
      $subdivision = trim($_POST['subdivision'] ?? '');
      
      if ($codigo && $nombre && $dni && $puesto && $centro) {
        try {
          $stmt = $pdo->prepare('INSERT INTO empleados(codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES(?, ?, ?, ?, ?, ?)');
          $stmt->execute([$codigo, $nombre, $dni, $puesto, $centro, $subdivision]);
          $_SESSION['info'] = '✅ Empleado registrado exitosamente';
        } catch (PDOException $e) {
          $_SESSION['error'] = '❌ Error al registrar empleado: ' . $e->getMessage();
        }
      } else {
        $_SESSION['error'] = '❌ Todos los campos obligatorios deben estar completos';
      }
      header('Location: ?seccion=empleados');
      exit;
    }
    
    if ($action === 'update_employee') {
      $codigo = trim($_POST['codigo'] ?? '');
      $nombre = trim($_POST['nombre'] ?? '');
      $dni = trim($_POST['dni'] ?? '');
      $puesto = trim($_POST['puesto_area'] ?? '');
      $centro = trim($_POST['codigo_centrocoste'] ?? '');
      $subdivision = trim($_POST['subdivision'] ?? '');
      
      if ($codigo && $nombre && $dni && $puesto && $centro) {
        try {
          $stmt = $pdo->prepare('UPDATE empleados SET nombre=?, dni=?, puesto_area=?, Codigo_CentroCoste=?, subdivision=? WHERE codigo=?');
          $stmt->execute([$nombre, $dni, $puesto, $centro, $subdivision, $codigo]);
          $_SESSION['info'] = '✅ Empleado actualizado exitosamente';
        } catch (PDOException $e) {
          $_SESSION['error'] = '❌ Error al actualizar empleado: ' . $e->getMessage();
        }
      } else {
        $_SESSION['error'] = '❌ Todos los campos obligatorios deben estar completos';
      }
      header('Location: ?seccion=empleados');
      exit;
    }
    
    if ($action === 'delete_employee') {
      $codigo = trim($_POST['codigo'] ?? '');
      if ($codigo) {
        try {
          $pdo->beginTransaction();
          
          // Primero eliminar registros de asistencia relacionados (FK constraint)
          $stmt = $pdo->prepare('DELETE FROM reporte_asistencia WHERE codigo_empleado=?');
          $stmt->execute([$codigo]);
          
          // Luego eliminar el empleado
          $stmt = $pdo->prepare('DELETE FROM empleados WHERE codigo=?');
          $stmt->execute([$codigo]);
          
          $pdo->commit();
          $_SESSION['info'] = '✅ Empleado y sus registros eliminados exitosamente';
        } catch (PDOException $e) {
          if ($pdo->inTransaction()) {
            $pdo->rollBack();
          }
          $_SESSION['error'] = '❌ Error al eliminar empleado: ' . $e->getMessage();
        }
      }
      header('Location: ?seccion=empleados');
      exit;
    }

    // ASISTENCIAS
    if ($action === 'add_attendance') {
      $fecha = trim($_POST['fecha'] ?? '');
      $codigo_empleado = trim($_POST['codigo_empleado'] ?? '');
      $codigo_turno = trim($_POST['codigo_turno'] ?? '');
      $dia = trim($_POST['dia'] ?? '');
      $marca_entrada = trim($_POST['marca_entrada'] ?? '') ?: null;
      $marca_salida = trim($_POST['marca_salida'] ?? '') ?: null;
      $h25 = floatval($_POST['h25'] ?? 0);
      $h35 = floatval($_POST['h35'] ?? 0);
      $h100 = floatval($_POST['h100'] ?? 0);
      
      if ($fecha && $codigo_empleado && $codigo_turno && $dia) {
        try {
          $stmt = $pdo->prepare('INSERT INTO reporte_asistencia(fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)');
          $stmt->execute([$fecha, $codigo_empleado, $codigo_turno, $dia, $marca_entrada, $marca_salida, $h25, $h35, $h100]);
          $_SESSION['info'] = '✅ Registro de asistencia creado exitosamente';
        } catch (PDOException $e) {
          $_SESSION['error'] = '❌ Error al registrar asistencia: ' . $e->getMessage();
        }
      } else {
        $_SESSION['error'] = '❌ Los campos obligatorios deben estar completos';
      }
      header('Location: ?seccion=asistencias');
      exit;
    }
    
    if ($action === 'update_attendance') {
      $fecha = trim($_POST['fecha'] ?? '');
      $codigo_empleado = trim($_POST['codigo_empleado'] ?? '');
      $codigo_turno = trim($_POST['codigo_turno'] ?? '');
      $dia = trim($_POST['dia'] ?? '');
      $marca_entrada = trim($_POST['marca_entrada'] ?? '') ?: null;
      $marca_salida = trim($_POST['marca_salida'] ?? '') ?: null;
      $h25 = floatval($_POST['h25'] ?? 0);
      $h35 = floatval($_POST['h35'] ?? 0);
      $h100 = floatval($_POST['h100'] ?? 0);
      
      if ($fecha && $codigo_empleado && $codigo_turno && $dia) {
        try {
          $stmt = $pdo->prepare('UPDATE reporte_asistencia SET codigo_turno=?, dia=?, marca_entrada=?, marca_salida=?, H25=?, H35=?, H100=? WHERE fecha=? AND codigo_empleado=?');
          $stmt->execute([$codigo_turno, $dia, $marca_entrada, $marca_salida, $h25, $h35, $h100, $fecha, $codigo_empleado]);
          $_SESSION['info'] = '✅ Registro de asistencia actualizado exitosamente';
        } catch (PDOException $e) {
          $_SESSION['error'] = '❌ Error al actualizar asistencia: ' . $e->getMessage();
        }
      } else {
        $_SESSION['error'] = '❌ Los campos obligatorios deben estar completos';
      }
      header('Location: ?seccion=asistencias');
      exit;
    }
    
    if ($action === 'delete_attendance') {
      $fecha = trim($_POST['fecha'] ?? '');
      $codigo_empleado = trim($_POST['codigo_empleado'] ?? '');
      if ($fecha && $codigo_empleado) {
        try {
          $stmt = $pdo->prepare('DELETE FROM reporte_asistencia WHERE fecha=? AND codigo_empleado=?');
          $stmt->execute([$fecha, $codigo_empleado]);
          $_SESSION['info'] = '✅ Registro de asistencia eliminado exitosamente';
        } catch (PDOException $e) {
          $_SESSION['error'] = '❌ Error al eliminar asistencia: ' . $e->getMessage();
        }
      }
      header('Location: ?seccion=asistencias');
      exit;
    }
  }

  // Obtener estadísticas para dashboard
  $stats = [];
  if ($seccion === 'dashboard' && $pdo) {
    try {
      $stmt = $pdo->query('SELECT COUNT(*) as total FROM empleados');
      $stats['total_empleados'] = $stmt->fetch()['total'];
      
      $stmt = $pdo->query('SELECT COUNT(*) as total FROM reporte_asistencia');
      $stats['total_registros'] = $stmt->fetch()['total'];
      
      $stmt = $pdo->query('SELECT SUM(H25 + H35 + H100) as total FROM reporte_asistencia');
      $stats['total_horas_extra'] = round($stmt->fetch()['total'] ?? 0, 2);
      
      $stmt = $pdo->query('SELECT COUNT(DISTINCT codigo_empleado) as total FROM reporte_asistencia WHERE H25 > 0 OR H35 > 0 OR H100 > 0');
      $stats['empleados_con_extras'] = $stmt->fetch()['total'];
    } catch (PDOException $e) {
      $error = '❌ Error al obtener estadísticas: ' . htmlspecialchars($e->getMessage());
    }
  }

} catch (Throwable $e) {
  $error = '❌ Error de conexión: ' . htmlspecialchars($e->getMessage()) . ' - Código: ' . $e->getCode();
  $pdo = null;
}
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sistema de Gestión de Sobretiempos - Kola Real</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <div class="sidebar">
    <div class="logo">
      <h2>🏭 Kola Real</h2>
      <p>Sistema de Sobretiempos</p>
    </div>
    <nav>
      <a href="?seccion=dashboard" class="<?= $seccion === 'dashboard' ? 'active' : '' ?>">
        📊 Dashboard
      </a>
      <a href="?seccion=empleados" class="<?= $seccion === 'empleados' ? 'active' : '' ?>">
        👥 Empleados
      </a>
      <a href="?seccion=asistencias" class="<?= $seccion === 'asistencias' ? 'active' : '' ?>">
        📝 Asistencias
      </a>
      <a href="?seccion=reportes" class="<?= $seccion === 'reportes' ? 'active' : '' ?>">
        📈 Reportes
      </a>
    </nav>
  </div>

  <div class="main-content">
    <!-- Header con info del servidor -->
    <div class="server-info <?php echo $serverInfo['is_primary'] ? 'primary' : ($serverInfo['role'] === 'SECONDARY' ? 'secondary' : ''); ?>">
      <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap;">
        <div>
          <strong>🔌 Servidor Actual:</strong> 
          <span style="font-family: monospace; font-size: 1.1rem;"><?php echo htmlspecialchars($serverInfo['host']); ?></span>
          <span class="badge badge-<?php echo $serverInfo['is_primary'] ? 'primary' : ($serverInfo['role'] === 'SECONDARY' ? 'secondary' : 'unknown'); ?>">
            <?php echo htmlspecialchars($serverInfo['role']); ?>
          </span>
        </div>
      </div>
      <div class="muted">
        Server ID: <?php echo htmlspecialchars($serverInfo['server_id']); ?> | 
        Router: <?=htmlspecialchars($cfg['host'])?>:<?=htmlspecialchars((string)$cfg['port'])?> | 
        Database: <?=htmlspecialchars($cfg['db'])?>
      </div>
    </div>

    <?php if ($info): ?><div class="msg ok"><?=htmlspecialchars($info)?></div><?php endif; ?>
    <?php if ($error): ?><div class="msg err"><?=htmlspecialchars($error)?></div><?php endif; ?>

    <?php if ($seccion === 'dashboard'): ?>
      <?php include 'sections/dashboard.php'; ?>
    <?php elseif ($seccion === 'empleados'): ?>
      <?php include 'sections/empleados.php'; ?>
    <?php elseif ($seccion === 'asistencias'): ?>
      <?php include 'sections/asistencias.php'; ?>
    <?php elseif ($seccion === 'reportes'): ?>
      <?php include 'sections/reportes.php'; ?>
    <?php endif; ?>
  </div>
</body>
</html>
