# EcoFlow API Docs Bundle

Este directorio deja preparada la documentacion para futuras sesiones del proyecto.

## Contenido

- `sources/raw/`
  - `delta_pro_3.mhtml`
  - `river_2_pro.mhtml`
- `sources/extracted/`
  - `delta_pro_3.extracted.txt`
  - `river_2_pro.extracted.txt`
- `notes/`
  - `delta_pro_3.md`
  - `river_2_pro.md`
- `templates/`
  - `http_set_quota.json`
  - `http_get_quota.json`
  - `mqtt_set.json`
  - `mqtt_set_reply.json`
- `scripts/extract_mhtml.py`

## Resumen rapido de integracion

- HTTP set command:
  - `PUT /iot-open/sign/device/quota`
- HTTP get quota:
  - River 2 Pro doc: `GET /iot-open/sign/device/quota`
  - DELTA Pro 3 doc: `POST /iot-open/sign/device/quota`
- HTTP get all quotas:
  - `GET /iot-open/sign/device/quota/all`

## MQTT base

- Set command topic: `/open/${certificateAccount}/${sn}/set`
- Set reply topic: `/open/${certificateAccount}/${sn}/set_reply`
- Telemetria/quotas: `/open/${certificateAccount}/${sn}/quota`
- Estado: `/open/${certificateAccount}/${sn}/status`

## Nota importante

Hay una diferencia entre documentos en el metodo de "get quota" (`GET` vs `POST`).
Al implementar, conviene probar ambos en staging y dejar fallback.

