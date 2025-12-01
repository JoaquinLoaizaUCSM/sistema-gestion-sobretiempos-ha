<?php
if (!$pdo) {
  echo '<div class="content-box"><div class="msg err">❌ No hay conexión a la base de datos. Por favor, espere mientras se restablece la conexión...</div></div>';
  echo '<script>setTimeout(function(){ location.reload(); }, 5000);</script>';
  return;
}

// Obtener datos para los formularios
try {
  $areas = $pdo->query('SELECT puesto FROM area ORDER BY puesto')->fetchAll();
  $centrosCosto = $pdo->query('SELECT codigo_centroCoste, centro_coste FROM centro_coste ORDER BY centro_coste')->fetchAll();
} catch (PDOException $e) {
  echo '<div class="content-box"><div class="msg err">❌ Error al cargar datos: ' . htmlspecialchars($e->getMessage()) . '</div></div>';
  echo '<script>setTimeout(function(){ location.reload(); }, 5000);</script>';
  return;
}

// Búsqueda y paginación
$search = $_GET['search'] ?? '';
$page = max(1, intval($_GET['page'] ?? 1));
$perPage = 10;
$offset = ($page - 1) * $perPage;

$whereClause = '';
$params = [];
if ($search !== '') {
  $whereClause = 'WHERE e.codigo LIKE ? OR e.nombre LIKE ? OR e.dni LIKE ?';
  $searchParam = '%' . $search . '%';
  $params = [$searchParam, $searchParam, $searchParam];
}

// Contar total de empleados
$countQuery = "SELECT COUNT(*) as total FROM empleados e $whereClause";
$stmt = $pdo->prepare($countQuery);
$stmt->execute($params);
$totalEmpleados = $stmt->fetch()['total'];
$totalPages = ceil($totalEmpleados / $perPage);

// Obtener empleados con paginación
$query = "
  SELECT 
    e.*, 
    a.unidad_organizativa,
    cc.centro_coste
  FROM empleados e
  LEFT JOIN area a ON e.puesto_area = a.puesto
  LEFT JOIN centro_coste cc ON e.Codigo_CentroCoste = cc.codigo_centroCoste
  $whereClause
  ORDER BY e.codigo
  LIMIT $perPage OFFSET $offset
";
$stmt = $pdo->prepare($query);
$stmt->execute($params);
$empleados = $stmt->fetchAll();

// Obtener empleado para editar
$editEmpleado = null;
$editing = $_GET['edit'] ?? null;
if ($editing) {
  $stmt = $pdo->prepare('SELECT * FROM empleados WHERE codigo = ?');
  $stmt->execute([$editing]);
  $editEmpleado = $stmt->fetch();
}
?>

<div class="content-box">
  <div class="content-header">
    <h1>👥 Gestión de Empleados</h1>
    <button class="btn btn-primary" onclick="showModal('addEmployeeModal')">
      ➕ Nuevo Empleado
    </button>
  </div>

  <!-- Búsqueda -->
  <div class="search-box">
    <form method="get" style="display: flex; gap: 1rem; width: 100%; align-items: flex-end;">
      <input type="hidden" name="seccion" value="empleados">
      <div class="form-group" style="flex: 1;">
        <label>🔍 Buscar Empleado</label>
        <input type="text" name="search" placeholder="Código, nombre o DNI..." value="<?= htmlspecialchars($search) ?>">
      </div>
      <button type="submit" class="btn btn-primary">Buscar</button>
      <?php if ($search): ?>
        <a href="?seccion=empleados" class="btn btn-secondary">Limpiar</a>
      <?php endif; ?>
    </form>
  </div>

  <!-- Tabla de empleados -->
  <div class="table-container">
    <table>
      <thead>
        <tr>
          <th>Código</th>
          <th>Nombre</th>
          <th>DNI</th>
          <th>Puesto</th>
          <th>Unidad Organizativa</th>
          <th>Centro de Coste</th>
          <th>Acciones</th>
        </tr>
      </thead>
      <tbody>
        <?php if (count($empleados) > 0): ?>
          <?php foreach ($empleados as $emp): ?>
            <tr>
              <td><strong><?= htmlspecialchars($emp['codigo']) ?></strong></td>
              <td><?= htmlspecialchars($emp['nombre']) ?></td>
              <td><?= htmlspecialchars($emp['dni']) ?></td>
              <td><?= htmlspecialchars($emp['puesto_area']) ?></td>
              <td><?= htmlspecialchars($emp['unidad_organizativa'] ?? 'N/A') ?></td>
              <td><?= htmlspecialchars($emp['centro_coste'] ?? 'N/A') ?></td>
              <td>
                <div class="actions">
                  <button class="btn btn-warning btn-sm" onclick="editEmployee('<?= htmlspecialchars(json_encode($emp)) ?>')">
                    ✏️ Editar
                  </button>
                  <form method="post" style="display: inline;" onsubmit="return confirm('¿Está seguro de eliminar este empleado?');">
                    <input type="hidden" name="action" value="delete_employee">
                    <input type="hidden" name="codigo" value="<?= htmlspecialchars($emp['codigo']) ?>">
                    <button type="submit" class="btn btn-danger btn-sm">🗑️ Eliminar</button>
                  </form>
                </div>
              </td>
            </tr>
          <?php endforeach; ?>
        <?php else: ?>
          <tr><td colspan="7" class="no-data">No se encontraron empleados</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>

  <!-- Paginación -->
  <?php if ($totalPages > 1): ?>
    <div style="display: flex; justify-content: center; gap: 0.5rem; margin-top: 1rem;">
      <?php for ($i = 1; $i <= $totalPages; $i++): ?>
        <a href="?seccion=empleados&page=<?= $i ?><?= $search ? '&search=' . urlencode($search) : '' ?>" 
           class="btn btn-sm <?= $i === $page ? 'btn-primary' : 'btn-secondary' ?>">
          <?= $i ?>
        </a>
      <?php endfor; ?>
    </div>
  <?php endif; ?>
</div>

<!-- Modal: Agregar Empleado -->
<div id="addEmployeeModal" class="modal">
  <div class="modal-content">
    <div class="modal-header">
      <h2>➕ Nuevo Empleado</h2>
      <button class="close" onclick="closeModal('addEmployeeModal')">&times;</button>
    </div>
    <form method="post">
      <input type="hidden" name="action" value="add_employee">
      
      <div class="form-row">
        <div class="form-group">
          <label>Código <span class="required">*</span></label>
          <input type="text" name="codigo" required maxlength="6" placeholder="E00001">
        </div>
        <div class="form-group">
          <label>DNI <span class="required">*</span></label>
          <input type="text" name="dni" required maxlength="8" placeholder="12345678">
        </div>
      </div>

      <div class="form-group">
        <label>Nombre Completo <span class="required">*</span></label>
        <input type="text" name="nombre" required maxlength="80" placeholder="Juan Pérez García">
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>Puesto <span class="required">*</span></label>
          <select name="puesto_area" required>
            <option value="">Seleccione...</option>
            <?php foreach ($areas as $area): ?>
              <option value="<?= htmlspecialchars($area['puesto']) ?>"><?= htmlspecialchars($area['puesto']) ?></option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="form-group">
          <label>Centro de Coste <span class="required">*</span></label>
          <select name="codigo_centrocoste" required>
            <option value="">Seleccione...</option>
            <?php foreach ($centrosCosto as $cc): ?>
              <option value="<?= htmlspecialchars($cc['codigo_centroCoste']) ?>">
                <?= htmlspecialchars($cc['centro_coste']) ?>
              </option>
            <?php endforeach; ?>
          </select>
        </div>
      </div>

      <div class="form-group">
        <label>Subdivisión</label>
        <input type="text" name="subdivision" maxlength="100" placeholder="Departamento, área específica...">
      </div>

      <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 1.5rem;">
        <button type="button" class="btn btn-secondary" onclick="closeModal('addEmployeeModal')">Cancelar</button>
        <button type="submit" class="btn btn-primary">💾 Guardar Empleado</button>
      </div>
    </form>
  </div>
</div>

<!-- Modal: Editar Empleado -->
<div id="editEmployeeModal" class="modal">
  <div class="modal-content">
    <div class="modal-header">
      <h2>✏️ Editar Empleado</h2>
      <button class="close" onclick="closeModal('editEmployeeModal')">&times;</button>
    </div>
    <form method="post" id="editEmployeeForm">
      <input type="hidden" name="action" value="update_employee">
      <input type="hidden" name="codigo" id="edit_codigo">
      
      <div class="form-row">
        <div class="form-group">
          <label>Código</label>
          <input type="text" id="edit_codigo_display" disabled>
        </div>
        <div class="form-group">
          <label>DNI <span class="required">*</span></label>
          <input type="text" name="dni" id="edit_dni" required maxlength="8">
        </div>
      </div>

      <div class="form-group">
        <label>Nombre Completo <span class="required">*</span></label>
        <input type="text" name="nombre" id="edit_nombre" required maxlength="80">
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>Puesto <span class="required">*</span></label>
          <select name="puesto_area" id="edit_puesto_area" required>
            <option value="">Seleccione...</option>
            <?php foreach ($areas as $area): ?>
              <option value="<?= htmlspecialchars($area['puesto']) ?>"><?= htmlspecialchars($area['puesto']) ?></option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="form-group">
          <label>Centro de Coste <span class="required">*</span></label>
          <select name="codigo_centrocoste" id="edit_codigo_centrocoste" required>
            <option value="">Seleccione...</option>
            <?php foreach ($centrosCosto as $cc): ?>
              <option value="<?= htmlspecialchars($cc['codigo_centroCoste']) ?>">
                <?= htmlspecialchars($cc['centro_coste']) ?>
              </option>
            <?php endforeach; ?>
          </select>
        </div>
      </div>

      <div class="form-group">
        <label>Subdivisión</label>
        <input type="text" name="subdivision" id="edit_subdivision" maxlength="100">
      </div>

      <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 1.5rem;">
        <button type="button" class="btn btn-secondary" onclick="closeModal('editEmployeeModal')">Cancelar</button>
        <button type="submit" class="btn btn-warning">💾 Actualizar Empleado</button>
      </div>
    </form>
  </div>
</div>

<script>
function showModal(modalId) {
  document.getElementById(modalId).classList.add('show');
}

function closeModal(modalId) {
  document.getElementById(modalId).classList.remove('show');
}

function editEmployee(empJson) {
  const emp = JSON.parse(empJson);
  document.getElementById('edit_codigo').value = emp.codigo;
  document.getElementById('edit_codigo_display').value = emp.codigo;
  document.getElementById('edit_dni').value = emp.dni;
  document.getElementById('edit_nombre').value = emp.nombre;
  document.getElementById('edit_puesto_area').value = emp.puesto_area;
  document.getElementById('edit_codigo_centrocoste').value = emp.Codigo_CentroCoste;
  document.getElementById('edit_subdivision').value = emp.subdivision || '';
  showModal('editEmployeeModal');
}

// Cerrar modal al hacer clic fuera
window.onclick = function(event) {
  if (event.target.classList.contains('modal')) {
    event.target.classList.remove('show');
  }
}
</script>
