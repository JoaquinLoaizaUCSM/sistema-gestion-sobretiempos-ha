# 🏗️ Arquitectura del Sistema

## Índice

1. [Visión General](#visión-general)
2. [Arquitectura de Componentes](#arquitectura-de-componentes)
3. [Topología del Cluster MySQL](#topología-del-cluster-mysql)
4. [Flujo de Datos](#flujo-de-datos)
5. [Proceso de Failover](#proceso-de-failover)
6. [Auto-Recovery](#auto-recovery)
7. [Estados del Cluster](#estados-del-cluster)

---

## Visión General

**Modo Multi-Primary**: Todos los nodos pueden leer y escribir simultáneamente.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
graph LR
    subgraph "Internet/Usuarios"
        U[👤 Usuarios]
    end
    
    subgraph "Application Layer"
        WEB[Web App<br/>PHP 8.2<br/>:8091]
    end
    
    subgraph "Routing Layer"
        ROUTER[MySQL Router<br/>:6446 R/W<br/>:6447 R/W]
    end
    
    subgraph "Data Layer - InnoDB Cluster Multi-Primary"
        M1[(MySQL 1<br/>PRIMARY R/W)]
        M2[(MySQL 2<br/>PRIMARY R/W)]
        M3[(MySQL 3<br/>PRIMARY R/W)]
    end
    
    subgraph "Management Layer"
        INIT[Cluster Setup<br/>Inicialización]
        POL[Cluster Policies<br/>Configuración]
        MON[Cluster Monitor<br/>Auto-Recovery]
    end
    
    U -->|HTTP| WEB
    WEB -->|PDO MySQL| ROUTER
    ROUTER -->|Read/Write| M1
    ROUTER -->|Read/Write| M2
    ROUTER -->|Read/Write| M3
    
    INIT -.->|Bootstrap| M1
    INIT -.->|Add Instance| M2
    INIT -.->|Add Instance| M3
    POL -.->|Configure| M1
    MON -.->|Monitor Every 10s| M1
    MON -.->|Monitor| M2
    MON -.->|Monitor| M3
    
    M1 <-->|Group Replication<br/>Port 33061| M2
    M2 <-->|Group Replication<br/>Port 33061| M3
    M3 <-->|Group Replication<br/>Port 33061| M1
    
    style M1 fill:#238636,stroke:#2ea043,stroke-width:3px,color:#ffffff
    style M2 fill:#238636,stroke:#2ea043,stroke-width:3px,color:#ffffff
    style M3 fill:#238636,stroke:#2ea043,stroke-width:3px,color:#ffffff
    style ROUTER fill:#d29922,stroke:#d29922,stroke-width:3px,color:#ffffff
    style MON fill:#da3633,stroke:#f85149,stroke-width:3px,color:#ffffff
    style WEB fill:#1f6feb,stroke:#388bfd,stroke-width:2px,color:#ffffff
```

---

## Arquitectura de Componentes

### Stack Tecnológico

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
graph TB
    subgraph "Docker Containers"
        subgraph "Web Service"
            W[Apache 2.4 + PHP 8.2]
            WD[App Directory<br/>/var/www/html]
        end
        
        subgraph "MySQL Router Service"
            R[MySQL Router 8.0]
            RC[Config Volume<br/>router-conf]
        end
        
        subgraph "MySQL Cluster Services"
            M1C[MySQL 1 Container]
            M2C[MySQL 2 Container]
            M3C[MySQL 3 Container]
        end
        
        subgraph "Management Services"
            SETUP[cluster-setup<br/>One-time init]
            POLICIES[cluster-policies<br/>One-time config]
            MONITOR[cluster-monitor<br/>Always running]
        end
        
        subgraph "Persistent Volumes"
            V1[(mysql1-data)]
            V2[(mysql2-data)]
            V3[(mysql3-data)]
            VR[(router-conf)]
        end
    end
    
    W --> R
    R --> M1C
    R --> M2C
    R --> M3C
    
    M1C --> V1
    M2C --> V2
    M3C --> V3
    R --> VR
    
    SETUP -.->|Init Once| M1C
    POLICIES -.->|Configure Once| M1C
    MONITOR -.->|Monitor Always| M1C
    MONITOR -.->|Monitor Always| M2C
    MONITOR -.->|Monitor Always| M3C
    
    style W fill:#1f6feb,stroke:#388bfd,color:#ffffff
    style R fill:#d29922,stroke:#d29922,color:#ffffff
    style M1C fill:#238636,stroke:#2ea043,color:#ffffff
    style M2C fill:#238636,stroke:#2ea043,color:#ffffff
    style M3C fill:#238636,stroke:#2ea043,color:#ffffff
    style MONITOR fill:#da3633,stroke:#f85149,color:#ffffff
```

### Dependencias de Servicios

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
graph TD
    START([docker-compose up])
    
    START --> NETWORK[Create Network: backend]
    START --> VOLUMES[Create Volumes]
    
    NETWORK --> M1[Start MySQL 1]
    NETWORK --> M2[Start MySQL 2]
    NETWORK --> M3[Start MySQL 3]
    
    M1 -->|Health Check| M1H{MySQL 1<br/>Healthy?}
    M2 -->|Health Check| M2H{MySQL 2<br/>Healthy?}
    M3 -->|Health Check| M3H{MySQL 3<br/>Healthy?}
    
    M1H -->|Yes| SETUP[cluster-setup]
    M2H -->|Yes| SETUP
    M3H -->|Yes| SETUP
    
    SETUP -->|Success| BOOTSTRAP[router-bootstrap]
    SETUP -->|Success| POLICIES[cluster-policies]
    
    BOOTSTRAP -->|Success| ROUTER[mysql-router]
    POLICIES -->|Success| MONITOR[cluster-monitor]
    
    ROUTER -->|Health Check| RH{Router<br/>Healthy?}
    RH -->|Yes| WEB[web service]
    
    MONITOR -.->|Continuous| WATCH[Monitoring Loop<br/>Every 10s]
    
    style SETUP fill:#d29922,stroke:#d29922,color:#ffffff
    style MONITOR fill:#da3633,stroke:#f85149,color:#ffffff
    style ROUTER fill:#d29922,stroke:#d29922,color:#ffffff
    style WEB fill:#1f6feb,stroke:#388bfd,color:#ffffff
```

---

## Topología del Cluster MySQL

### Group Replication - Single Primary Mode

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
graph TB
    subgraph "MySQL InnoDB Cluster: myCluster"
        subgraph "PRIMARY Node"
            M1[MySQL 1<br/>mysql1:3306<br/>Server ID: 1<br/>Weight: 100<br/>GR Address: mysql1:33061]
            M1STATUS[Status: ONLINE<br/>Mode: R/W<br/>Role: PRIMARY]
        end
        
        subgraph "SECONDARY Nodes"
            M2[MySQL 2<br/>mysql2:3306<br/>Server ID: 2<br/>Weight: 60<br/>GR Address: mysql2:33061]
            M2STATUS[Status: ONLINE<br/>Mode: R/O<br/>Role: SECONDARY]
            
            M3[MySQL 3<br/>mysql3:3306<br/>Server ID: 3<br/>Weight: 60<br/>GR Address: mysql3:33061]
            M3STATUS[Status: ONLINE<br/>Mode: R/O<br/>Role: SECONDARY]
        end
        
        M1 -.->|Replicates to| M2
        M1 -.->|Replicates to| M3
        M2 -->|Heartbeat| M1
        M3 -->|Heartbeat| M1
        M2 <-->|P2P Communication| M3
    end
    
    M1 --> M1STATUS
    M2 --> M2STATUS
    M3 --> M3STATUS
    
    METADATA[(Metadata Schema<br/>mysql_innodb_cluster_metadata)]
    
    M1 --> METADATA
    M2 --> METADATA
    M3 --> METADATA
    
    style M1 fill:#238636,stroke:#2ea043,stroke-width:4px,color:#ffffff
    style M2 fill:#1f6feb,stroke:#388bfd,stroke-width:2px,color:#ffffff
    style M3 fill:#1f6feb,stroke:#388bfd,stroke-width:2px,color:#ffffff
    style M1STATUS fill:#238636,color:#ffffff
    style M2STATUS fill:#1f6feb,color:#ffffff
    style M3STATUS fill:#1f6feb,color:#ffffff
    style METADATA fill:#d29922,color:#ffffff
```

### Configuración de Group Replication

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
graph LR
    subgraph "Group Replication Configuration"
        CONFIG[Group Configuration]
        
        CONFIG --> MODE[Single Primary Mode: ON]
        CONFIG --> GROUP[Group Name:<br/>b8a8a597-b9a2-11f0-bd5b-e63917e32565]
        CONFIG --> SEEDS[Group Seeds:<br/>mysql1:33061<br/>mysql2:33061<br/>mysql3:33061]
        
        CONFIG --> BOOT[Bootstrap Group: OFF]
        CONFIG --> START[Start on Boot: ON]
        CONFIG --> REJOIN[Auto Rejoin Tries: 2016]
        CONFIG --> EXPEL[Expel Timeout: 3600s]
        CONFIG --> EXIT[Exit State Action: READ_ONLY]
        CONFIG --> CONS[Consistency: EVENTUAL]
    end
    
    style MODE fill:#238636,color:#ffffff
    style REJOIN fill:#d29922,color:#ffffff
    style EXPEL fill:#da3633,color:#ffffff
```

---

## Flujo de Datos

### Flujo de Escritura (INSERT/UPDATE/DELETE)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
sequenceDiagram
    participant User as 👤 Usuario
    participant Web as Web App
    participant Router as MySQL Router<br/>:6446 (RW)
    participant M1 as MySQL 1<br/>PRIMARY
    participant M2 as MySQL 2<br/>SECONDARY
    participant M3 as MySQL 3<br/>SECONDARY
    
    User->>Web: HTTP Request<br/>(Crear Asistencia)
    Web->>Router: INSERT INTO asistencias<br/>via PDO
    Router->>M1: Route to PRIMARY
    M1->>M1: Execute INSERT<br/>Generate GTID
    M1-->>M2: Replicate via GR
    M1-->>M3: Replicate via GR
    M2->>M2: Apply Transaction
    M3->>M3: Apply Transaction
    M2-->>M1: ACK
    M3-->>M1: ACK
    M1-->>Router: Success
    Router-->>Web: Query OK
    Web-->>User: 200 OK<br/>(Registro creado)
    
    Note over M1,M3: Group Replication ensures<br/>all nodes have same data
```

### Flujo de Lectura (SELECT)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
sequenceDiagram
    participant User as 👤 Usuario
    participant Web as Web App
    participant RouterRO as MySQL Router<br/>:6447 (RO)
    participant M2 as MySQL 2<br/>SECONDARY
    participant M3 as MySQL 3<br/>SECONDARY
    
    User->>Web: HTTP Request<br/>(Ver Dashboard)
    Web->>RouterRO: SELECT * FROM empleados
    
    alt Load Balance to MySQL 2
        RouterRO->>M2: Execute SELECT
        M2-->>RouterRO: Result Set
    else Load Balance to MySQL 3
        RouterRO->>M3: Execute SELECT
        M3-->>RouterRO: Result Set
    end
    
    RouterRO-->>Web: Data
    Web-->>User: 200 OK<br/>(HTML rendered)
    
    Note over M2,M3: Read load is distributed<br/>between SECONDARY nodes
```

---

## Proceso de Failover

### Failover Automático cuando PRIMARY cae

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
sequenceDiagram
    participant Router as MySQL Router
    participant M1 as MySQL 1<br/>PRIMARY ❌
    participant M2 as MySQL 2<br/>SECONDARY
    participant M3 as MySQL 3<br/>SECONDARY
    participant Monitor as Cluster Monitor
    
    Note over M1: MySQL 1 crashes
    M1->>M1: ❌ OFFLINE
    
    M2->>M2: Detect M1 unreachable
    M3->>M3: Detect M1 unreachable
    
    M2->>M3: No quorum!<br/>Need new PRIMARY
    M3->>M2: Agree, let's elect
    
    Note over M2,M3: Election based on<br/>memberWeight + GTID
    
    M2->>M2: ✅ I become PRIMARY<br/>(Weight: 60)
    M2-->>M3: I am new PRIMARY
    M3->>M3: Stay as SECONDARY
    
    Router->>M2: Detect new PRIMARY
    Router->>Router: Update routing:<br/>RW → mysql2:3306
    
    Monitor->>M1: Try to reconnect
    Monitor->>M2: Check cluster status
    M2-->>Monitor: Status: OK_NO_TOLERANCE<br/>PRIMARY: mysql2:3306
    Monitor->>Monitor: Update router state.json<br/>with available nodes
    
    alt M1 comes back online
        M1->>M1: ✅ Restart
        Monitor->>M1: Detect M1 available
        Monitor->>M2: Get cluster handle
        Monitor->>M2: cluster.rejoinInstance(mysql1)
        M2->>M1: Sync data via GR
        M1->>M1: Join as SECONDARY
        
        Note over M1,M3: All 3 nodes ONLINE again
        
        Monitor->>Monitor: Prefer mysql1 as PRIMARY?
        Monitor->>M2: cluster.setPrimaryInstance(mysql1)
        M2->>M1: Transfer PRIMARY role
        M1->>M1: ✅ Become PRIMARY again
        M2->>M2: Become SECONDARY
        
        Router->>Router: Update routing:<br/>RW → mysql1:3306
    end
```

### Escenario: Solo 1 Nodo Disponible

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
flowchart TD
    START([Todos los nodos caen])
    
    START --> ALLDOWN[mysql1: ❌ OFFLINE<br/>mysql2: ❌ OFFLINE<br/>mysql3: ❌ OFFLINE]
    
    ALLDOWN --> WAIT[Monitor detecta:<br/>0 nodos disponibles]
    
    WAIT --> M3START[mysql3 se inicia]
    
    M3START --> DETECT[Monitor detecta:<br/>1 nodo disponible]
    
    DETECT --> TRY1{Try getCluster}
    
    TRY1 -->|Error| TRY2{Try rebootClusterFromCompleteOutage}
    TRY1 -->|Success + NO_QUORUM| FORCE1[forceQuorumUsingPartitionOf<br/>mysql3:3306]
    
    TRY2 -->|Success| BOOT[✅ Cluster rebooted<br/>with mysql3]
    TRY2 -->|Error| TRY3{Try getCluster again}
    
    TRY3 -->|Success + NO_QUORUM| FORCE2[forceQuorumUsingPartitionOf<br/>mysql3:3306]
    TRY3 -->|Success + OK| OK1[✅ Cluster OK]
    
    FORCE1 --> OK2[✅ Cluster OK<br/>with 1 node]
    FORCE2 --> OK3[✅ Cluster OK<br/>with 1 node]
    BOOT --> OK4[✅ Cluster OK<br/>with 1 node]
    
    OK1 --> OPERATE[Cluster operando<br/>con 1 solo nodo]
    OK2 --> OPERATE
    OK3 --> OPERATE
    OK4 --> OPERATE
    
    OPERATE --> UPDATE[Monitor actualiza<br/>router state.json<br/>solo con mysql3]
    
    UPDATE --> READY[✅ Sistema funcional<br/>con 1 nodo]
    
    style START fill:#da3633,color:#ffffff
    style ALLDOWN fill:#da3633,color:#ffffff
    style READY fill:#238636,color:#ffffff
    style OPERATE fill:#238636,color:#ffffff
```

---

## Auto-Recovery

### Ciclo de Monitoreo Continuo

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
flowchart TD
    INIT([Monitor Inicia])
    
    INIT --> DELAY[Espera inicial:<br/>25 segundos]
    
    DELAY --> LOOP[Iniciar Loop]
    
    LOOP --> ITER[Iteración N]
    
    ITER --> TRY{getCluster<br/>accesible?}
    
    TRY -->|No| RECOVER[Ejecutar<br/>rebootClusterIfNeeded]
    TRY -->|Sí| STATUS[Obtener<br/>cluster.status]
    
    RECOVER --> CHECK1{Hay nodos<br/>disponibles?}
    CHECK1 -->|No| SLEEP1[Esperar 10s]
    CHECK1 -->|1 nodo| SINGLE[Proceso para<br/>1 solo nodo]
    CHECK1 -->|2+ nodos| REBOOT[rebootClusterFromCompleteOutage<br/>force: true]
    
    SINGLE --> FORCE[forceQuorum o<br/>reboot]
    
    FORCE --> SLEEP1
    REBOOT --> SLEEP1
    
    STATUS --> COUNT[Contar nodos<br/>ONLINE]
    
    COUNT --> DEGRADED{Nodos < 3?}
    
    DEGRADED -->|Sí| UPDATEROUTER[Actualizar<br/>router state.json]
    DEGRADED -->|No| POLICY{Tiempo para<br/>enforcar políticas?}
    
    UPDATEROUTER --> POLICY
    
    POLICY -->|Sí| ENFORCE[ensureClusterOptions<br/>enforcePreferredPrimary]
    POLICY -->|No| CLSTATUS{Cluster<br/>Status?}
    
    ENFORCE --> CLSTATUS
    
    CLSTATUS -->|OK/OK_PARTIAL| HEAL[autoRejoinNodes<br/>checkMissingInstances]
    CLSTATUS -->|NO_QUORUM| FORCEQUORUM[forceQuorumUsingPartitionOf]
    CLSTATUS -->|Otro| RESCAN[cluster.rescan]
    
    HEAL --> RESCAN
    FORCEQUORUM --> RESCAN
    
    RESCAN --> PREFPRIMARY[Enforcar PRIMARY<br/>preferido si es posible]
    
    PREFPRIMARY --> SLEEP2[Esperar 10s]
    
    SLEEP1 --> LOOP
    SLEEP2 --> LOOP
    
    style INIT fill:#1f6feb,color:#ffffff
    style RECOVER fill:#da3633,color:#ffffff
    style SINGLE fill:#d29922,color:#ffffff
    style UPDATEROUTER fill:#d29922,color:#ffffff
    style HEAL fill:#238636,color:#ffffff
```

### Funciones de Auto-Recovery

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
graph TB
    subgraph "cluster-monitor.py"
        MAIN[checkAndHealCluster<br/>Función Principal]
        
        MAIN --> F1[rebootClusterIfNeeded]
        MAIN --> F2[ensureClusterOptions]
        MAIN --> F3[enforcePreferredPrimary]
        MAIN --> F4[autoRejoinNodes]
        MAIN --> F5[checkMissingInstances]
        MAIN --> F6[updateRouterStateJson]
        
        F1 --> F1A[findAvailableInstances]
        F1 --> F1B[forceQuorumOnSingleNode]
        
        F4 --> F4A[Reintentar nodos<br/>OFFLINE/ERROR]
        F5 --> F5A[Añadir nodos<br/>MISSING]
        F6 --> F6A[Actualizar<br/>state.json del Router]
    end
    
    style MAIN fill:#da3633,stroke:#f85149,stroke-width:3px,color:#ffffff
    style F1 fill:#d29922,color:#ffffff
    style F6 fill:#1f6feb,color:#ffffff
```

---

## Estados del Cluster

### Posibles Estados

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
stateDiagram-v2
    [*] --> OFFLINE: Cluster no iniciado
    
    OFFLINE --> REBOOTING: rebootClusterFromCompleteOutage()
    
    REBOOTING --> OK: 3 nodos ONLINE
    REBOOTING --> OK_NO_TOLERANCE: 2 nodos ONLINE
    REBOOTING --> OK_NO_TOLERANCE: 1 nodo ONLINE + forceQuorum
    REBOOTING --> NO_QUORUM: Falló el reboot
    
    OK --> OK_PARTIAL: 1 nodo cae
    OK_PARTIAL --> OK_NO_TOLERANCE: Otro nodo cae
    OK_NO_TOLERANCE --> NO_QUORUM: Quórum perdido
    
    OK_NO_TOLERANCE --> OK_PARTIAL: Nodo se recupera
    OK_PARTIAL --> OK: Todos los nodos OK
    
    NO_QUORUM --> OK_NO_TOLERANCE: forceQuorumUsingPartitionOf()
    NO_QUORUM --> OK: rebootClusterFromCompleteOutage()
    
    OK --> [*]: Shutdown ordenado
    
    note right of OK
        3 nodos ONLINE
        Redundancia total
        R/W y R/O funcionan
    end note
    
    note right of OK_PARTIAL
        2 nodos ONLINE
        Puede tolerar 1 fallo más
        R/W y R/O funcionan
    end note
    
    note right of OK_NO_TOLERANCE
        1-2 nodos ONLINE
        No puede tolerar más fallos
        R/W funciona, R/O limitado
    end note
    
    note right of NO_QUORUM
        Quórum perdido
        Cluster no funcional
        Necesita intervención
    end note
```

### Matriz de Estados y Acciones

| Estado Cluster | Nodos ONLINE | Acción del Monitor | Router State |
|---------------|--------------|-------------------|--------------|
| **OK** | 3/3 | Monitoreo normal | Todos los nodos |
| **OK_PARTIAL** | 2/3 | Monitor + Update router state | 2 nodos |
| **OK_NO_TOLERANCE** | 1-2/3 | Update router + Force quorum si es 1 | Nodos disponibles |
| **NO_QUORUM** | 0-1/3 | Force quorum o reboot | Nodo único si hay 1 |
| **OFFLINE** | 0/3 | Esperar nodos + Reboot cuando haya 1+ | N/A |

---

## Resumen de Puertos

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0d1117', 'primaryTextColor': '#c9d1d9', 'primaryBorderColor': '#30363d', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#161b22', 'mainBkg': '#0d1117', 'nodeBorder': '#30363d', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d', 'defaultLinkColor': '#58a6ff', 'fontFamily': 'arial', 'fontSize': '16px'}}}%%
graph LR
    subgraph "Puertos Externos"
        P8091[8091<br/>HTTP Web App]
        P6446[6446<br/>MySQL RW]
        P6447[6447<br/>MySQL RO]
    end
    
    subgraph "Puertos Internos"
        P3306[3306<br/>MySQL Direct]
        P33060[33060<br/>MySQL X Protocol]
        P33061[33061<br/>Group Replication]
    end
    
    WEB[Web Container] -.->|Expone| P8091
    ROUTER[Router Container] -.->|Expone| P6446
    ROUTER -.->|Expone| P6447
    
    M1[MySQL 1] -.->|Usa| P3306
    M1 -.->|Usa| P33060
    M1 -.->|Usa GR| P33061
    
    style P8091 fill:#1f6feb,color:#ffffff
    style P6446 fill:#238636,color:#ffffff
    style P6447 fill:#1f6feb,color:#ffffff
    style P33061 fill:#d29922,color:#ffffff
```

---

## Siguiente: Configuración

Ver **[CONFIGURACION.md](CONFIGURACION.md)** para detalles de todos los parámetros configurables.

[← Volver al README](README.md) | [Siguiente: Configuración →](CONFIGURACION.md)
