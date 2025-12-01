<?php
if (!$pdo) {
  echo '<div class="content-box"><div class="msg err">❌ No hay conexión a la base de datos. Recargando en 5 segundos...</div></div>';
  echo '<script>setTimeout(function(){ location.reload(); }, 5000);</script>';
  return;
}

// Obtener datos para los formularios
try {
  $empleados_list = $pdo->query('SELECT codigo, nombre FROM empleados ORDER BY nombre')->fetchAll();
  $turnos = $pdo->query('SELECT codigo_turno, hora_entrada, hora_salida FROM turnos ORDER BY codigo_turno')->fetchAll();
} catch (PDOException $e) {
  echo '<div class="content-box"><div class="msg err">❌ Error al cargar datos: ' . htmlspecialchars($e->getMessage()) . '</div></div>';
  echo '<script>setTimeout(function(){ location.reload(); }, 5000);</script>';
  return;
}

// Búsqueda y filtros
$search = $_GET['search'] ?? '';
$filterEmpleado = $_GET['empleado'] ?? '';
$filterFechaInicio = $_GET['fecha_inicio'] ?? '';
$filterFechaFin = $_GET['fecha_fin'] ?? '';
$page = max(1, intval($_GET['page'] ?? 1));
$perPage = 15;
$offset = ($page - 1) * $perPage;

$whereConditions = [];
$params = [];

if ($search !== '') {
  $whereConditions[] = '(e.codigo LIKE ? OR e.nombre LIKE ?)';
  $searchParam = '%' . $search . '%';
  $params[] = $searchParam;
  $params[] = $searchParam;
}

if ($filterEmpleado !== '') {
  $whereConditions[] = 'ra.codigo_empleado = ?';
  $params[] = $filterEmpleado;
}

if ($filterFechaInicio !== '') {
  $whereConditions[] = 'ra.fecha >= ?';
  $params[] = $filterFechaInicio;
}

if ($filterFechaFin !== '') {
  $whereConditions[] = 'ra.fecha <= ?';
  $params[] = $filterFechaFin;
}

$whereClause = count($whereConditions) > 0 ? 'WHERE ' . implode(' AND ', $whereConditions) : '';

// Contar total de registros
$countQuery = "SELECT COUNT(*) as total FROM reporte_asistencia ra LEFT JOIN empleados e ON ra.codigo_empleado = e.codigo $whereClause";
$stmt = $pdo->prepare($countQuery);
$stmt->execute($params);
$totalRegistros = $stmt->fetch()['total'];
$totalPages = ceil($totalRegistros / $perPage);

// Obtener registros de asistencia
$query = "
  SELECT 
    ra.*,
    e.nombre as nombre_empleado,
    t.hora_entrada,
    t.hora_salida
  FROM reporte_asistencia ra
  LEFT JOIN empleados e ON ra.codigo_empleado = e.codigo
  LEFT JOIN turnos t ON ra.codigo_turno = t.codigo_turno
  $whereClause
  ORDER BY ra.fecha DESC, e.nombre
  LIMIT $perPage OFFSET $offset
";
$stmt = $pdo->prepare($query);
$stmt->execute($params);
$asistencias = $stmt->fetchAll();
?>

<div class="content-box">
  <div class="content-header">
    <h1>📝 Registro de Asistencias</h1>
    <button class="btn btn-primary" onclick="showModal('addAttendanceModal')">
      ➕ Nuevo Registro
    </button>
  </div>

  <!-- Filtros de Búsqueda -->
  <div class="search-box">
    <form method="get" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; width: 100%;">
      <input type="hidden" name="seccion" value="asistencias">
      
      <div class="form-group">
        <label>🔍 Buscar</label>
        <input type="text" name="search" placeholder="Código o nombre..." value="<?= htmlspecialchars($search) ?>">
      </div>
      
      <div class="form-group">
        <label>👤 Empleado</label>
        <select name="empleado">
          <option value="">Todos</option>
          <?php foreach ($empleados_list as $emp): ?>
            <option value="<?= htmlspecialchars($emp['codigo']) ?>" <?= $filterEmpleado === $emp['codigo'] ? 'selected' : '' ?>>
              <?= htmlspecialchars($emp['codigo']) ?> - <?= htmlspecialchars($emp['nombre']) ?>
            </option>
          <?php endforeach; ?>
        </select>
      </div>
      
      <div class="form-group">
        <label>📅 Fecha Inicio</label>
        <input type="date" name="fecha_inicio" value="<?= htmlspecialchars($filterFechaInicio) ?>">
      </div>
      
      <div class="form-group">
        <label>📅 Fecha Fin</label>
        <input type="date" name="fecha_fin" value="<?= htmlspecialchars($filterFechaFin) ?>">
      </div>
      
      <div style="display: flex; gap: 0.5rem; align-items: flex-end;">
        <button type="submit" class="btn btn-primary btn-sm">Filtrar</button>
        <a href="?seccion=asistencias" class="btn btn-secondary btn-sm">Limpiar</a>
      </div>
    </form>
  </div>

  <!-- Tabla de asistencias -->
  <div class="table-container">
    <table>
      <thead>
        <tr>
          <th>Fecha</th>
          <th>Día</th>
          <th>Empleado</th>
          <th>Turno</th>
          <th>Entrada</th>
          <th>Salida</th>
          <th>H25</th>
          <th>H35</th>
          <th>H100</th>
          <th>Total</th>
          <th>Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (count($asistencias) > 0): ?>
          <?php foreach ($asistencias as $asist): ?>
            <?php 
              $totalHoras = $asist['H25'] + $asist['H35'] + $asist['H100'];
              $hasExtras = $totalHoras > 0;
            ?>
            <tr style="<?= $hasExtras ? 'background: #fff3cd;' : '' ?>">
              <td><strong><?= htmlspecialchars($asist['fecha']) ?></strong></td>
              <td><?= htmlspecialchars($asist['dia']) ?></td>
              <td><?= htmlspecialchars($asist['nombre_empleado'] ?? 'N/A') ?></td>
              <td><?= htmlspecialchars($asist['codigo_turno']) ?></td>
              <td><?= htmlspecialchars($asist['marca_entrada'] ?? '-') ?></td>
              <td><?= htmlspecialchars($asist['marca_salida'] ?? '-') ?></td>
              <td><?= number_format($asist['H25'], 2) ?></td>
              <td><?= number_format($asist['H35'], 2) ?></td>
              <td><?= number_format($asist['H100'], 2) ?></td>
              <td><strong><?= number_format($totalHoras, 2) ?></strong></td>
              <td>
                <div class="actions">
                  <button class="btn btn-warning btn-sm" onclick="editAttendance('<?= htmlspecialchars(json_encode($asist)) ?>')">
                    ✏️
                  </button>
                  <form method="post" style="display: inline;" onsubmit="return confirm('¿Eliminar este registro?');">
                    <input type="hidden" name="action" value="delete_attendance">
                    <input type="hidden" name="fecha" value="<?= htmlspecialchars($asist['fecha']) ?>">
                    <input type="hidden" name="codigo_empleado" value="<?= htmlspecialchars($asist['codigo_empleado']) ?>">
                    <button type="submit" class="btn btn-danger btn-sm">🗑️</button>
                  </form>
                </div>
              </td>
            </tr>
          <?php endforeach; ?>
        <?php else: ?>
          <tr><td colspan="11" class="no-data">No se encontraron registros de asistencia</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>

  <!-- Paginación -->
  <?php if ($totalPages > 1): ?>
    <div style="display: flex; justify-content: center; gap: 0.5rem; margin-top: 1rem;">
      <?php 
      $queryString = http_build_query(array_filter([
        'seccion' => 'asistencias',
        'search' => $search,
        'empleado' => $filterEmpleado,
        'fecha_inicio' => $filterFechaInicio,
        'fecha_fin' => $filterFechaFin
      ]));
      ?>
      <?php for ($i = 1; $i <= $totalPages; $i++): ?>
        <a href="?<?= $queryString ?>&page=<?= $i ?>" 
           class="btn btn-sm <?= $i === $page ? 'btn-primary' : 'btn-secondary' ?>">
          <?= $i ?>
        </a>
      <?php endfor; ?>
    </div>
  <?php endif; ?>
</div>

<!-- Modal: Agregar Asistencia -->
<div id="addAttendanceModal" class="modal">
  <div class="modal-content">
    <div class="modal-header">
      <h2>➕ Nuevo Registro de Asistencia</h2>
      <button class="close" onclick="closeModal('addAttendanceModal')">&times;</button>
    </div>
    <form method="post">
      <input type="hidden" name="action" value="add_attendance">
      
      <div class="form-row">
        <div class="form-group">
          <label>Fecha <span class="required">*</span></label>
          <input type="date" name="fecha" required>
        </div>
        <div class="form-group">
          <label>Día <span class="required">*</span></label>
          <select name="dia" required>
            <option value="">Seleccione...</option>
            <option value="Lunes">Lunes</option>
            <option value="Martes">Martes</option>
            <option value="Miércoles">Miércoles</option>
            <option value="Jueves">Jueves</option>
            <option value="Viernes">Viernes</option>
            <option value="Sábado">Sábado</option>
            <option value="Domingo">Domingo</option>
          </select>
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>Empleado <span class="required">*</span></label>
          <select name="codigo_empleado" required>
            <option value="">Seleccione...</option>
            <?php foreach ($empleados_list as $emp): ?>
              <option value="<?= htmlspecialchars($emp['codigo']) ?>">
                <?= htmlspecialchars($emp['codigo']) ?> - <?= htmlspecialchars($emp['nombre']) ?>
              </option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="form-group">
          <label>Turno <span class="required">*</span></label>
          <select name="codigo_turno" required>
            <option value="">Seleccione...</option>
            <?php foreach ($turnos as $turno): ?>
              <option value="<?= htmlspecialchars($turno['codigo_turno']) ?>">
                <?= htmlspecialchars($turno['codigo_turno']) ?> 
                (<?= htmlspecialchars($turno['hora_entrada']) ?> - <?= htmlspecialchars($turno['hora_salida']) ?>)
              </option>
            <?php endforeach; ?>
          </select>
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>Marca Entrada</label>
          <input type="time" name="marca_entrada">
        </div>
        <div class="form-group">
          <label>Marca Salida</label>
          <input type="time" name="marca_salida">
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>H25 (25%)</label>
          <input type="number" name="h25" step="0.01" min="0" value="0">
        </div>
        <div class="form-group">
          <label>H35 (35%)</label>
          <input type="number" name="h35" step="0.01" min="0" value="0">
        </div>
        <div class="form-group">
          <label>H100 (100%)</label>
          <input type="number" name="h100" step="0.01" min="0" value="0">
        </div>
      </div>

      <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 1.5rem;">
        <button type="button" class="btn btn-secondary" onclick="closeModal('addAttendanceModal')">Cancelar</button>
        <button type="submit" class="btn btn-primary">💾 Guardar Registro</button>
      </div>
    </form>
  </div>
</div>

<!-- Modal: Editar Asistencia -->
<div id="editAttendanceModal" class="modal">
  <div class="modal-content">
    <div class="modal-header">
      <h2>✏️ Editar Registro de Asistencia</h2>
      <button class="close" onclick="closeModal('editAttendanceModal')">&times;</button>
    </div>
    <form method="post">
      <input type="hidden" name="action" value="update_attendance">
      <input type="hidden" name="fecha" id="edit_fecha">
      <input type="hidden" name="codigo_empleado" id="edit_codigo_empleado">
      
      <div class="form-row">
        <div class="form-group">
          <label>Fecha</label>
          <input type="date" id="edit_fecha_display" disabled>
        </div>
        <div class="form-group">
          <label>Empleado</label>
          <input type="text" id="edit_empleado_display" disabled>
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>Día <span class="required">*</span></label>
          <select name="dia" id="edit_dia" required>
            <option value="Lunes">Lunes</option>
            <option value="Martes">Martes</option>
            <option value="Miércoles">Miércoles</option>
            <option value="Jueves">Jueves</option>
            <option value="Viernes">Viernes</option>
            <option value="Sábado">Sábado</option>
            <option value="Domingo">Domingo</option>
          </select>
        </div>
        <div class="form-group">
          <label>Turno <span class="required">*</span></label>
          <select name="codigo_turno" id="edit_codigo_turno" required>
            <?php foreach ($turnos as $turno): ?>
              <option value="<?= htmlspecialchars($turno['codigo_turno']) ?>">
                <?= htmlspecialchars($turno['codigo_turno']) ?> 
                (<?= htmlspecialchars($turno['hora_entrada']) ?> - <?= htmlspecialchars($turno['hora_salida']) ?>)
              </option>
            <?php endforeach; ?>
          </select>
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>Marca Entrada</label>
          <input type="time" name="marca_entrada" id="edit_marca_entrada">
        </div>
        <div class="form-group">
          <label>Marca Salida</label>
          <input type="time" name="marca_salida" id="edit_marca_salida">
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>H25 (25%)</label>
          <input type="number" name="h25" id="edit_h25" step="0.01" min="0">
        </div>
        <div class="form-group">
          <label>H35 (35%)</label>
          <input type="number" name="h35" id="edit_h35" step="0.01" min="0">
        </div>
        <div class="form-group">
          <label>H100 (100%)</label>
          <input type="number" name="h100" id="edit_h100" step="0.01" min="0">
        </div>
      </div>

      <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 1.5rem;">
        <button type="button" class="btn btn-secondary" onclick="closeModal('editAttendanceModal')">Cancelar</button>
        <button type="submit" class="btn btn-warning">💾 Actualizar Registro</button>
      </div>
    </form>
  </div>
</div>

<script>
function editAttendance(asistJson) {
  const asist = JSON.parse(asistJson);
  document.getElementById('edit_fecha').value = asist.fecha;
  document.getElementById('edit_fecha_display').value = asist.fecha;
  document.getElementById('edit_codigo_empleado').value = asist.codigo_empleado;
  document.getElementById('edit_empleado_display').value = asist.codigo_empleado + ' - ' + asist.nombre_empleado;
  document.getElementById('edit_dia').value = asist.dia;
  document.getElementById('edit_codigo_turno').value = asist.codigo_turno;
  document.getElementById('edit_marca_entrada').value = asist.marca_entrada || '';
  document.getElementById('edit_marca_salida').value = asist.marca_salida || '';
  document.getElementById('edit_h25').value = asist.H25;
  document.getElementById('edit_h35').value = asist.H35;
  document.getElementById('edit_h100').value = asist.H100;
  showModal('editAttendanceModal');
}
</script>
