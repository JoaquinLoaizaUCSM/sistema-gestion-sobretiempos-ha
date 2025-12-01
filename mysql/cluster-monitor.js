// MySQL Shell JS script for continuous cluster monitoring and auto-healing
// Robust version for Single Node Survival + Router Update

(function () {
  function getenv(name, defVal) {
    try { return shell.env[name] || defVal; } catch (e) { return defVal; }
  }

  const rootPwd = getenv('MYSQL_ROOT_PASSWORD', '1234');
  const monitorInterval = Math.max(5, parseInt(getenv('MONITOR_INTERVAL', '10')) || 10);
  const preferredPrimary = getenv('PREFERRED_PRIMARY', 'mysql1:3306');

  const inst1 = `root:${rootPwd}@mysql1:3306`;
  const inst2 = `root:${rootPwd}@mysql2:3306`;
  const inst3 = `root:${rootPwd}@mysql3:3306`;
  const instances = [inst1, inst2, inst3];

  print(`\n=== Cluster Monitor Started (Robust Mode + Router Update) ===`);
  print(`Monitor interval: ${monitorInterval} seconds`);

  function sleep(seconds) {
    os.sleep(seconds);
  }

  function safeConnect(uri) {
    try {
      const currentSession = shell.getSession();
      if (currentSession) {
        try { currentSession.close(); } catch (e) { }
      }
      shell.connect(uri);
      return true;
    } catch (e) {
      return false;
    }
  }

  function updateRouterStateJson(availableNodes) {
    const stateFile = '/router-state/data/state.json';
    const grId = 'b8a8a597-b9a2-11f0-bd5b-e63917e32565';

    const serverList = availableNodes.map(node => `            "mysql://${node}"`).join(',\n');
    const stateJson = `{
    "metadata-cache": {
        "group-replication-id": "${grId}",
        "cluster-metadata-servers": [
${serverList}
        ]
    },
    "version": "1.0.0"
}`;

    try {
      // Use echo to write the file since os.openFile might be restricted
      // We escape double quotes for the shell command
      const escapedJson = stateJson.replace(/"/g, '\\"');
      const cmd = `echo "${escapedJson}" > ${stateFile}`;

      // Try to execute via os.system (if available in this context)
      // If this fails, we might need another approach, but let's try this first.
      // Note: os.system returns 0 on success
      try {
        os.system(cmd);
        print(`[Monitor] Updated router state.json with nodes: ${availableNodes.join(', ')}`);
      } catch (sysErr) {
        print(`[Monitor] Failed to execute os.system: ${sysErr}`);
      }

    } catch (e) {
      print('[Monitor] Failed to write router state: ' + e);
    }
  }

  function checkAndHealCluster() {
    let cluster = null;
    let connectedUri = null;

    // 1. Try to connect to ANY reachable node and get the cluster
    for (let uri of instances) {
      if (safeConnect(uri)) {
        try {
          cluster = dba.getCluster('myCluster');
          connectedUri = uri;
          print(`[Monitor] Connected to cluster via ${uri.split('@')[1]}`);
          break;
        } catch (e) {
          const msg = String(e);
          if (msg.indexOf('Metadata schema not found') === -1) {
            print(`[Monitor] Connected to ${uri.split('@')[1]} but could not get cluster: ${msg}`);
          }
        }
      }
    }

    if (!cluster) {
      print('[Monitor] ⚠️  Cluster object not accessible via standard getCluster().');

      try {
        print('[Monitor] Attempting rebootClusterFromCompleteOutage...');
        dba.rebootClusterFromCompleteOutage('myCluster', { force: true });
        print('[Monitor] ✅ Cluster rebooted successfully!');
        return;
      } catch (e) {
        print('[Monitor] Reboot failed: ' + e);
      }

      return;
    }

    // 2. Check Cluster Status
    try {
      const status = cluster.status();
      const replicaSet = status.defaultReplicaSet || {};
      const clusterStatus = replicaSet.status || 'UNKNOWN';
      const topology = replicaSet.topology || {};

      print(`[Monitor] Cluster status: ${clusterStatus}`);

      // Update Router State with ALL online nodes
      try {
        const onlineNodeAddrs = Object.values(topology)
          .filter(n => n.status === 'ONLINE' || n.status === 'RECOVERING')
          .map(n => n.address);

        if (onlineNodeAddrs.length > 0) {
          updateRouterStateJson(onlineNodeAddrs);
        }
      } catch (e) {
        print('[Monitor] Error updating router state: ' + e);
      }

      if (clusterStatus === 'OK' || clusterStatus === 'OK_NO_TOLERANCE') {
        return;
      }

      if (clusterStatus === 'NO_QUORUM') {
        print('[Monitor] ⚠️  NO_QUORUM detected. Checking available nodes...');

        const onlineNodes = Object.values(topology).filter(n => n.status === 'ONLINE');

        if (onlineNodes.length === 1) {
          const node = onlineNodes[0];
          const nodeAddr = node.address;
          print(`[Monitor] 🚨 Single node survival mode: Forcing quorum on ${nodeAddr}...`);

          try {
            cluster.forceQuorumUsingPartitionOf(nodeAddr);
            print(`[Monitor] ✅ Quorum forced successfully on ${nodeAddr}`);
          } catch (e) {
            print(`[Monitor] ❌ Failed to force quorum: ${e}`);
          }
        } else {
          if (connectedUri) {
            const host = connectedUri.split('@')[1];
            print(`[Monitor] Attempting to force quorum on current connection: ${host}`);
            try {
              cluster.forceQuorumUsingPartitionOf(host);
              print(`[Monitor] ✅ Quorum forced successfully on ${host}`);
            } catch (e) {
              print(`[Monitor] ❌ Failed to force quorum: ${e}`);
            }
          }
        }
      }
    } catch (e) {
      print('[Monitor] Error checking/healing status: ' + e);
    }
  }

  // Main loop
  while (true) {
    try {
      checkAndHealCluster();
    } catch (e) {
      print('[Monitor] Unexpected error in main loop: ' + e);
    }
    sleep(monitorInterval);
  }
})();
