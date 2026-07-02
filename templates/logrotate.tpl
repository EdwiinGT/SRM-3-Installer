# Logrotate para SRM-3 (generado por SRM-3-Installer)
{{INSTALL_DIR}}/logs/*.log /var/log/srm-*.log {
    weekly
    rotate 8
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
