# Migración de App a EcoFlow Bridge WS `v2`

## Objetivo
Actualizar la app para consumir el nuevo contrato WebSocket `v2` del bridge, manteniendo compatibilidad temporal con `v1` durante la transición.

## Estado actual del bridge
- El bridge puede emitir `v1` y `v2` en paralelo.
- Flags de control:
  - `BRIDGE_WS_EMIT_V1=true|false`
  - `BRIDGE_WS_EMIT_V2=true|false`
- `v2` añade `connectivity` por dispositivo:
  - `online`
  - `assume_offline`
  - `offline`

## Diferencias clave `v1` vs `v2`
- Estructura base se mantiene (`event` + `payload`).
- En `v2`, snapshots y fleet incluyen `connectivity` explícito.
- Se incorporan métricas nuevas por modelo (ej. extra battery DP3: `powGet4p81`, `powGet4p82`).
- `online` sigue presente para compatibilidad, pero la app debe priorizar `connectivity`.

## Contrato esperado en app (recomendado)
Definir un modelo unificado con fallback:

```ts
type Connectivity = 'online' | 'assume_offline' | 'offline';

interface DeviceViewModel {
  deviceId: string;
  displayName: string;
  model: string | null;
  batteryPercent: number | null;
  connectivity: Connectivity;
  onlineLegacy: boolean | null;
  totalInputW: number | null;
  totalOutputW: number | null;
  metrics: Record<string, number | boolean | string | null>;
  updatedAt: string;
}
```

Regla de fallback:
- Si llega `v2`, usar `connectivity` directamente.
- Si llega solo `v1`, derivar:
  - `online === true` -> `online`
  - `online === false` -> `offline`
  - `online === null` -> `assume_offline`

## Cambios a implementar en la app
1. **Parser de envelopes**
- Soportar `version: 'v1' | 'v2'`.
- No descartar eventos `v2`.

2. **Store/estado global**
- Añadir campo `connectivity` al estado de dispositivo.
- Mantener `online` como `onlineLegacy` hasta terminar migración.

3. **UI de estado**
- Cambiar lógica de badges/colores a `connectivity`.
- Sugerencia visual:
  - `online`: verde
  - `assume_offline`: ámbar (estado incierto)
  - `offline`: rojo

4. **Pantalla de detalle de energía**
- Mostrar métricas extra battery cuando existan:
  - `metrics.pd.powGet4p81`
  - `metrics.pd.powGet4p82`
  - `metrics.pd.extraBattery1.soc` / `metrics.pd.extraBattery2.soc`
  - `metrics.pd.extraBattery1.temp` / `metrics.pd.extraBattery2.temp`
  - `metrics.pd.extraBattery1.maxCellTemp` / `metrics.pd.extraBattery2.maxCellTemp`
  - `metrics.pd.extraBattery1.minCellTemp` / `metrics.pd.extraBattery2.minCellTemp`
  - `metrics.pd.extraBattery1.inputWatts` / `metrics.pd.extraBattery2.inputWatts`
  - `metrics.pd.extraBattery1.outputWatts` / `metrics.pd.extraBattery2.outputWatts`
  - `metrics.pd.extraBattery1.cycles` / `metrics.pd.extraBattery2.cycles`
- Mantener ocultas si son `null/undefined`.

5. **Telemetría y logs app**
- Registrar `version` de mensaje recibido (`v1` o `v2`).
- Registrar transiciones de `connectivity` para diagnóstico de reconexión.

## Estrategia de despliegue recomendada
1. Bridge con emisión dual:
- `BRIDGE_WS_EMIT_V1=true`
- `BRIDGE_WS_EMIT_V2=true`

2. Publicar app con soporte dual:
- Consumir `v2` preferente.
- Fallback automático a `v1`.

3. Validar en dispositivos reales.

4. Cuando todo esté estable:
- Desactivar `v1` en bridge (`BRIDGE_WS_EMIT_V1=false`).

## Casos de prueba mínimos en app
1. **Conectividad**
- Recibir `online -> assume_offline -> offline` y reflejar en UI.
- Volver de `offline/assume_offline` a `online` al llegar nueva telemetría.

2. **Delta 3 Pro + extra battery**
- Visualizar `powGet4p81` y `powGet4p82` cuando estén presentes.
- Verificar agregados (`totalOutputW`) consistentes con cargas activas.

3. **River 3**
- Confirmar estabilidad de métricas principales con frames parciales.
- Confirmar que la UI no rompe cuando un campo derivado aparece/desaparece.

4. **Compatibilidad**
- App funciona con solo `v1`.
- App funciona con `v1+v2` simultáneo sin duplicar o corromper estado.

## Criterio de salida de migración
- App estable consumiendo `v2` en los 3 equipos objetivo.
- Sin regresiones visuales/funcionales en dashboard.
- Logs de conectividad coherentes con estados reales del bridge.
- `v1` desactivable sin impacto.
