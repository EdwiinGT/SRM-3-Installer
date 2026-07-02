# Solución de problemas — SRM-3-Installer

## Diagnóstico rápido

```bash
sudo bash scripts/status.sh
```

## Problemas frecuentes

### 1. HTTPS no se emitió
**Causa**: el dominio no apunta (aún) a la IP del VPS, o el DNS no ha propagado.

```bash
# Verifica a dónde apunta el dominio y la IP del VPS
dig +short A tu-dominio.com
curl -s https://api.ipify.org; echo

# Cuando coincidan, emite el certificado
sudo certbot --nginx -d tu-dominio.com
```

Tras emitir HTTPS, actualiza `frontend/.env` a `https://` y reconstruye:

```bash
sudo bash scripts/update.sh
```

### 2. `502 Bad Gateway`
El backend no está corriendo.

```bash
sudo systemctl status srm-backend
sudo journalctl -u srm-backend -n 50 --no-pager
sudo systemctl restart srm-backend
```

### 3. Error `500` al iniciar sesión
MongoDB no está accesible o `MONGO_URL` es incorrecta.

```bash
sudo systemctl status mongod
mongosh --eval "db.runCommand({ping:1})"
sudo cat /opt/srm/backend/.env | grep MONGO_URL
```

### 4. No puedo iniciar sesión con Admin/Chef
El backend resincroniza las credenciales del `.env` al reiniciar:

```bash
sudo cat /opt/srm/backend/.env | grep -E 'ADMIN_|CHEF_'
sudo systemctl restart srm-backend
```

### 5. `yarn build` se queda sin memoria
En VPS con 1 GB de RAM, añade swap:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 6. Nginx no arranca
```bash
sudo nginx -t          # muestra el error de configuración
sudo systemctl restart nginx
```

## Logs

- Instalador: `logs/install-*.log` (dentro del proyecto)
- Backend: `sudo journalctl -u srm-backend -f`
- Nginx: `/var/log/nginx/error.log`
- MongoDB: `sudo journalctl -u mongod -f`
- UFW: `/var/log/ufw.log`

## Puertos esperados

| Servicio | Puerto | Exposición |
|----------|--------|------------|
| Nginx | 80/443 | Público |
| Uvicorn (backend) | 8001 | Solo localhost |
| MongoDB | 27017 | Solo localhost |
| SSH | 22 | Público (protegido por Fail2Ban) |
