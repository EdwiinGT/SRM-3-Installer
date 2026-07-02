[Unit]
Description=SRM-3 Backend (FastAPI + Uvicorn)
After=network.target mongod.service
Wants=mongod.service

[Service]
Type=simple
User={{USER}}
Group={{USER}}
WorkingDirectory={{WORKDIR}}
EnvironmentFile={{ENVFILE}}
ExecStart={{VENV}}/bin/uvicorn server:app --host 127.0.0.1 --port {{BACKEND_PORT}} --workers {{WORKERS}} --proxy-headers
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
