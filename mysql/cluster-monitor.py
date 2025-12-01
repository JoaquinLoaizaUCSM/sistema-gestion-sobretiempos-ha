# MySQL Shell Python script for continuous cluster monitoring and auto-healing
# Robust version for Single Node Survival + Router Update

import os
import time
import json
import sys

def getenv(name, defVal):
    return os.getenv(name, defVal)

root_pwd = getenv('MYSQL_ROOT_PASSWORD', '1234')
monitor_interval = max(5, int(getenv('MONITOR_INTERVAL', '10')))
preferred_primary = getenv('PREFERRED_PRIMARY', 'mysql1:3306')

inst1 = f"root:{root_pwd}@mysql1:3306"
inst2 = f"root:{root_pwd}@mysql2:3306"
inst3 = f"root:{root_pwd}@mysql3:3306"
instances = [inst1, inst2, inst3]

print(f"\n=== Cluster Monitor Started (Python Mode) ===")
print(f"Monitor interval: {monitor_interval} seconds")

def safe_connect(uri):
    try:
        shell.connect(uri)
        return True
    except Exception as e:
        return False

def update_router_state_json(available_nodes):
    state_file = '/router-state/data/state.json'
    gr_id = 'b8a8a597-b9a2-11f0-bd5b-e63917e32565'
    
    server_list = ",\n".join([f'            "mysql://{node}"' for node in available_nodes])
    
    state_json = f'''{{
    "metadata-cache": {{
        "group-replication-id": "{gr_id}",
        "cluster-metadata-servers": [
{server_list}
        ]
    }},
    "version": "1.0.0"
}}'''

    try:
        with open(state_file, 'w') as f:
            f.write(state_json)
        print(f"[Monitor] Updated router state.json with nodes: {', '.join(available_nodes)}")
    except Exception as e:
        print(f"[Monitor] Failed to write router state: {e}")

def check_and_heal_cluster():
    cluster = None
    connected_uri = None

    # 1. Try to connect to ANY reachable node and get the cluster
    for uri in instances:
        if safe_connect(uri):
            try:
                cluster = dba.get_cluster('myCluster')
                connected_uri = uri
                host = uri.split('@')[1]
                print(f"[Monitor] Connected to cluster via {host}")
                break
            except Exception as e:
                msg = str(e)
                host = uri.split('@')[1]
                if 'Metadata schema not found' not in msg:
                    print(f"[Monitor] Connected to {host} but could not get cluster: {msg}")

    if not cluster:
        print('[Monitor] ⚠️  Cluster object not accessible via standard get_cluster().')
        
        try:
            print('[Monitor] Attempting reboot_cluster_from_complete_outage...')
            dba.reboot_cluster_from_complete_outage('myCluster', {'force': True})
            print('[Monitor] ✅ Cluster rebooted successfully!')
            return
        except Exception as e:
            print(f'[Monitor] Reboot failed: {e}')
        
        return

    # 2. Check Cluster Status
    try:
        status = cluster.status()
        replica_set = status.get('defaultReplicaSet', {})
        cluster_status = replica_set.get('status', 'UNKNOWN')
        topology = replica_set.get('topology', {})
        
        print(f"[Monitor] Cluster status: {cluster_status}")

        # Update Router State with ALL online nodes
        try:
            online_node_addrs = []
            for node in topology.values():
                if node.get('status') in ['ONLINE', 'RECOVERING']:
                    online_node_addrs.append(node.get('address'))
            
            if online_node_addrs:
                update_router_state_json(online_node_addrs)
        except Exception as e:
            print(f'[Monitor] Error updating router state: {e}')

        if cluster_status in ['OK', 'OK_NO_TOLERANCE']:
            return

        if cluster_status == 'NO_QUORUM':
            print('[Monitor] ⚠️  NO_QUORUM detected. Checking available nodes...')
            
            online_nodes = [n for n in topology.values() if n.get('status') == 'ONLINE']
            
            if len(online_nodes) == 1:
                node = online_nodes[0]
                node_addr = node.get('address')
                print(f"[Monitor] 🚨 Single node survival mode: Forcing quorum on {node_addr}...")
                
                try:
                    cluster.force_quorum_using_partition_of(node_addr)
                    print(f"[Monitor] ✅ Quorum forced successfully on {node_addr}")
                except Exception as e:
                    print(f"[Monitor] ❌ Failed to force quorum: {e}")
            else:
                if connected_uri:
                    host = connected_uri.split('@')[1]
                    print(f"[Monitor] Attempting to force quorum on current connection: {host}")
                    try:
                        cluster.force_quorum_using_partition_of(host)
                        print(f"[Monitor] ✅ Quorum forced successfully on {host}")
                    except Exception as e:
                        print(f"[Monitor] ❌ Failed to force quorum: {e}")

    except Exception as e:
        print(f'[Monitor] Error checking/healing status: {e}')

# Main loop
while True:
    try:
        check_and_heal_cluster()
    except Exception as e:
        print(f'[Monitor] Unexpected error in main loop: {e}')
    time.sleep(monitor_interval)
