# 💻 Selfhosted Cloud Server Architecture Project: Nextcloud, Media, and Zero Trust VPN



This repository documents the architecture and manual setup of a highly secure, low-cost cloud server environment built on a Virtual Machine, featuring self-hosted services and secure remote access via Cloudflare Zero Trust.



---



## en Project Overview and Architecture



This project demonstrates proficiency in Linux system administration, network security, and service orchestration using the \*\*LEMP stack\*\* (Nginx, MariaDB, PHP-FPM) and \*\*containerization\*\* (Docker).



### Key Features



* \*\*Low-Cost Storage:\*\* Utilization of an 8TB External HDD (simulated via VM disk mount) for high-capacity media storage.

* \*\*Zero Trust Access:\*\* \*\*Only Nextcloud\*\* is exposed to the public internet using a \*\*Cloudflare Tunnel\*\*, avoiding port forwarding and mitigating CGNAT issues.

* \*\*Manual Setup:\*\* Nextcloud is installed manually on the Host OS for granular control and database practice.

\* \*\*Local Management:\*\* High-value services like Cockpit and Portainer are accessed locally or via \*\*ZeroTier VPN\*\*.



### Architectural Diagram



The full traffic flow and component organization is visualized in the dedicated diagram file (Mermaid syntax).



➡️ \*\*\[View Detailed Architectural Diagram](architecture-diagram.md)\*\* ⬅️



### Port Assignment and Access Table (English)



This table shows the logical port mapping for the final architecture.



| Service Name (Actual) | Generic Component | Access Port (Local) | External Access Method | Notes |

| :--- | :--- | :--- | :--- | :--- |

| \*\*Nextcloud\*\* | Web Server (Nginx) | 443 | \*\*Cloudflare Tunnel\*\* (`nextcloud.domain.cc`) | Primary service. Exposed via HTTPS Tunnel only. |

| \*\*Cockpit\*\* | Web Host Manager | 9090 | N/A | Host management. Access via \*\*Local IP:Port\*\* or \*\*ZeroTier\*\*. |

| \*\*Portainer\*\* | Container Manager | 9000 | N/A | Docker/Container management GUI. |

| \*\*Samba\*\* | File Sharing Protocol | 445 (SMB) | N/A | File access via network sharing (`\\\\IP\_ADDRESS`). |

| \*\*Unbound\*\* | DNS Resolver | 53 (UDP/TCP) | N/A | Used internally for DNS privacy and recursive resolving. |



\*\*\*



## 🇪🇸 Resumen del Proyecto y Arquitectura



Este repositorio documenta la arquitectura y configuración manual de un entorno de servidor cloud de alta seguridad y bajo costo, construido sobre una Máquina Virtual, con servicios autoalojados y acceso remoto seguro mediante Cloudflare Zero Trust.



### Características Clave



* \*\*Almacenamiento de Bajo Costo:\*\* Utilización de un HDD Externo de 8TB (simulado mediante montaje de disco de MV) para almacenamiento multimedia de alta capacidad.

* \*\*Acceso Zero Trust:\*\* \*\*Solo Nextcloud\*\* está expuesto a Internet público usando un \*\*Túnel de Cloudflare\*\*, evitando la apertura de puertos y mitigando problemas de CGNAT.

* \*\*Configuración Manual:\*\* Nextcloud está instalado manualmente en el SO Host para un control granular y práctica de bases de datos.

* \*\*Gestión Local:\*\* Los servicios de alto valor como Cockpit y Portainer son accesibles localmente o vía \*\*VPN ZeroTier\*\*.



### Diagrama Arquitectónico



El flujo de tráfico completo y la organización de los componentes se visualiza en el archivo de diagrama dedicado (sintaxis Mermaid).



➡️ \*\*\[Ver Diagrama Arquitectónico Detallado](architecture-diagram.md)\*\* ⬅️



### Tabla de Asignación de Puertos y Accesos (Español)



Esta tabla muestra la asignación lógica de puertos para la arquitectura final.



| Nombre del Servicio (Real) | Componente Genérico | Puerto de Acceso (Local) | Método de Acceso Externo | Notas |

| :--- | :--- | :--- | :--- | :--- |

| \*\*Nextcloud\*\* | Servidor Web (Nginx) | 443 | \*\*Túnel de Cloudflare\*\* (`nextcloud.dominio.cc`) | Servicio principal. Expuesto solo por el Túnel HTTPS. |

| \*\*Cockpit\*\* | Gestor Web del Host | 9090 | N/A | Gestión del Host. Acceso vía \*\*IP Local:Puerto\*\* o \*\*ZeroTier\*\*. |

| \*\*Portainer\*\* | Gestor de Contenedores | 9000 | N/A | Interfaz gráfica para gestión de Docker/Contenedores. |

| \*\*Samba\*\* | Protocolo de Archivos | 445 (SMB) | N/A | Acceso a archivos mediante recurso compartido de red (`\\\\DIRECCIÓN\_IP`). |

| \*\*Unbound\*\* | Resolvedor DNS | 53 (UDP/TCP) | N/A | Uso interno para privacidad DNS y resolución recursiva. |



\*\*\*



## 💾 VM Appliance Download / Descarga del Appliance de la MV



The complete VirtualBox appliance (`.ova` file) is hosted on Google Drive. You can download and import the VM to test the environment.



El \*appliance\* completo de VirtualBox (`.ova`) está alojado en Google Drive. Puedes descargar e importar la MV para probar el entorno.



➡️ \*\*VM Appliance Download Link / Enlace de Descarga del Appliance:\*\* \*\*\[ENLACE DE DRIVE A COMPLETAR POR EL USUARIO]\*\*
