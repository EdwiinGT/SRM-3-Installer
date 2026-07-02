# SRM-3-Installer

**Instalador oficial de [SRM-3](https://github.com/EdwiinGT/SRM-3)** — *System of Restaurant Management*.
Instala de forma **totalmente automática** todo el stack de SRM-3 sobre un **VPS limpio con Ubuntu Server 24.04 LTS**, sin necesidad de editar archivos ni ejecutar comandos manuales.

> Este es un proyecto **independiente**. No modifica el proyecto principal SRM-3: únicamente lo clona desde GitHub y lo despliega respetando su arquitectura oficial.

---

## Tabla de contenidos

1. [¿Qué instala?](#qué-instala)
2. [Requisitos](#requisitos)
3. [Uso de `install.sh`](#uso-de-installsh)
4. [Datos que solicita el instalador](#datos-que-solicita-el-instalador)
5. [Modo desatendido](#modo-desatendido)
6. [Arquitectura desplegada](#arquitectura-desplegada)
7. [Estructura del proyecto](#estructura-del-proyecto)
8. [Reinstalar](#reinstalar)
9. [Actualizar](#actualizar)
10. [Desinstalar](#desinstalar)
11. [Comprobar el estado del sistema](#comprobar-el-estado-del-sistema)
12. [Revisar los logs](#revisar-los-logs)
13. [Solución de errores](#solución-de-errores)
14. [Pruebas del propio instalador](#pruebas-del-propio-instalador)
15. [Licencia](#licencia)

---

## ¿Qué instala?

De forma automática y en orden:

- Actualiza Ubuntu y sus repositorios.
- Instala **Git, Curl, Wget, Python 3 + venv + pip, build-essential**.
- Instala **Node.js 20 LTS** y **Yarn**.
- Instala **MongoDB 8.0** (repositorio oficial para *noble*/24.04), solo en `localhost`.
- Instala **Nginx** y **Certbot**.
- Crea el usuario de sistema `srm` y clona **SRM-3** en `/opt/srm`.
- Configura el **backend FastAPI** (entorno virtual + dependencias + `.env`).
- Compila el **frontend React** (`yarn build`).
- Genera automáticamente los archivos `.env` de backend y frontend.
- Configura **Nginx** como *reverse proxy* + servidor de estáticos.
- Emite **HTTPS con Let's Encrypt** (previa validación de DNS).
- Configura **Firewall UFW**, **Fail2Ban** y **Logrotate**.
- Crea el servicio **systemd** `srm-backend` y lo habilita en el arranque.
- Ejecuta **validaciones end-to-end** con auto-reparación.

---

## Requisitos

- **VPS con Ubuntu Server 24.04 LTS** limpio, con acceso `root` (o `sudo`).
- Un **dominio** con un registro **A** apuntando a la IP pública del VPS (necesario para HTTPS).
- Recomendado: 2 vCPU, 2 GB RAM, 20 GB SSD (mínimo 1 vCPU / 1 GB).

---

## Uso de `install.sh`

```bash
# 1) Copia el proyecto al VPS (git clone, scp, etc.)
git clone https://github.com/EdwiinGT/SRM-3-Installer.git
cd SRM-3-Installer

# 2) Ejecuta el instalador como root
sudo bash install.sh
```

El instalador te guiará paso a paso. Al finalizar mostrará un resumen como:

```
==========================================
  SRM-3 instalado correctamente.
==========================================

  Panel:
    https://midominio.com

  Administrador:
    admin@correo.com

  Chef:
    chef@correo.com

  ------------------------------------------
  Backend....... OK
  Frontend...... OK
  MongoDB....... OK
  Nginx......... OK
  HTTPS......... OK
  Firewall...... OK
  systemd....... OK
  ------------------------------------------
==========================================
```

---

## Datos que solicita el instalador

El instalador **solo** pregunta:

| Dato | Descripción |
|------|-------------|
| **Dominio** | Ej: `srm.mirestaurante.com` |
| **Administrador — correo** | Email de la cuenta admin |
| **Administrador — contraseña** | Contraseña del admin |
| **Chef — correo** | Email de la cuenta chef |
| **Chef — contraseña** | Contraseña del chef |
| **JWT_SECRET** | Opcional; si se deja vacío se **genera automáticamente** con `openssl rand -hex 48` |

> **No** solicita nombre de base de datos, usuario, contraseña ni puerto de MongoDB: todo se configura automáticamente (`srm_restaurant` en `mongodb://localhost:27017`), tal como define la arquitectura oficial de SRM-3.

---

## Modo desatendido

Para automatizaciones (sin preguntas interactivas):

```bash
export SRM_DOMAIN="srm.mirestaurante.com"
export SRM_ADMIN_EMAIL="admin@midominio.com"
export SRM_ADMIN_PASSWORD="una-contraseña-fuerte"
export SRM_CHEF_EMAIL="chef@midominio.com"
export SRM_CHEF_PASSWORD="otra-contraseña-fuerte"
# export SRM_JWT_SECRET="..."   # opcional, si no se genera solo
sudo -E bash install.sh --non-interactive
```

Variables útiles adicionales: `SRM_REQUIRE_HTTPS=true` (cancela si el DNS no valida), `INSTALL_DIR`, `SRM_USER`, `DB_NAME`, `MONGO_VERSION`, `NODE_MAJOR`.

---

## Arquitectura desplegada

```
                Internet (HTTPS :443)
                        │
                        ▼
                ┌──────────────┐
                │    Nginx     │  sirve /opt/srm/frontend/build
                │  (TLS + SPA) │  y hace proxy de /api/*
                └──────┬───────┘
                       │ /api → 127.0.0.1:8001
                       ▼
                ┌──────────────┐
                │  Uvicorn     │  systemd: srm-backend
                │  FastAPI     │
                └──────┬───────┘
                       │ Motor (async)
                       ▼
                ┌──────────────┐
                │  MongoDB     │  127.0.0.1:27017  (srm_restaurant)
                └──────────────┘
```

- **Backend**: `uvicorn server:app --host 127.0.0.1 --port 8001 --workers 2 --proxy-headers` (gestionado por systemd, **no** supervisor).
- **Frontend**: build estático servido por Nginx.
- **MongoDB**: expuesto solo en loopback; UFW no abre 27017 ni 8001.

---

## Estructura del proyecto

```
SRM-3-Installer/
├── install.sh              # Orquestador principal
├── README.md
├── LICENSE
├── config/
│   └── defaults.conf       # Rutas, versiones, nombre de BD, usuario...
├── scripts/
│   ├── lib_common.sh       # Utilidades: logging, prompts, validaciones
│   ├── 00_preflight.sh     # Comprobaciones previas
│   ├── 01_collect_input.sh # Datos + validación DNS
│   ├── 02_system_update.sh
│   ├── 03_base_deps.sh
│   ├── 04_node.sh
│   ├── 05_mongodb.sh
│   ├── 06_nginx_certbot.sh
│   ├── 07_clone_srm.sh
│   ├── 08_backend.sh
│   ├── 09_frontend.sh
│   ├── 10_nginx_site.sh
│   ├── 11_ssl.sh
│   ├── 12_systemd.sh
│   ├── 13_security.sh
│   ├── 14_validate.sh
│   ├── 99_summary.sh
│   ├── update.sh           # Actualizar SRM-3
│   ├── uninstall.sh        # Desinstalar (--purge para todo)
│   └── status.sh           # Estado del sistema
├── templates/              # Plantillas .env, fail2ban, logrotate
├── nginx/                  # Plantilla del sitio Nginx
├── systemd/                # Plantilla del servicio systemd
├── ssl/                    # Notas sobre certificados
├── logs/                   # Logs de instalación (runtime)
├── docs/                   # Documentación adicional
└── tests/                  # Validación estática (bash -n + shellcheck)
```

---

## Reinstalar

Vuelve a ejecutar el instalador. Es **idempotente**: si `/opt/srm` ya es un repositorio git, actualiza el código en lugar de fallar, regenera los `.env`, reconstruye el frontend y reinicia los servicios.

```bash
sudo bash install.sh
```

Si quieres partir de cero, primero desinstala con `--purge` (ver abajo).

---

## Actualizar

Descarga los últimos cambios de SRM-3 y reconstruye:

```bash
sudo bash scripts/update.sh
```

Hace `git pull`, reinstala dependencias del backend, reconstruye el frontend y reinicia `srm-backend` + Nginx.

---

## Desinstalar

```bash
# Conserva la base de datos, el usuario y /opt/srm
sudo bash scripts/uninstall.sh

# Elimina TODO (base de datos, usuario 'srm' y /opt/srm)
sudo bash scripts/uninstall.sh --purge
```

---

## Comprobar el estado del sistema

```bash
sudo bash scripts/status.sh
```

Muestra el estado de `mongod`, `srm-backend`, `nginx`, `fail2ban`, el firewall, la API local, la conexión a la base de datos y las últimas líneas del backend.

Comandos útiles directos:

```bash
sudo systemctl status srm-backend
sudo systemctl status mongod nginx
sudo journalctl -u srm-backend -f
```

---

## Revisar los logs

- **Instalación / actualización / desinstalación**: `logs/install-*.log`, `logs/update-*.log`, `logs/uninstall-*.log` dentro del proyecto.
- **Backend**: `sudo journalctl -u srm-backend -f`
- **Nginx**: `/var/log/nginx/access.log` y `/var/log/nginx/error.log`
- **MongoDB**: `sudo journalctl -u mongod -f`
- **UFW**: `/var/log/ufw.log`

---

## Solución de errores

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `502 Bad Gateway` | Backend caído | `sudo systemctl restart srm-backend` y revisa `journalctl -u srm-backend` |
| HTTPS no se emitió | El dominio no apunta al VPS | Corrige el registro A y ejecuta `sudo certbot --nginx -d TU_DOMINIO` |
| `500` al iniciar sesión | Backend no conecta a Mongo | `sudo systemctl status mongod`; revisa `MONGO_URL` en `/opt/srm/backend/.env` |
| Login falla | Contraseñas mal introducidas | El backend resincroniza las credenciales del `.env` al reiniciar: `sudo systemctl restart srm-backend` |
| Frontend en blanco | `REACT_APP_BACKEND_URL` incorrecta | Verifica `/opt/srm/frontend/.env` y reconstruye con `scripts/update.sh` |
| `yarn build` sin memoria | VPS con poca RAM | El instalador ya limita memoria; añade swap si persiste |

El instalador intenta **auto-reparar** servicios inactivos y, si Certbot falla, revierte automáticamente a HTTP reconstruyendo el frontend.

---

## Pruebas del propio instalador

Validación estática (no instala nada):

```bash
bash tests/run_tests.sh
```

Comprueba la sintaxis de todos los scripts (`bash -n`), ejecuta `shellcheck` si está disponible y verifica la presencia de las plantillas.

---

## Licencia

Distribuido bajo licencia **MIT**. Consulta [`LICENSE`](./LICENSE).
