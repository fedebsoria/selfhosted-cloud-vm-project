# 💻 Documentación de Arquitectura y Seguridad del Cloud Server

Este documento detalla la arquitectura, la asignación de servicios y las consideraciones de seguridad para el proyecto del servidor cloud, que incluye la instalación manual de Nextcloud y el uso del Túnel de Cloudflare para el acceso externo.

## 🔒 Diagrama del Servidor Generalizado (Seguridad Ofuscada)

Este diagrama muestra la disposición de los servicios y el flujo de tráfico. Los puertos específicos y los nombres de herramientas de gestión de alto valor han sido generalizados para evitar su exposición en un portfolio público.

```mermaid
graph TD
    %% SUBGRAPHS: Represent physical or logical locations.
    subgraph "External Access - Nextcloud"
        %% User device outside the local network
        A[Remote Device]
        %% The Cloudflare network edge (access point)
        B(Cloudflare Zero Trust Proxy)
        A --> B
        B --> Host
    end
    
    subgraph "Home Network"
        %% Router providing Internet and local network access
        C[ISP Router/Modem]
        %% User device inside the local network (PC, mobile, TV)
        D[Local Device]
    end
    
    subgraph "Server (Ubuntu Server @ M.2)"
    %% Ubuntu Server, where everything runs
    Host{"Operating System / Docker Host"}
    %% Database for Nextcloud (internal access only)
    DB["Database (MariaDB/PostgreSQL)"]
    %% Manual Nextcloud installation
    NC_Web["Web Server (Nginx + PHP-FPM) - Nextcloud"]
    %% Docker container for the dashboard (Homer)
    G["Local Homepage"]
    %% Docker management tool (Portainer)
    J["Container Manager (GUI)"]
    %% VPN client for alternative secure remote access
    K["VPN Client (ZeroTier)"]
        %% DNS service for privacy (Unbound)
        L[DNS Resolver]
    %% Host service for file sharing (Samba)
    M["File Sharing Protocol (SMB)"]
    %% Web interface for OS management (Cockpit)
    P["Host Web Manager (SystemD)"]
    end
    
    %% TRAFFIC FLOWS AND CONNECTIONS (Arrows)

    %% Local and Internet traffic entering the server
    C --> Host
    
    %% Cloudflare Tunnel connects to Nginx, which serves Nextcloud
    Host -- Tunnel (HTTPS) --> NC_Web
    %% Nextcloud connects internally to its database
    NC_Web --> DB
    
    %% DIRECT LOCAL ACCESS VIA IP:PORT (Generalized/hidden ports)
    %% Access to Local Homepage (Homer)
    D -- App Port 1 --> G
    %% Access to Container Manager (Portainer)
    D -- Mgmt Port 1 --> J
    %% Access to Host Web Manager (Cockpit)
    D -- Mgmt Port 2 --> P
    %% Access to network shared folders
    D -- SMB Access --> M
    %% Device uses Unbound as DNS server
    D -- DNS (53) --> L

    %% REMOTE ACCESS VIA ZEROTIER
    %% Access to Host Web Manager via ZeroTier
    K -- VPN Access --> P
    %% Access to Media Streaming App via ZeroTier
    K -- VPN Access --> G
    %% Access to Shared Files via ZeroTier
    K -- VPN Access --> M
    
    subgraph "Storage"
        %% The large-capacity disk
        N("8TB External HDD")
    end
    
    %% STORAGE DEPENDENCIES
    %% Nextcloud stores and writes files to the disk
    NC_Web -- Mounts/Writes --> N
    %% File Sharing Protocol shares the disk's folders
    M -- Shares --> N
    
    %% STYLES FOR VISUAL CLARITY
    style B fill:#3082e6,stroke:#333
    style Host fill:#f9f,stroke:#333,stroke-width:2px
    style K fill:#ffc,stroke:#333
    style L fill:#cff,stroke:#333
    style M fill:#ffa,stroke:#333
    style P fill:#ccf,stroke:#333
    style NC_Web fill:#a6e22e,stroke:#333
    style DB fill:#f08080,stroke:#333
```