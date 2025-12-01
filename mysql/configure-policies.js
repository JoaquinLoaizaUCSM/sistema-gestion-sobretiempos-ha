// Script to configure advanced cluster policies for automatic failback
// This sets up the cluster to prefer mysql1 as PRIMARY when it recovers

(function () {
  function getenv(name, defVal) {
    try { return shell.env[name] || defVal; } catch (e) { return defVal; }
  }

  const rootPwd = getenv('MYSQL_ROOT_PASSWORD', '1234');
  const inst1 = `root:${rootPwd}@mysql1:3306`;
  const preferredPrimary = getenv('PREFERRED_PRIMARY', 'mysql1:3306');
  const desiredWeights = {
    'mysql1:3306': 60,
    'mysql2:3306': 60,
    'mysql3:3306': 60
  };
  desiredWeights[preferredPrimary] = 100;

  print('\n=== Configuring Cluster Advanced Policies ===\n');

  // Connect to mysql1 if possible, otherwise any available node
  try {
    shell.connect(inst1);
  } catch (e) {
    print('Cannot connect to mysql1, will configure later when available');
    return;
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

  function setWeightIfNeeded(clusterRef, instance, weight, topology) {
    const entry = findTopologyEntry(topology, instance);
    if (!entry) {
      print(`   - Note: ${instance} aún no está en el clúster (se aplicará luego)`);
      return;
    }
    if (Number(entry.memberWeight) === Number(weight)) {
      print(`   - ${instance}: peso=${weight} (sin cambios)`);
      return;
    }
    clusterRef.setInstanceOption(instance, 'memberWeight', weight);
    print(`   - ${instance}: peso actualizado a ${weight}`);
  }

  function enforcePreferredPrimary(clusterRef, statusSnapshot) {
    const topology = statusSnapshot.defaultReplicaSet ? statusSnapshot.defaultReplicaSet.topology : null;
    const preferredEntry = findTopologyEntry(topology, preferredPrimary);
    const currentPrimary = statusSnapshot.defaultReplicaSet ? statusSnapshot.defaultReplicaSet.primary : null;
    if (!preferredEntry || preferredEntry.status !== 'ONLINE') {
      print(`   - PRIMARY preferido (${preferredPrimary}) no está ONLINE (estado actual: ${preferredEntry ? preferredEntry.status : 'desconocido'})`);
      return;
    }
    if (currentPrimary === preferredPrimary) {
      print(`   - PRIMARY actual ya es ${preferredPrimary}`);
      return;
    }
    try {
      clusterRef.setPrimaryInstance(preferredPrimary);
      print(`   - PRIMARY actualizado a ${preferredPrimary}`);
    } catch (e) {
      print('   - Nota: no se pudo cambiar el PRIMARY preferido: ' + e);
    }
  }

  let cluster;
  try {
    cluster = dba.getCluster('myCluster');
  } catch (e) {
    print('Cluster not accessible yet. This is normal on first setup.');
    return;
  }

  try {
    let status = cluster.status();
    let topology = status.defaultReplicaSet ? status.defaultReplicaSet.topology : null;
    const clusterStatus = status.defaultReplicaSet ? status.defaultReplicaSet.status : 'UNKNOWN';
    
    print(`Estado actual del cluster: ${clusterStatus}`);
    
    // Contar nodos online
    const onlineNodes = Object.keys(topology || {}).filter(key => {
      const node = topology[key];
      return node.status === 'ONLINE';
    });
    
    print(`Nodos ONLINE: ${onlineNodes.length} de ${Object.keys(topology || {}).length}`);

    // Si hay NO_QUORUM con solo 1 nodo, intentar forzar quorum
    if (clusterStatus === 'NO_QUORUM' && onlineNodes.length === 1) {
      print('⚠️  Detectado NO_QUORUM con 1 solo nodo, forzando quorum...');
      const singleNodeKey = onlineNodes[0];
      const singleNode = topology[singleNodeKey];
      const singleNodeAddr = singleNode.address || singleNodeKey;
      
      try {
        cluster.forceQuorumUsingPartitionOf(singleNodeAddr);
        print(`✅ Quorum forzado en nodo único: ${singleNodeAddr}`);
        
        // Esperar y refrescar estado
        const sleep = function(seconds) { os.sleep(seconds); };
        sleep(3);
        status = cluster.status();
        topology = status.defaultReplicaSet ? status.defaultReplicaSet.topology : null;
      } catch (forceErr) {
        print('⚠️  No se pudo forzar quorum: ' + forceErr);
      }
    }

    print('Resincronizando topología del clúster...');
    try {
      cluster.rescan({addInstances: 'auto', removeInstances: 'auto'});
    } catch (rescanErr) {
      print('Nota: rescan falló (se ignorará): ' + rescanErr);
    }

    try {
      status = cluster.status();
      topology = status.defaultReplicaSet ? status.defaultReplicaSet.topology : null;
    } catch (statusRefreshErr) {
      print('Nota: no se pudo refrescar el estado tras rescan: ' + statusRefreshErr);
    }

    print('✅ Pesos de miembros (memberWeight):');
    Object.entries(desiredWeights).forEach(([instance, weight]) => {
      try {
        setWeightIfNeeded(cluster, instance, weight, topology);
      } catch (weightErr) {
        print(`   - Nota: no se pudo ajustar el peso de ${instance}: ${weightErr}`);
      }
    });

    print('✅ Opciones del clúster:');
    try {
      const options = cluster.options();
      if (options.autoRejoinTries !== 2016) {
        cluster.setOption('autoRejoinTries', 2016);
        print('   - autoRejoinTries establecido en 2016');
      } else {
        print('   - autoRejoinTries ya estaba en 2016');
      }
      if (options.expelTimeout !== 3600) {
        cluster.setOption('expelTimeout', 3600);
        print('   - expelTimeout establecido en 3600');
      } else {
        print('   - expelTimeout ya estaba en 3600');
      }
      if (options.exitStateAction !== 'READ_ONLY') {
        cluster.setOption('exitStateAction', 'READ_ONLY');
        print('   - exitStateAction establecido en READ_ONLY');
      } else {
        print('   - exitStateAction ya estaba en READ_ONLY');
      }
      if (options.consistency !== 'EVENTUAL') {
        cluster.setOption('consistency', 'EVENTUAL');
        print('   - consistency establecido en EVENTUAL');
      } else {
        print('   - consistency ya estaba en EVENTUAL');
      }
    } catch (optionErr) {
      print('   - Nota: no se pudieron leer/ajustar opciones: ' + optionErr);
    }

    print('✅ PRIMARY preferido:');
    enforcePreferredPrimary(cluster, status);
  } catch (e) {
    print('Nota: error aplicando políticas del clúster: ' + e);
  }

  print('\n=== Cluster Policy Configuration Complete ===\n');
})();
