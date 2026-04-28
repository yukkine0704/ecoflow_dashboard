# ecoflow_dashboard

Dashboard Flutter conectado a un bridge local (`ioBroker.ecoflow-mqtt` -> MQTT HA topics -> WebSocket).

## Configuración

1. Levanta el bridge Node/TS en `./bridge`.
2. Abre la app y configura `Bridge WebSocket URL` (ej. `ws://127.0.0.1:8787/ws`).
3. Conecta y monitorea tus dispositivos.

## Bridge

Ver `./bridge/README.md`.
