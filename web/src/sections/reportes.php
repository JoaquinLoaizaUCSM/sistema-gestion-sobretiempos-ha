<?php
if (!$pdo) {
  echo '<div class="content-box"><div class="msg err">❌ No hay conexión a la base de datos. Recargando en 5 segundos...</div></div>';
  echo '<script>setTimeout(function(){ location.reload(); }, 5000);</script>';
  return;
}

// Obtener parámetros de filtro
$tipoReporte = $_GET['tipo'] ?? 'horas_extras_empleado';
$fechaInicio = $_GET['fecha_inicio'] ?? date('Y-m-01'); // Primer día del mes actual
$fechaFin = $_GET['fecha_fin'] ?? date('Y-m-d'); // Día actual
$empleadoFiltro = $_GET['empleado'] ?? '';

try {
  $empleados_list = $pdo->query('SELECT codigo, nombre FROM empleados ORDER BY nombre')->fetchAll();
} catch (PDOException $e) {
  echo '<div class="content-box"><div class="msg err">❌ Error al cargar datos: ' . htmlspecialchars($e->getMessage()) . '</div></div>';
  echo '<script>setTimeout(function(){ location.reload(); }, 5000);</script>';
  return;
}
?>

<div class="content-box">
  <div class="content-header">
    <h1>📈 Reportes de Sobretiempos</h1>
  </div>

  <!-- Filtros de Reporte -->
  <div class="search-box" style="background: #e3f2fd;">
    <form method="get" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; width: 100%;">
      <input type="hidden" name="seccion" value="reportes">
      
      <div class="form-group">
        <label>📊 Tipo de Reporte</label>
        <select name="tipo">
          <option value="horas_extras_empleado" <?= $tipoReporte === 'horas_extras_empleado' ? 'selected' : '' ?>>
            Horas Extras por Empleado
          </option>
          <option value="top_empleados" <?= $tipoReporte === 'top_empleados' ? 'selected' : '' ?>>
            Top Empleados con Más Horas
          </option>
          <option value="centro_coste" <?= $tipoReporte === 'centro_coste' ? 'selected' : '' ?>>
            Por Centro de Coste
          </option>
          <option value="por_dia_semana" <?= $tipoReporte === 'por_dia_semana' ? 'selected' : '' ?>>
            Por Día de la Semana
          </option>
          <option value="tardanzas" <?= $tipoReporte === 'tardanzas' ? 'selected' : '' ?>>
            Registro de Tardanzas
          </option>
          <option value="ausencias" <?= $tipoReporte === 'ausencias' ? 'selected' : '' ?>>
            Registro de Ausencias
          </option>
        </select>
      </div>
      
      <div class="form-group">
        <label>📅 Fecha Inicio</label>
        <input type="date" name="fecha_inicio" value="<?= htmlspecialchars($fechaInicio) ?>">
      </div>
      
      <div class="form-group">
        <label>📅 Fecha Fin</label>
        <input type="date" name="fecha_fin" value="<?= htmlspecialchars($fechaFin) ?>">
      </div>
      
      <?php if ($tipoReporte === 'horas_extras_empleado'): ?>
      <div class="form-group">
        <label>👤 Empleado (Opcional)</label>
        <select name="empleado">
          <option value="">Todos</option>
          <?php foreach ($empleados_list as $emp): ?>
            <option value="<?= htmlspecialchars($emp['codigo']) ?>" <?= $empleadoFiltro === $emp['codigo'] ? 'selected' : '' ?>>
              <?= htmlspecialchars($emp['codigo']) ?> - <?= htmlspecialchars($emp['nombre']) ?>
            </option>
          <?php endforeach; ?>
        </select>
      </div>
      <?php endif; ?>
      
      <div style="display: flex; align-items: flex-end;">
        <button type="submit" class="btn btn-primary">Generar Reporte</button>
      </div>
    </form>
  </div>

  <!-- Contenido del Reporte -->
  <?php if ($tipoReporte === 'horas_extras_empleado'): ?>
    <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">Total de Horas Extras por Empleado</h2>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Código</th>
            <th>Nombre</th>
            <th>Puesto</th>
            <th>H25 (25%)</th>
            <th>H35 (35%)</th>
            <th>H100 (100%)</th>
            <th>Total Horas</th>
          </tr>
        </thead>
        <tbody>
          <?php
          $whereClause = 'WHERE ra.fecha BETWEEN ? AND ?';
          $params = [$fechaInicio, $fechaFin];
          if ($empleadoFiltro !== '') {
            $whereClause .= ' AND e.codigo = ?';
            $params[] = $empleadoFiltro;
          }
          
          $query = "
            SELECT 
              e.codigo,
              e.nombre,
              e.puesto_area,
              SUM(ra.H25) as total_h25,
              SUM(ra.H35) as total_h35,
              SUM(ra.H100) as total_h100,
              SUM(ra.H25 + ra.H35 + ra.H100) as total
            FROM empleados e
            LEFT JOIN reporte_asistencia ra ON e.codigo = ra.codigo_empleado
            $whereClause
            GROUP BY e.codigo, e.nombre, e.puesto_area
            HAVING total > 0
            ORDER BY total DESC
          ";
          $stmt = $pdo->prepare($query);
          $stmt->execute($params);
          $results = $stmt->fetchAll();
          
          if (count($results) > 0):
            $totalH25 = 0;
            $totalH35 = 0;
            $totalH100 = 0;
            $totalGeneral = 0;
            
            foreach ($results as $row):
              $totalH25 += $row['total_h25'];
              $totalH35 += $row['total_h35'];
              $totalH100 += $row['total_h100'];
              $totalGeneral += $row['total'];
          ?>
            <tr>
              <td><?= htmlspecialchars($row['codigo']) ?></td>
              <td><?= htmlspecialchars($row['nombre']) ?></td>
              <td><?= htmlspecialchars($row['puesto_area']) ?></td>
              <td><?= number_format($row['total_h25'], 2) ?></td>
              <td><?= number_format($row['total_h35'], 2) ?></td>
              <td><?= number_format($row['total_h100'], 2) ?></td>
              <td><strong><?= number_format($row['total'], 2) ?></strong></td>
            </tr>
          <?php 
            endforeach;
          ?>
            <tr style="background: #e3f2fd; font-weight: bold;">
              <td colspan="3">TOTAL GENERAL</td>
              <td><?= number_format($totalH25, 2) ?></td>
              <td><?= number_format($totalH35, 2) ?></td>
              <td><?= number_format($totalH100, 2) ?></td>
              <td><strong><?= number_format($totalGeneral, 2) ?></strong></td>
            </tr>
          <?php else: ?>
            <tr><td colspan="7" class="no-data">No hay datos en el rango de fechas seleccionado</td></tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>

  <?php elseif ($tipoReporte === 'top_empleados'): ?>
    <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">Top 10 Empleados con Más Horas Extras</h2>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Posición</th>
            <th>Código</th>
            <th>Nombre</th>
            <th>Total Horas</th>
            <th>Registros</th>
          </tr>
        </thead>
        <tbody>
          <?php
          $query = "
            SELECT 
              e.codigo,
              e.nombre,
              SUM(ra.H25 + ra.H35 + ra.H100) as total,
              COUNT(*) as registros
            FROM empleados e
            LEFT JOIN reporte_asistencia ra ON e.codigo = ra.codigo_empleado
            WHERE ra.fecha BETWEEN ? AND ?
            GROUP BY e.codigo, e.nombre
            HAVING total > 0
            ORDER BY total DESC
            LIMIT 10
          ";
          $stmt = $pdo->prepare($query);
          $stmt->execute([$fechaInicio, $fechaFin]);
          $results = $stmt->fetchAll();
          
          if (count($results) > 0):
            $position = 1;
            foreach ($results as $row):
          ?>
            <tr>
              <td><strong><?= $position++ ?></strong></td>
              <td><?= htmlspecialchars($row['codigo']) ?></td>
              <td><?= htmlspecialchars($row['nombre']) ?></td>
              <td><strong><?= number_format($row['total'], 2) ?></strong></td>
              <td><?= $row['registros'] ?></td>
            </tr>
          <?php 
            endforeach;
          else:
          ?>
            <tr><td colspan="5" class="no-data">No hay datos en el rango de fechas seleccionado</td></tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>

  <?php elseif ($tipoReporte === 'centro_coste'): ?>
    <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">Horas Extras por Centro de Coste</h2>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Centro de Coste</th>
            <th>Total Empleados</th>
            <th>H25 (25%)</th>
            <th>H35 (35%)</th>
            <th>H100 (100%)</th>
            <th>Total Horas</th>
          </tr>
        </thead>
        <tbody>
          <?php
          $query = "
            SELECT 
              cc.centro_coste,
              COUNT(DISTINCT e.codigo) as total_empleados,
              SUM(ra.H25) as total_h25,
              SUM(ra.H35) as total_h35,
              SUM(ra.H100) as total_h100,
              SUM(ra.H25 + ra.H35 + ra.H100) as total
            FROM centro_coste cc
            LEFT JOIN empleados e ON cc.codigo_centroCoste = e.Codigo_CentroCoste
            LEFT JOIN reporte_asistencia ra ON e.codigo = ra.codigo_empleado
            WHERE ra.fecha BETWEEN ? AND ?
            GROUP BY cc.codigo_centroCoste, cc.centro_coste
            HAVING total > 0
            ORDER BY total DESC
          ";
          $stmt = $pdo->prepare($query);
          $stmt->execute([$fechaInicio, $fechaFin]);
          $results = $stmt->fetchAll();
          
          if (count($results) > 0):
            foreach ($results as $row):
          ?>
            <tr>
              <td><?= htmlspecialchars($row['centro_coste']) ?></td>
              <td><?= $row['total_empleados'] ?></td>
              <td><?= number_format($row['total_h25'], 2) ?></td>
              <td><?= number_format($row['total_h35'], 2) ?></td>
              <td><?= number_format($row['total_h100'], 2) ?></td>
              <td><strong><?= number_format($row['total'], 2) ?></strong></td>
            </tr>
          <?php 
            endforeach;
          else:
          ?>
            <tr><td colspan="6" class="no-data">No hay datos en el rango de fechas seleccionado</td></tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>

  <?php elseif ($tipoReporte === 'por_dia_semana'): ?>
    <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">Horas Extras por Día de la Semana</h2>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Día</th>
            <th>Total Horas Extras</th>
            <th>Registros</th>
          </tr>
        </thead>
        <tbody>
          <?php
          $query = "
            SELECT 
              dia,
              SUM(H25 + H35 + H100) as total,
              COUNT(*) as registros
            FROM reporte_asistencia
            WHERE fecha BETWEEN ? AND ?
            GROUP BY dia
            ORDER BY 
              CASE
                WHEN dia = 'Lunes' THEN 1
                WHEN dia = 'Martes' THEN 2
                WHEN dia = 'Miércoles' THEN 3
                WHEN dia = 'Jueves' THEN 4
                WHEN dia = 'Viernes' THEN 5
                WHEN dia = 'Sábado' THEN 6
                WHEN dia = 'Domingo' THEN 7
              END
          ";
          $stmt = $pdo->prepare($query);
          $stmt->execute([$fechaInicio, $fechaFin]);
          $results = $stmt->fetchAll();
          
          if (count($results) > 0):
            foreach ($results as $row):
          ?>
            <tr>
              <td><strong><?= htmlspecialchars($row['dia']) ?></strong></td>
              <td><?= number_format($row['total'], 2) ?></td>
              <td><?= $row['registros'] ?></td>
            </tr>
          <?php 
            endforeach;
          else:
          ?>
            <tr><td colspan="3" class="no-data">No hay datos en el rango de fechas seleccionado</td></tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>

  <?php elseif ($tipoReporte === 'tardanzas'): ?>
    <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">Registro de Tardanzas</h2>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Fecha</th>
            <th>Empleado</th>
            <th>Turno Inicio</th>
            <th>Marca Entrada</th>
            <th>Tiempo Tarde</th>
          </tr>
        </thead>
        <tbody>
          <?php
          $query = "
            SELECT 
              ra.fecha,
              e.nombre,
              t.hora_entrada,
              ra.marca_entrada,
              TIMEDIFF(ra.marca_entrada, t.hora_entrada) as tiempo_tarde
            FROM reporte_asistencia ra
            JOIN empleados e ON ra.codigo_empleado = e.codigo
            JOIN turnos t ON ra.codigo_turno = t.codigo_turno
            WHERE ra.fecha BETWEEN ? AND ?
              AND ra.marca_entrada > t.hora_entrada
            ORDER BY ra.fecha DESC
            LIMIT 50
          ";
          $stmt = $pdo->prepare($query);
          $stmt->execute([$fechaInicio, $fechaFin]);
          $results = $stmt->fetchAll();
          
          if (count($results) > 0):
            foreach ($results as $row):
          ?>
            <tr>
              <td><?= htmlspecialchars($row['fecha']) ?></td>
              <td><?= htmlspecialchars($row['nombre']) ?></td>
              <td><?= htmlspecialchars($row['hora_entrada']) ?></td>
              <td><?= htmlspecialchars($row['marca_entrada']) ?></td>
              <td><span style="color: #e74c3c; font-weight: bold;"><?= htmlspecialchars($row['tiempo_tarde']) ?></span></td>
            </tr>
          <?php 
            endforeach;
          else:
          ?>
            <tr><td colspan="5" class="no-data">No se registraron tardanzas en el período seleccionado</td></tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>

  <?php elseif ($tipoReporte === 'ausencias'): ?>
    <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">Registro de Ausencias</h2>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Empleado</th>
            <th>Total Faltas</th>
          </tr>
        </thead>
        <tbody>
          <?php
          $query = "
            SELECT 
              e.nombre,
              COUNT(*) as total_faltas
            FROM reporte_asistencia ra
            JOIN empleados e ON ra.codigo_empleado = e.codigo
            WHERE ra.fecha BETWEEN ? AND ?
              AND ra.marca_entrada IS NULL
              AND ra.codigo_turno <> 'DES'
            GROUP BY e.codigo, e.nombre
            HAVING COUNT(*) > 0
            ORDER BY total_faltas DESC
          ";
          $stmt = $pdo->prepare($query);
          $stmt->execute([$fechaInicio, $fechaFin]);
          $results = $stmt->fetchAll();
          
          if (count($results) > 0):
            foreach ($results as $row):
          ?>
            <tr>
              <td><?= htmlspecialchars($row['nombre']) ?></td>
              <td><span style="color: #e74c3c; font-weight: bold;"><?= $row['total_faltas'] ?></span></td>
            </tr>
          <?php 
            endforeach;
          else:
          ?>
            <tr><td colspan="2" class="no-data">No se registraron ausencias en el período seleccionado</td></tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>
  <?php endif; ?>
</div>
