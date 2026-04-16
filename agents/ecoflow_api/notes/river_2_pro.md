# River 2 Pro - Notas de API

Fuente: `sources/extracted/river_2_pro.extracted.txt`

## Transporte

- HTTP:
  - `PUT /iot-open/sign/device/quota` (set)
  - `GET /iot-open/sign/device/quota` (get selectivo por `quotas`)
  - `GET /iot-open/sign/device/quota/all` (telemetria completa)
- MQTT:
  - `/open/${certificateAccount}/${sn}/set`
  - `/open/${certificateAccount}/${sn}/set_reply`
  - `/open/${certificateAccount}/${sn}/quota`
  - `/open/${certificateAccount}/${sn}/status`

## ModuleType

- `1`: PD
- `2`: BMS
- `3`: INV
- `4`: BMS_SLAVE
- `5`: MPPT

## Comandos principales por modulo

- MPPT (`moduleType: 5`)
  - `operateType: "mpptCar"` -> 12V car output (`enabled`)
  - `operateType: "acOutCfg"` -> AC output + X-Boost + voltaje/frecuencia
    - `enabled`
    - `xboost`
    - `out_voltage`
    - `out_freq`
- PD (`moduleType: 1`)
  - `operateType: "watthConfig"`
    - `isConfig`
    - `bpPowerSoc`
    - `minDsgSoc` (doc indica que puede no estar activo aun)
    - `minChgSoc` (doc indica que puede no estar activo aun)
- BMS (`moduleType: 2`)
  - `operateType: "upsConfig"` -> `maxChgSoc`
  - `operateType: "dsgCfg"` -> `minDsgSoc`

## Quotas clave

- `pd.wattsOutSum`
- `pd.carState`
- `pd.bpPowerSoc`
- `pd.usb1Watts`
- `bms_emsStatus.maxChargeSoc`
- `bms_emsStatus.minDsgSoc`
- `mppt.cfgAcEnabled`
- `mppt.cfgAcXboost`
- `mppt.cfgAcOutVol`
- `mppt.cfgAcOutFreq`

## Mapeo rapido a tus pantallas

- Home:
  - consumo/salida: `pd.wattsOutSum`
- Control:
  - AC + X-Boost: `mppt.cfgAcEnabled`, `mppt.cfgAcXboost`
  - 12V: `pd.carState`
- BMS:
  - limites: `bms_emsStatus.maxChargeSoc`, `bms_emsStatus.minDsgSoc`
  - respaldo: `pd.bpPowerSoc`

