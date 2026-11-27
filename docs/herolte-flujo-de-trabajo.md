# Cómo se trabaja en HEROLTE (desde el 2026-11-27)

## Dónde está cada cosa

| Ruta | Qué es | ¿En git? |
|---|---|---|
| `~/HackiOS/repos/wardevsa-ios-a5xelte-v2` | Línea activa (`herolte-sync-upstream`) | sí |
| `~/HackiOS/repos/wardevsa-ios-a5xelte` | Copia principal, rama `herolte-drop-fixes` con trabajo sin commit (copia en `backups/trabajo-sin-commit-20261127`) | sí |
| `~/HackiOS/evidencias/` | Registros del teléfono y archivos citados en `evidence.toml` | no (privado) |
| `~/HackiOS/builds/` | Imágenes de BOOT (`device-day`) y descargas de CI (`ci/`) | no |
| `~/HackiOS/backups/` | Copias del teléfono (contienen IMEI) y del trabajo | no |
| `~/HackiOS/lab/` | Herramientas de análisis: `venv` (lz4, capstone), `dyld/`, `sim/`, scripts antiguos | no |
| `~/HackiOS/informes/` | Informes sueltos antiguos | no |

Nada que haya que conservar va a `/tmp` ni a la carpeta temporal de un trabajo de Claude: se borran solos.

## Ciclo de una prueba

1. Cambiar código, probar sin teléfono (`python3 -m unittest tools/test_hero.py`, simulación de parches en `lab/sim`).
2. Commit y push a `mio herolte-sync-upstream`.
3. `tools/hero ci xnu-fast` (kernel) o `tools/hero ci mesa-ios` (`hero-run` y bibliotecas).
4. Imagen: `tools/herolte-build-min.sh KERNEL LINEA SALIDA NOMBRE` (el verificador debe dar 0 FAIL).
5. **Autorización del Director** y escritura: `herolte-flash-boot.sh` (BOOT) o `herolte-drop.py` (zona DROP).
6. El Director arranca, prueba y vuelve a TWRP.
7. `tools/hero pull NOMBRE`, `tools/hero logs EXPRESIÓN`, `tools/hero power`.
8. `tools/hero evidence ARCHIVO TÍTULO`, `python3 tools/governance.py render`, `check`, commit.

## Pruebas sin tocar botones (pendiente de probar en el teléfono)

`recovery.after` en la zona DROP, con el texto `SEGUNDOS VECES` (por ejemplo `900 3`): `hero-run` apaga iOS pasado ese
tiempo y, como `herohalt=1` es el valor por defecto del kernel, el teléfono vuelve solo a TWRP. Desde TWRP el PC recoge
(`tools/hero pull`) y arranca otra vez (`adb reboot`). Se detiene al gastar las VECES. No cubre un pánico ni un cuelgue
anterior a `hero-run`: ahí siguen haciendo falta las teclas.

## Reglas que no cambian

- Solo se escriben BOOT y la zona DROP; nunca EFS, RECOVERY ni cargadores.
- Cualquier otra escritura en USERDATA se aprueba una a una.
- Una hipótesis se escribe como hipótesis; un fallo refutado también se registra.
- `tools/hero` no escribe en el teléfono.

## Para limpiar el disco

`df -h /` antes de crear artefactos grandes. Las descargas de `builds/ci/` se pueden volver a bajar con `gh run download`.
Lo archivado en el NVMe está descrito en la memoria `reference_offload_nvme`.
