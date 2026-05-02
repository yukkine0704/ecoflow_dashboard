# EcoFlow Bridge Release Checklist

## CI Gate
- `npm run build` exitoso.
- `npm test` exitoso.
- Tests de `StatusTracker`, decoders por modelo y store de conectividad en verde.

## Functional Validation
- Delta Pro 3: SOC, input/output, temperatura y estado de conectividad correctos.
- Delta Pro 3 + extra battery: `powGet4p81` y `powGet4p82` visibles y agregados estables.
- River 3: campos derivados (`cfg_ac_out_open`) y telemetría principal estables.

## Connectivity / Resilience
- Reconexión MQTT restablece subscripciones.
- Estado transita `online -> assume_offline -> offline` con TTL configurado.
- Poll condicional Open API solo se ejecuta para dispositivos en `assume_offline`.

## WS Contract
- `v1` se mantiene operativo.
- `v2` emite `connectivity` y nuevos campos de métricas.
- Emisión dual controlada por `BRIDGE_WS_EMIT_V1/BRIDGE_WS_EMIT_V2`.

