# 💻 Documentación de Arquitectura y Seguridad del Cloud Server

Este documento detalla la arquitectura, la asignación de servicios y las consideraciones de seguridad para el proyecto del servidor cloud, que incluye la instalación manual de Nextcloud y el uso del Túnel de Cloudflare para el acceso externo.

## 🔒 Diagrama del Servidor Generalizado (Seguridad Ofuscada)

Este diagrama muestra la disposición de los servicios y el flujo de tráfico. Los puertos específicos y los nombres de herramientas de gestión de alto valor han sido generalizados para evitar su exposición en un portfolio público.

graph TD
    %% SUBGRAFOS: Representan ubicaciones físicas o lógicas.

    subgraph Acceso Externo (Nextcloud)
        A[Dispositivo Remoto] %% Dispositivo del usuario fuera de la red local
        B(Proxy Cloudflare Zero Trust) %% El borde de la red de Cloudflare (punto de acceso)
        A --> B %% El usuario accede al dominio en Cloudflare
        B --> Host %% Cloudflare reenvía la petición a través del Túnel al servidor Host
    end
    
    subgraph Red Doméstica 🏠
        C[Router/Módem ISP] %% Router que provee acceso a Internet y red local
        D[Dispositivo Local] %% Dispositivo del usuario dentro de la red local (PC, móvil, TV)
    end
    
    subgraph Servidor (Ubuntu Server @ M.2) 💻 %% La máquina física
        Host{Sistema Operativo / Docker Host} %% Ubuntu Server, donde todo corre
        DB[Base de Datos (MariaDB/PostgreSQL)] %% Base de datos para Nextcloud (solo acceso interno)
        NC_Web[Servidor Web (Nginx + PHP-FPM) - Nextcloud] %% Instalación manual de Nextcloud
        G[Página de Inicio Local] %% Contenedor Docker para el dashboard (Homer)
        J[Gestor de Contenedores (GUI)] %% Herramienta de gestión de Docker (Portainer)
        K[Cliente VPN (ZeroTier)] %% Cliente VPN para acceso remoto alternativo seguro
        L[Resolvedor DNS] %% Servicio DNS para privacidad (Unbound)
        M[Protocolo de Archivos Compartidos (SMB)] %% Servicio del Host para compartir archivos (Samba)
        P[Gestor Web del Host (SystemD)] %% Interfaz web para gestión del SO (Cockpit)
    end
    
    %% FLUJOS DE TRÁFICO Y CONEXIONES (Flechas)

    C --> Host %% Tráfico local e Internet entrando al servidor
    
    Host -- Túnel (HTTPS) --> NC_Web %% Cloudflare Tunnel conecta a Nginx, el cual sirve Nextcloud
    NC_Web --> DB %% Nextcloud se conecta internamente a su base de datos
    
    %% ACCESOS LOCALES DIRECTOS POR IP:PUERTO (Puertos generalizados/ocultos)
    D -- Puerto App 1 --> G %% Acceso a Página de Inicio Local (Homer)
    D -- Puerto Gestión 1 --> J %% Acceso a Gestor de Contenedores (Portainer)
    D -- Puerto Gestión 2 --> P %% Acceso a Gestor Web del Host (Cockpit)
    D -- Acceso SMB --> M %% Acceso a carpetas compartidas por red
    D -- DNS (53) --> L %% Dispositivo usa Unbound como servidor DNS

    %% ACCESOS REMOTOS VÍA ZEROTIER
    K -- Acceso VPN --> P %% Acceso a Gestor Web del Host vía ZeroTier
    K -- Acceso VPN --> G %% Acceso a App de Streaming Multimedia vía ZeroTier
    K -- Acceso SMB --> M %% Acceso a Archivos Compartidos vía ZeroTier
    
    subgraph Almacenamiento 💾 %% El disco de gran capacidad
        N(HDD Externo de 8TB) %% Disco Duro Externo
    end
    
    %% DEPENDENCIAS DE ALMACENAMIENTO
    NC_Web -- Monta/Escribe --> N %% Nextcloud almacena y escribe archivos en el disco
    M -- Comparte --> N %% Protocolo de Archivos Compartidos comparte las carpetas del disco
    
    %% ESTILOS PARA CLARIDAD VISUAL
    style B fill:#3082e6,stroke:#333
    style Host fill:#f9f,stroke:#333,stroke-width:2px
    style K fill:#ffc,stroke:#333
    style L fill:#cff,stroke:#333
    style M fill:#ffa,stroke:#333
    style P fill:#ccf,stroke:#333
    style NC_Web fill:#a6e22e,stroke:#333
    style DB fill:#f08080,stroke:#333