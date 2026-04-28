# EcoFlow Direct Bridge

Bridge local para `ecoflow_dashboard` sin HA/ioBroker:

`EcoFlow API + MQTT cloud` -> `bridge` -> `ws://<host>:8787/ws`

## Variables

- `WS_HOST` / `WS_PORT`
- `ECOFLOW_APP_EMAIL` / `ECOFLOW_APP_PASSWORD` (obligatorias)
- `ECOFLOW_DEVICE_SNS` (lista SN separada por coma, recomendado)
- `ECOFLOW_OPEN_ACCESS_KEY` / `ECOFLOW_OPEN_SECRET_KEY` (opcionales para descubrir catálogo)

## Eventos WS

- `device_catalog`
- `fleet_state`
- `device_snapshot`
- `device_delta`

## Comandos

- `npm install`
- `npm run dev`
- `npm run build && npm run start`
- `npm test`
