# DELTA Pro 3 - Notas de API

Fuente: `sources/extracted/delta_pro_3.extracted.txt`

## Transporte

- HTTP:
  - `PUT /iot-open/sign/device/quota` (set)
  - `POST /iot-open/sign/device/quota` (get selectivo por `quotas`)
  - `GET /iot-open/sign/device/quota/all` (telemetria completa)
- MQTT:
  - `/open/${certificateAccount}/${sn}/set`
  - `/open/${certificateAccount}/${sn}/set_reply`
  - `/open/${certificateAccount}/${sn}/quota`
  - `/open/${certificateAccount}/${sn}/status`

## Comandos clave (Set)

- Beep:
  - `cfgBeepEn`
- Timeouts:
  - `cfgAcStandbyTime`
  - `cfgDcStandbyTime`
  - `cfgScreenOffTime`
  - `cfgDevStandbyTime`
  - `cfgBleStandbyTime`
- Pantalla:
  - `cfgLcdLight`
- Salidas:
  - `cfgHvAcOutOpen`
  - `cfgLvAcOutOpen`
  - `cfgDc12vOutOpen`
- Potencia:
  - `cfgXboostEn`
  - `cfgAcOutFreq`
- Bateria:
  - `cfgMaxChgSoc`
  - `cfgMinDsgSoc`
  - `cfgEnergyBackup.energyBackupStartSoc`
  - `cfgEnergyBackup.energyBackupEn`
- Otros:
  - `cfgPowerOff`
  - `cfgAcEnergySavingOpen`
  - `cfgMultiBpChgDsgMode`

## Quotas/telemetria relevante para UI

- SOC/estado:
  - `cmsBattSoc`
  - `bmsBattSoc`
  - `cmsChgDsgState`
  - `bmsChgDsgState`
- Limites:
  - `cmsMaxChgSoc`
  - `cmsMinDsgSoc`
- Backup reserve:
  - `energyBackupEn`
  - `energyBackupStartSoc`
- Salidas:
  - `xboostEn`
  - `acOutFreq`
  - `acEnergySavingOpen`
- Salud de bateria:
  - temperatura minima/maxima de bateria (campos BMS en `quota/all`)

## Mapeo directo a tus pantallas

- Home:
  - SOC: `cmsBattSoc`/`bmsBattSoc`
  - Flujo energia: campos `flowInfo*`, `plugInInfo*`, `pow*` de `quota/all`
- Control de salidas:
  - `cfgHvAcOutOpen`, `cfgLvAcOutOpen`, `cfgDc12vOutOpen`, `cfgXboostEn`
- BMS:
  - `cfgMaxChgSoc`, `cfgMinDsgSoc`, `cfgEnergyBackup.*`
- Configuracion tecnica:
  - `cfgAcStandbyTime`, `cfgDcStandbyTime`, `cfgScreenOffTime`, `cfgDevStandbyTime`, `cfgLcdLight`, `cfgBeepEn`

