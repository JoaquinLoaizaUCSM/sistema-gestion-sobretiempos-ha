// MySQL Shell JS script to bootstrap an InnoDB Cluster
// Idempotent: safe to re-run

(function () {
  function getenv(name, defVal) {
    try { return shell.env[name] || defVal; } catch (e) { return defVal; }
  }

  const rootPwd = getenv('MYSQL_ROOT_PASSWORD', '1234');
  const appDb = getenv('APP_DB', 'appdb');
  const appUser = getenv('APP_USER', 'app');
  const appPwd = getenv('APP_PASSWORD', '1234');

  const inst1 = `root:${rootPwd}@mysql1:3306`;
  const inst2 = `root:${rootPwd}@mysql2:3306`;
  const inst3 = `root:${rootPwd}@mysql3:3306`;
  const preferredPrimary = getenv('PREFERRED_PRIMARY', 'mysql1:3306');
  const desiredInstanceWeights = {
    'mysql1:3306': 50,
    'mysql2:3306': 50,
    'mysql3:3306': 50
  };
  desiredInstanceWeights[preferredPrimary] = 100;

  print('Configuring instances for Group Replication...');
  try { dba.configureInstance(inst1); } catch (e) { print('configureInstance mysql1: ' + e); }
  try { dba.configureInstance(inst2); } catch (e) { print('configureInstance mysql2: ' + e); }
  try { dba.configureInstance(inst3); } catch (e) { print('configureInstance mysql3: ' + e); }

  // Connect to the primary instance
  try {
    const currentSession = shell.getSession();
    if (!currentSession || currentSession.uri.indexOf('mysql1') === -1) {
      print('Connecting to mysql1...');
      shell.connect(inst1);
    }
  } catch (e) {
    print('Connecting to mysql1...');
    shell.connect(inst1);
  }

  let cluster;
  try {
    cluster = dba.getCluster('myCluster');
    print('Existing cluster found: myCluster');
    // Rescan to update metadata with any instances that joined but aren't in metadata
    try {
      print('Rescanning cluster to update metadata...');
      cluster.rescan({ addInstances: 'auto', removeInstances: 'auto' });
    } catch (e) {
      print('Rescan note: ' + e);
    }
  } catch (e) {
    print('Cluster not found or not accessible. Error: ' + e);
    // Check if metadata exists but cluster is not running
    try {
      print('Attempting to reboot cluster from complete outage...');
      cluster = dba.rebootClusterFromCompleteOutage('myCluster', { force: true });
      print('Cluster rebooted successfully from complete outage.');
    } catch (rebootErr) {
      print('Reboot failed or not needed. Error: ' + rebootErr);

      // Check if metadata is corrupted (exists but GR not active)
      const errorMsg = String(rebootErr);
      if (errorMsg.indexOf('metadata exists') !== -1 || errorMsg.indexOf('not configured properly') !== -1) {
        print('Detected corrupted metadata. Cleaning up...');
        try {
          dba.dropMetadataSchema({ force: true });
          print('Metadata cleaned. Creating new cluster...');
        } catch (dropErr) {
          print('Warning: Could not drop metadata: ' + dropErr);
        }
      }

      // Try to create new cluster
      print('Creating new cluster: myCluster');
      try {
        cluster = dba.createCluster('myCluster', {
          autoRejoinTries: 2016,              // Máximo permitido: 2016 intentos
          expelTimeout: 3600,                  // Esperar 1 hora antes de expulsar un nodo
          consistency: 'EVENTUAL',             // Permitir lecturas eventuales durante failover
          exitStateAction: 'READ_ONLY',        // Modo read-only si sale del cluster
          memberWeight: 50,                    // Peso balanceado (no aplica en multi-primary)
          multiPrimary: true,                  // Multi-primary mode: TODOS pueden escribir
          force: true,                         // Forzar creación si es necesario
          clearReadOnly: true,                 // Limpiar read-only mode si existe
          groupName: 'b8a8a597-b9a2-11f0-bd5b-e63917e32565'  // GR ID consistente para Router
        });
        print('✅ Cluster created successfully');
      } catch (createErr) {
        print('ERROR: Cannot create cluster: ' + createErr);
        print('If metadata exists, you may need to run: dba.dropMetadataSchema()');
        throw createErr;
      }
    }
  }

  function setInstanceWeight(clusterRef, instance, weight) {
    try {
      clusterRef.setInstanceOption(instance, 'memberWeight', weight);
      print(`Instance weight enforced: ${instance} -> ${weight}`);
    } catch (e) {
      print(`Note: could not set weight for ${instance}: ${e}`);
    }
  }

  function findTopologyEntry(topology, hostPort) {
    if (!topology) {
      return null;
    }
    if (topology[hostPort]) {
      return topology[hostPort];
    }
    const matchingKey = Object.keys(topology).find(key => key.endsWith(hostPort));
    return matchingKey ? topology[matchingKey] : null;
  }

  function enforceClusterPolicies(clusterRef) {
    try {
      const options = clusterRef.options();
      if (options.autoRejoinTries !== 2016) {
        clusterRef.setOption('autoRejoinTries', 2016);
        print('Cluster option autoRejoinTries set to 2016');
      }
      if (options.expelTimeout !== 3600) {
        clusterRef.setOption('expelTimeout', 3600);
        print('Cluster option expelTimeout set to 3600');
      }
      if (options.exitStateAction !== 'READ_ONLY') {
        clusterRef.setOption('exitStateAction', 'READ_ONLY');
        print('Cluster option exitStateAction set to READ_ONLY');
      }
      if (options.consistency !== 'EVENTUAL') {
        clusterRef.setOption('consistency', 'EVENTUAL');
        print('Cluster option consistency set to EVENTUAL');
      }
    } catch (e) {
      print('Note: could not enforce cluster options: ' + e);
    }

    try {
      const statusSnapshot = clusterRef.status();
      const topology = statusSnapshot.defaultReplicaSet ? statusSnapshot.defaultReplicaSet.topology : null;
      Object.entries(desiredInstanceWeights).forEach(([instance, weight]) => {
        const entry = findTopologyEntry(topology, instance);
        if (!entry || Number(entry.memberWeight) === Number(weight)) {
          if (!entry) {
            print(`Note: instance ${instance} not found in topology while enforcing weight`);
          }
          return;
        }
        setInstanceWeight(clusterRef, instance, weight);
      });

      const currentPrimary = statusSnapshot.defaultReplicaSet ? statusSnapshot.defaultReplicaSet.primary : null;
      const preferredEntry = findTopologyEntry(topology, preferredPrimary);
      if (preferredEntry && preferredEntry.status === 'ONLINE' && currentPrimary !== preferredPrimary) {
        try {
          clusterRef.setPrimaryInstance(preferredPrimary);
          print(`PRIMARY switched to preferred instance ${preferredPrimary}`);
        } catch (primaryErr) {
          print('Note: could not switch PRIMARY to preferred instance: ' + primaryErr);
        }
      }
    } catch (statusErr) {
      print('Note: could not inspect topology for policy enforcement: ' + statusErr);
    }
  }

  function addIfMissing(uri) {
    try {
      // Check if instance is already in the cluster
      const status = cluster.status();
      const topology = status.defaultReplicaSet.topology;
      const host = uri.split('@')[1]; // Extract host:port from uri

      for (const [key, value] of Object.entries(topology)) {
        if (key.includes(host) || value.address === host) {
          return;
        }
      }

      // Instance not in cluster, add it
      print(`Adding instance ${host} to cluster...`);
      cluster.addInstance(uri, {
        recoveryMethod: 'clone',
        autoRejoinTries: 2016,
        exitStateAction: 'READ_ONLY',
        memberSslMode: 'REQUIRED',
        waitRecovery: 2  // Wait up to 2 seconds for recovery to start
      });
      print('✅ Added instance to cluster: ' + uri);

      // Esperar un momento para que la instancia se estabilice
      os.sleep(2);

      const hostPort = uri.split('@')[1];
      if (desiredInstanceWeights[hostPort]) {
        setInstanceWeight(cluster, hostPort, desiredInstanceWeights[hostPort]);
      }
    } catch (e) {
      const msg = (e && e.message) ? e.message : String(e);
      if (msg.match(/is already part of the InnoDB cluster|The instance .* belongs to the cluster|already a member/i)) {
        print('Instance already in cluster: ' + uri);

        // Intentar rejoin si está en metadata pero offline
        try {
          print('Attempting rejoin for instance that is in metadata...');
          cluster.rejoinInstance(uri, { memberSslMode: 'REQUIRED' });
          print('✅ Instance rejoined successfully');
        } catch (rejoinErr) {
          print('Note: rejoin failed or not needed: ' + rejoinErr);
        }
      } else {
        print('⚠️  Error adding instance ' + uri + ': ' + msg);
        // Don't throw, continue with other instances
      }
    }
  }

  addIfMissing(inst2);
  addIfMissing(inst3);

  enforceClusterPolicies(cluster);

  print('Cluster status:');
  let cachedStatus = null;
  try {
    cachedStatus = cluster.status();
    print(JSON.stringify(cachedStatus, null, 2));
  } catch (e) {
    print('status error: ' + e);
  }

  // Always run schema operations against the current PRIMARY to avoid super_read_only blocks
  const primaryHostPort = (cachedStatus && cachedStatus.defaultReplicaSet && cachedStatus.defaultReplicaSet.primary)
    ? cachedStatus.defaultReplicaSet.primary.replace(/^[^@]*@/, '')
    : preferredPrimary;
  const primaryUri = `root:${rootPwd}@${primaryHostPort}`;

  print(`Creating application database and user on PRIMARY (${primaryHostPort})...`);
  let appSession = null;
  try {
    try {
      appSession = mysql.getSession(primaryUri);
    } catch (primaryErr) {
      print('Warning: could not open dedicated session to PRIMARY, falling back to current session: ' + primaryErr);
      appSession = shell.getSession();
    }

    appSession.runSql(`CREATE DATABASE IF NOT EXISTS \`${appDb}\``);
    appSession.runSql(`CREATE USER IF NOT EXISTS '${appUser}'@'%' IDENTIFIED BY '${appPwd}'`);
    appSession.runSql(`GRANT ALL PRIVILEGES ON \`${appDb}\`.* TO '${appUser}'@'%'`);
    // Allow the application user to inspect replication metadata to show PRIMARY/SECONDARY status
    appSession.runSql(`GRANT SELECT ON performance_schema.replication_group_members TO '${appUser}'@'%'`);
    appSession.runSql('FLUSH PRIVILEGES');

    // Create tables for overtime tracking system (Sistema de Registro de Sobretiempos)
    print('Creating overtime tracking database schema...');

    // Use database
    appSession.runSql(`USE \`${appDb}\``);

    // Drop tables if they exist (reverse order for dependencies)
    appSession.runSql('DROP TABLE IF EXISTS reporte_asistencia');
    appSession.runSql('DROP TABLE IF EXISTS empleados');
    appSession.runSql('DROP TABLE IF EXISTS area');
    appSession.runSql('DROP TABLE IF EXISTS centro_coste');
    appSession.runSql('DROP TABLE IF EXISTS turnos');

    // Create centro_coste table
    appSession.runSql(`
      CREATE TABLE centro_coste (
        codigo_centroCoste CHAR(8) PRIMARY KEY,
        centro_coste VARCHAR(50) NOT NULL
      ) ENGINE=InnoDB
    `);

    // Create area table
    appSession.runSql(`
      CREATE TABLE area (
        puesto CHAR(80) PRIMARY KEY,
        unidad_organizativa VARCHAR(50) NOT NULL
      ) ENGINE=InnoDB
    `);

    // Create turnos table
    appSession.runSql(`
      CREATE TABLE turnos (
        codigo_turno CHAR(3) PRIMARY KEY,
        hora_entrada TIME NOT NULL,
        hora_salida TIME NOT NULL
      ) ENGINE=InnoDB
    `);

    // Create empleados table
    appSession.runSql(`
      CREATE TABLE empleados (
        codigo CHAR(6) PRIMARY KEY,
        puesto_area CHAR(80) NOT NULL,
        Codigo_CentroCoste CHAR(8) NOT NULL,
        nombre VARCHAR(80) NOT NULL,
        dni CHAR(8) UNIQUE NOT NULL,
        subdivision VARCHAR(100),
        FOREIGN KEY (Codigo_CentroCoste) REFERENCES centro_coste(codigo_centroCoste),
        FOREIGN KEY (puesto_area) REFERENCES area(puesto),
        INDEX idx_nombre_empleado (nombre),
        INDEX idx_dni_empleado (dni)
      ) ENGINE=InnoDB
    `);

    // Create reporte_asistencia table
    appSession.runSql(`
      CREATE TABLE reporte_asistencia (
        fecha DATE,
        codigo_empleado CHAR(6),
        codigo_turno CHAR(3) NOT NULL,
        dia VARCHAR(15) NOT NULL,
        marca_entrada TIME NULL,
        marca_salida TIME NULL,
        H25 DECIMAL(5,2) DEFAULT 0,
        H35 DECIMAL(5,2) DEFAULT 0,
        H100 DECIMAL(5,2) DEFAULT 0,
        PRIMARY KEY (fecha, codigo_empleado),
        FOREIGN KEY (codigo_empleado) REFERENCES empleados(codigo),
        FOREIGN KEY (codigo_turno) REFERENCES turnos(codigo_turno),
        INDEX idx_fecha_asistencia (fecha),
        INDEX idx_empleado_fecha (codigo_empleado, fecha)
      ) ENGINE=InnoDB
    `);

    print('Inserting initial data...');

    // Insert centros de coste
    appSession.runSql(`
      INSERT INTO centro_coste (codigo_centroCoste, centro_coste) VALUES
      ('CC-ADM01', 'Administración y Finanzas'),
      ('CC-VTS01', 'Ventas y Marketing'),
      ('CC-OPE01', 'Operaciones y Logística'),
      ('CC-TEC01', 'Tecnología de la Información'),
      ('CC-RH01', 'Recursos Humanos')
    `);

    // Insert areas
    appSession.runSql(`
      INSERT INTO area (puesto, unidad_organizativa) VALUES
      ('Gerente General', 'Gerencia'),
      ('Contador General', 'Administración y Finanzas'),
      ('Asistente Contable', 'Administración y Finanzas'),
      ('Analista Financiero', 'Administración y Finanzas'),
      ('Jefe de Ventas', 'Ventas y Marketing'),
      ('Ejecutivo de Cuentas', 'Ventas y Marketing'),
      ('Especialista en Marketing Digital', 'Ventas y Marketing'),
      ('Jefe de Almacén', 'Operaciones y Logística'),
      ('Operario de Almacén', 'Operaciones y Logística'),
      ('Coordinador de Despachos', 'Operaciones y Logística'),
      ('Gerente de TI', 'Tecnología de la Información'),
      ('Desarrollador Senior', 'Tecnología de la Información'),
      ('Desarrollador Junior', 'Tecnología de la Información'),
      ('Soporte Técnico Nivel 1', 'Tecnología de la Información'),
      ('Jefe de Recursos Humanos', 'Recursos Humanos'),
      ('Analista de Reclutamiento', 'Recursos Humanos')
    `);

    // Insert turnos
    appSession.runSql(`
      INSERT INTO turnos (codigo_turno, hora_entrada, hora_salida) VALUES
      ('M01', '08:00:00', '17:00:00'),
      ('M02', '09:00:00', '18:00:00'),
      ('T01', '14:00:00', '22:00:00'),
      ('N01', '22:00:00', '06:00:00'),
      ('DES', '00:00:00', '00:00:00')
    `);

    // Insert sample employees
    print('Inserting sample employees...');
    appSession.runSql(`
      INSERT INTO empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES
      ('E001', 'Juan Carlos Pérez López', '45678901', 'Operario de Almacén', 'CC-OPE01', 'Planta Norte'),
      ('E002', 'María Fernanda García Torres', '46789012', 'Contador General', 'CC-ADM01', 'Sede Central'),
      ('E003', 'Pedro Antonio Rodríguez Sánchez', '47890123', 'Jefe de Almacén', 'CC-OPE01', 'Planta Norte'),
      ('E004', 'Ana Lucía Martínez Flores', '48901234', 'Analista de Reclutamiento', 'CC-RH01', 'Sede Central'),
      ('E005', 'Carlos Eduardo Ramírez González', '49012345', 'Soporte Técnico Nivel 1', 'CC-TEC01', 'Planta Sur'),
      ('E006', 'Rosa María Gutiérrez Castro', '50123456', 'Asistente Contable', 'CC-ADM01', 'Sede Central'),
      ('E007', 'José Luis Hernández Vargas', '51234567', 'Operario de Almacén', 'CC-OPE01', 'Planta Norte'),
      ('E008', 'Carmen Elena Díaz Morales', '52345678', 'Jefe de Ventas', 'CC-VTS01', 'Zona Norte'),
      ('E009', 'Miguel Ángel Torres Ruiz', '53456789', 'Coordinador de Despachos', 'CC-OPE01', 'Almacén Central'),
      ('E010', 'Patricia Isabel Flores Mendoza', '54567890', 'Analista Financiero', 'CC-ADM01', 'Sede Central'),
      ('E011', 'Roberto Carlos Méndez Silva', '55678901', 'Operario de Almacén', 'CC-OPE01', 'Planta Sur'),
      ('E012', 'Sofía Alexandra Castro Jiménez', '56789012', 'Desarrollador Junior', 'CC-TEC01', 'Sede Central'),
      ('E013', 'Fernando José Ramos Ortiz', '57890123', 'Ejecutivo de Cuentas', 'CC-VTS01', 'Zona Sur'),
      ('E014', 'Claudia Patricia Vega Romero', '58901234', 'Jefe de Recursos Humanos', 'CC-RH01', 'Sede Central'),
      ('E015', 'Daniel Alejandro Cruz Navarro', '59012345', 'Gerente de TI', 'CC-TEC01', 'Planta Sur')
    `);

    // Insert sample attendance records
    print('Inserting sample attendance records...');
    appSession.runSql(`
      INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
      ('2024-10-01', 'E001', 'M01', 'Martes', '08:00:00', '19:00:00', 2.0, 0, 0),
      ('2024-10-01', 'E003', 'M01', 'Martes', '08:00:00', '18:30:00', 1.5, 0, 0),
      ('2024-10-01', 'E007', 'M01', 'Martes', '08:00:00', '17:00:00', 0, 0, 0),
      ('2024-10-01', 'E002', 'M02', 'Martes', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-01', 'E005', 'T01', 'Martes', '14:00:00', '23:30:00', 1.5, 0, 0),
      ('2024-10-02', 'E001', 'M01', 'Miércoles', '08:00:00', '17:00:00', 0, 0, 0),
      ('2024-10-02', 'E003', 'M01', 'Miércoles', '08:00:00', '20:00:00', 2.0, 1.0, 0),
      ('2024-10-02', 'E007', 'M01', 'Miércoles', '08:00:00', '17:30:00', 0.5, 0, 0),
      ('2024-10-02', 'E008', 'M02', 'Miércoles', '09:00:00', '19:30:00', 1.5, 0, 0),
      ('2024-10-02', 'E009', 'T01', 'Miércoles', '14:00:00', '22:00:00', 0, 0, 0),
      ('2024-10-03', 'E001', 'M01', 'Jueves', '08:00:00', '18:00:00', 1.0, 0, 0),
      ('2024-10-03', 'E003', 'M01', 'Jueves', '08:00:00', '17:00:00', 0, 0, 0),
      ('2024-10-03', 'E007', 'M01', 'Jueves', '08:00:00', '19:30:00', 2.0, 0.5, 0),
      ('2024-10-03', 'E010', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-03', 'E011', 'N01', 'Jueves', '22:00:00', '06:00:00', 0, 0, 0),
      ('2024-10-04', 'E001', 'M01', 'Viernes', '08:00:00', '17:00:00', 0, 0, 0),
      ('2024-10-04', 'E003', 'M01', 'Viernes', '08:00:00', '19:00:00', 2.0, 0, 0),
      ('2024-10-04', 'E007', 'M01', 'Viernes', '08:00:00', '18:00:00', 1.0, 0, 0),
      ('2024-10-04', 'E012', 'M02', 'Viernes', '09:00:00', '20:00:00', 2.0, 0, 0),
      ('2024-10-04', 'E013', 'T01', 'Viernes', '14:00:00', '23:00:00', 1.0, 0, 0),
      ('2024-10-05', 'E001', 'M01', 'Sábado', '08:00:00', '17:00:00', 0, 9.0, 0),
      ('2024-10-05', 'E003', 'M01', 'Sábado', '08:00:00', '14:00:00', 0, 6.0, 0),
      ('2024-10-05', 'E007', 'M01', 'Sábado', '08:00:00', '17:00:00', 0, 9.0, 0),
      ('2024-10-08', 'E001', 'M01', 'Martes', '08:00:00', '17:00:00', 0, 0, 9.0),
      ('2024-10-08', 'E005', 'M01', 'Martes', '08:00:00', '14:00:00', 0, 0, 6.0),
      ('2024-10-07', 'E001', 'M01', 'Lunes', '08:00:00', '17:00:00', 0, 0, 0),
      ('2024-10-07', 'E002', 'M02', 'Lunes', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-07', 'E003', 'M01', 'Lunes', '08:00:00', '18:30:00', 1.5, 0, 0),
      ('2024-10-07', 'E004', 'M02', 'Lunes', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-07', 'E005', 'T01', 'Lunes', '14:00:00', '22:00:00', 0, 0, 0),
      ('2024-10-09', 'E001', 'M01', 'Miércoles', '08:00:00', '19:00:00', 2.0, 0, 0),
      ('2024-10-09', 'E006', 'M02', 'Miércoles', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-09', 'E007', 'M01', 'Miércoles', '08:00:00', '17:00:00', 0, 0, 0),
      ('2024-10-09', 'E008', 'M02', 'Miércoles', '09:00:00', '20:00:00', 2.0, 0, 0),
      ('2024-10-10', 'E003', 'M01', 'Jueves', '08:00:00', '20:00:00', 2.0, 1.0, 0),
      ('2024-10-10', 'E009', 'T01', 'Jueves', '14:00:00', '23:00:00', 1.0, 0, 0),
      ('2024-10-10', 'E010', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-11', 'E001', 'M01', 'Viernes', '08:00:00', '18:00:00', 1.0, 0, 0),
      ('2024-10-11', 'E011', 'M01', 'Viernes', '08:00:00', '19:30:00', 2.0, 0.5, 0),
      ('2024-10-11', 'E012', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-14', 'E013', 'M02', 'Lunes', '09:00:00', '19:00:00', 1.0, 0, 0),
      ('2024-10-14', 'E014', 'M02', 'Lunes', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-14', 'E015', 'M01', 'Lunes', '08:00:00', '18:30:00', 1.5, 0, 0),
      ('2024-10-15', 'E013', 'M02', 'Martes', '09:00:00', '20:00:00', 2.0, 0, 0),
      ('2024-10-15', 'E014', 'M02', 'Martes', '09:00:00', '18:00:00', 0, 0, 0),
      ('2024-10-15', 'E015', 'M01', 'Martes', '08:00:00', '17:00:00', 0, 0, 0)
    `);

    print('Database schema and sample data created successfully.');
  } finally {
    // Close extra session if we created one explicitly
    try {
      if (appSession && appSession !== shell.getSession()) {
        appSession.close();
      }
    } catch (closeErr) {
      print('Warning: error closing PRIMARY session: ' + closeErr);
    }
  }

  print('InnoDB Cluster bootstrap complete.');
})();
