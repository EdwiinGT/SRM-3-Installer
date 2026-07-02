# Guía de instalación detallada — SRM-3-Installer

Esta guía amplía el `README.md` con el detalle de cada fase y las decisiones de diseño.

## Fases del instalador

| # | Script | Función | Qué hace |
|---|--------|---------|----------|
| 00 | `00_preflight.sh` | `preflight` | Verifica root, detecta Ubuntu/arquitectura, instala utilidades base (curl, dnsutils, jq, openssl), comprueba red |
| 01 | `01_collect_input.sh` | `collect_input` + `dns_check` | Solicita dominio, admin, chef y JWT; valida que el dominio apunte a la IP del VPS |
| 02 | `02_system_update.sh` | `system_update` | `apt update && apt upgrade` |
| 03 | `03_base_deps.sh` | `install_base_deps` | Git, Curl, Python3/venv/pip, build-essential, UFW, etc. |
| 04 | `04_node.sh` | `install_node` | Node.js 20 LTS + Yarn |
| 05 | `05_mongodb.sh` | `install_mongodb` | MongoDB 8.0 (repo noble), `bindIp 127.0.0.1`, enable mongod |
| 06 | `06_nginx_certbot.sh` | `install_web_stack` | Nginx + Certbot |
| 07 | `07_clone_srm.sh` | `clone_srm` | Usuario `srm` + clona SRM-3 en `/opt/srm` |
| 08 | `08_backend.sh` | `setup_backend` | venv + `pip install` + genera `backend/.env` |
| 09 | `09_frontend.sh` | `setup_frontend` | `frontend/.env` + `yarn install` + `yarn build` |
| 10 | `10_nginx_site.sh` | `configure_nginx` | Genera y activa el sitio Nginx |
| 11 | `11_ssl.sh` | `setup_ssl` | `certbot --nginx` (con reversión a HTTP si falla) |
| 12 | `12_systemd.sh` | `setup_systemd` | Servicio `srm-backend` + enable |
| 13 | `13_security.sh` | `setup_security` | UFW + Fail2Ban + Logrotate |
| 14 | `14_validate.sh` | `run_validations` | 11 validaciones end-to-end con auto-reparación |
| 99 | `99_summary.sh` | `print_summary` | Resumen final |

## Decisiones de diseño

- **Ubuntu 24.04 (noble)**: se usa MongoDB **8.0** (única versión con soporte oficial para noble) y Node **20 LTS** (recomendado para React 19). Estos son los únicos ajustes de versión frente a la documentación oficial de SRM-3 (que ejemplifica con 22.04 y Mongo 7.0). Todo lo demás (rutas, puertos, nombre de BD, servicio systemd) es idéntico a la arquitectura oficial.
- **systemd exclusivamente** (sin supervisor), tal como exige el objetivo.
- **Idempotencia**: el instalador se puede re-ejecutar sin romper la instalación.
- **Sin datos hardcodeados**: todo se genera desde plantillas (`templates/`, `nginx/`, `systemd/`).
- **Seguridad**: MongoDB solo en loopback; UFW abre únicamente 22/80/443; `.env` con `chmod 600`.

## Cómo se crean los usuarios Admin y Chef

No se crean manualmente. El backend de SRM-3, al arrancar (`app.on_event("startup")`), crea los usuarios definidos en `ADMIN_EMAIL/ADMIN_PASSWORD` y `CHEF_EMAIL/CHEF_PASSWORD` del `.env`. Si ya existen y la contraseña difiere, la **resincroniza**. Por eso el instalador solo necesita escribir el `.env` correctamente.
