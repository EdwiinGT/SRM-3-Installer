# Certificados SSL

Los certificados TLS los gestiona **Certbot** (Let's Encrypt) automáticamente durante la
instalación (`scripts/11_ssl.sh`).

- Ubicación de los certificados: `/etc/letsencrypt/live/<dominio>/`
- Renovación automática: gestionada por `certbot.timer` (systemd).

## Comandos útiles

```bash
# Emitir/renovar manualmente
sudo certbot --nginx -d tu-dominio.com

# Probar la renovación automática
sudo certbot renew --dry-run

# Ver el estado del temporizador de renovación
sudo systemctl status certbot.timer
```

Este directorio se mantiene como referencia; el instalador no almacena certificados aquí.
