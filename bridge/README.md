# EcoFlow Direct Bridge

Bridge local para `ecoflow_dashboard` sin HA/ioBroker:

`EcoFlow API + MQTT cloud` -> `bridge` -> `ws://<host>:8787/ws`

## Variables

- `WS_HOST` / `WS_PORT`
- `ECOFLOW_APP_EMAIL` / `ECOFLOW_APP_PASSWORD` (obligatorias)
- `ECOFLOW_DEVICE_SNS` (lista SN separada por coma, recomendado)
- `ECOFLOW_OPEN_ACCESS_KEY` / `ECOFLOW_OPEN_SECRET_KEY` (opcionales para descubrir catálogo)
- `ECOFLOW_STATUS_ASSUME_OFFLINE_SEC` (default `90`)
- `ECOFLOW_STATUS_FORCE_OFFLINE_MULTIPLIER` (default `3`)
- `ECOFLOW_STATUS_POLL_INTERVAL_SEC` (default `60`, poll condicional con Open API)
- `BRIDGE_WS_EMIT_V1` (default `true`)
- `BRIDGE_WS_EMIT_V2` (default `true`)

## Eventos WS

- `device_catalog`
- `fleet_state`
- `device_snapshot`
- `device_delta`

Notas de contrato:
- `v1` se mantiene para compatibilidad.
- `v2` convive en paralelo y añade `connectivity: online|assume_offline|offline`.

## Comandos

- `npm install`
- `npm run dev`
- `npm run build && npm run start`
- `npm test`
