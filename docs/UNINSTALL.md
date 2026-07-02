# Desinstalación — SRM-3-Installer

## Desinstalación estándar (conserva los datos)

Detiene y elimina el servicio `srm-backend`, la configuración de Nginx, Fail2Ban y Logrotate.
**Conserva** la base de datos `srm_restaurant`, el usuario `srm` y el directorio `/opt/srm`.

```bash
sudo bash scripts/uninstall.sh
```

## Desinstalación completa (elimina TODO)

Además de lo anterior, elimina la base de datos, el usuario `srm` y `/opt/srm`.

```bash
sudo bash scripts/uninstall.sh --purge
```

> **Atención**: `--purge` borra irreversiblemente los datos del restaurante. Haz un respaldo antes:
>
> ```bash
> mongodump --uri="mongodb://localhost:27017/srm_restaurant" \
>           --archive="/root/srm-backup-$(date +%F).archive" --gzip
> ```

## Elementos que la desinstalación NO toca

- Paquetes del sistema (MongoDB, Node.js, Nginx, Certbot) — se conservan por si otros servicios los usan.
- Reglas de UFW.

Para eliminarlos manualmente (opcional):

```bash
sudo apt purge -y mongodb-org nodejs nginx certbot python3-certbot-nginx
sudo apt autoremove -y
```
