<?php
if (!$pdo) {
  echo '<div class="content-box"><div class="msg err">❌ No hay conexión a la base de datos. Recargando en 5 segundos...</div></div>';
  echo '<script>setTimeout(function(){ location.reload(); }, 5000);</script>';
  return;
}
?>

<div class="content-box">
  <div class="content-header">
    <h1>📊 Dashboard - Panel de Control</h1>
  </div>

  <!-- Estadísticas Principales -->
  <div class="stats-grid">
    <div class="stat-card">
      <div class="stat-number"><?= $stats['total_empleados'] ?? 0 ?></div>
      <div class="stat-label">👥 Total de Empleados</div>
    </div>
    
    <div class="stat-card success">
      <div class="stat-number"><?= $stats['total_registros'] ?? 0 ?></div>
      <div class="stat-label">📝 Registros de Asistencia</div>
    </div>
    
    <div class="stat-card warning">
      <div class="stat-number"><?= $stats['total_horas_extra'] ?? 0 ?></div>
      <div class="stat-label">⏰ Total Horas Extras</div>
    </div>
    
    <div class="stat-card danger">
      <div class="stat-number"><?= $stats['empleados_con_extras'] ?? 0 ?></div>
      <div class="stat-label">🔥 Empleados con Extras</div>
    </div>
  </div>

  <!-- Top 5 Empleados con más horas extras -->
  <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">🏆 Top 5 Empleados con Más Horas Extras</h2>
  <div class="table-container">
    <table>
      <thead>
        <tr>
          <th>Posición</th>
          <th>Código</th>
          <th>Nombre</th>
          <th>H25 (25%)</th>
          <th>H35 (35%)</th>
          <th>H100 (100%)</th>
          <th>Total</th>
        </tr>
      </thead>
      <tbody>
        <?php
        try {
        $stmt = $pdo->query('
          SELECT 
            e.codigo,
            e.nombre,
            SUM(ra.H25) as total_h25,
            SUM(ra.H35) as total_h35,
            SUM(ra.H100) as total_h100,
            SUM(ra.H25 + ra.H35 + ra.H100) as total
          FROM empleados e
          LEFT JOIN reporte_asistencia ra ON e.codigo = ra.codigo_empleado
          GROUP BY e.codigo, e.nombre
          HAVING total > 0
          ORDER BY total DESC
          LIMIT 5
        ');
        $position = 1;
        $topEmployees = $stmt->fetchAll();
        if (count($topEmployees) > 0):
          foreach ($topEmployees as $emp):
        ?>
          <tr>
            <td><strong><?= $position++ ?></strong></td>
            <td><?= htmlspecialchars($emp['codigo']) ?></td>
            <td><?= htmlspecialchars($emp['nombre']) ?></td>
            <td><?= number_format($emp['total_h25'], 2) ?></td>
            <td><?= number_format($emp['total_h35'], 2) ?></td>
            <td><?= number_format($emp['total_h100'], 2) ?></td>
            <td><strong><?= number_format($emp['total'], 2) ?></strong></td>
          </tr>
        <?php 
          endforeach;
        else:
        ?>
          <tr><td colspan="7" class="no-data">No hay datos de horas extras registradas</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>

  <!-- Resumen por Centro de Coste -->
  <h2 style="margin: 2rem 0 1rem 0; color: #2c3e50;">💼 Resumen de Horas Extras por Centro de Coste</h2>
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
        $stmt = $pdo->query('
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
          GROUP BY cc.codigo_centroCoste, cc.centro_coste
          ORDER BY total DESC
        ');
        $centroCostes = $stmt->fetchAll();
        if (count($centroCostes) > 0):
          foreach ($centroCostes as $cc):
        ?>
          <tr>
            <td><?= htmlspecialchars($cc['centro_coste']) ?></td>
            <td><?= $cc['total_empleados'] ?></td>
            <td><?= number_format($cc['total_h25'] ?? 0, 2) ?></td>
            <td><?= number_format($cc['total_h35'] ?? 0, 2) ?></td>
            <td><?= number_format($cc['total_h100'] ?? 0, 2) ?></td>
            <td><strong><?= number_format($cc['total'] ?? 0, 2) ?></strong></td>
          </tr>
        <?php 
          endforeach;
        else:
        ?>
          <tr><td colspan="6" class="no-data">No hay centros de coste registrados</td></tr>

        <?php
        endif;
        } catch (PDOException $e) {
          echo '<tr><td colspan="7" class="no-data">Error al cargar datos: ' . htmlspecialchars($e->getMessage()) . '</td></tr>';
        }
        ?>
      </tbody>
    </table>
  </div>
</div>

<div class="content-box" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
  <h2 style="color: white; margin-bottom: 1rem;">💡 Información del Sistema</h2>
  <p style="margin-bottom: 0.5rem;">
    <strong>Base de Datos:</strong> MySQL InnoDB Cluster con Alta Disponibilidad
  </p>
  <p style="margin-bottom: 0.5rem;">
    <strong>Empresa:</strong> Industrias San Miguel del Sur SAC (Kola Real)
  </p>
  <p>
    Este sistema gestiona el registro de sobretiempos (horas extras) de los trabajadores de forma automática, 
    permitiendo un control preciso y eficiente de las remuneraciones extraordinarias.
  </p>
</div>
