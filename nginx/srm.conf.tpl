server {
    listen 80;
    listen [::]:80;
    server_name {{DOMAIN}};

    # Build estático de React
    root {{BUILD_DIR}};
    index index.html;

    # Proxy de la API al backend FastAPI (Uvicorn)
    location ^~ /api/ {
        proxy_pass http://127.0.0.1:{{BACKEND_PORT}};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        client_max_body_size 25M;
    }

    # SPA fallback
    location / {
        try_files $uri /index.html;
    }

    # Caché de estáticos
    location ~* \.(js|css|png|jpg|jpeg|svg|gif|ico|woff2?)$ {
        expires 30d;
        access_log off;
    }
}
