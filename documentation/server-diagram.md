# 💻 Cloud Server Architecture and Security Documentation

This document details the architecture, service allocation, and security considerations for the cloud server project, which includes the manual installation of Nextcloud and the use of the Cloudflare Tunnel for external access.

## 🔒 Generalized Server Diagram (Security Obfuscated)

This diagram shows the service layout and traffic flow. Specific ports and the names of high-value management tools have been generalized to avoid their exposure in a public portfolio.

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

    C --> Host %% Local and Internet traffic entering the server
    
    Host -- Tunnel (HTTPS) --> NC_Web %% Cloudflare Tunnel connects to Nginx, which serves Nextcloud
    NC_Web --> DB %% Nextcloud connects internally to its database
    
    %% DIRECT LOCAL ACCESS VIA IP:PORT (Generalized/hidden ports)
    D -- App Port 1 --> G %% Access to Local Homepage (Homer)
    D -- Mgmt Port 1 --> J %% Access to Container Manager (Portainer)
    D -- Mgmt Port 2 --> P %% Access to Host Web Manager (Cockpit)
    D -- SMB Access --> M %% Access to network shared folders
    D -- DNS (53) --> L %% Device uses Unbound as DNS server

    %% REMOTE ACCESS VIA ZEROTIER
    K -- VPN Access --> P %% Access to Host Web Manager via ZeroTier
    K -- VPN Access --> G %% Access to Media Streaming App via ZeroTier
    K -- VPN Access --> M %% Access to Shared Files via ZeroTier
    
    subgraph "Storage"
        %% The large-capacity disk
        N("8TB External HDD")
    end
    
    %% STORAGE DEPENDENCIES
    NC_Web -- Mounts/Writes --> N %% Nextcloud stores and writes files to the disk
    M -- Shares --> N %% File Sharing Protocol shares the disk's folders
    
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