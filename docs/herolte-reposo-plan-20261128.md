# Reposo con la pantalla apagada: siguiente paso (2026-11-28)

## Medido

| Estado | Corriente | Evidencia |
|---|---|---|
| iOS, pantalla apagada, sin cable (2026-11-28) | ~340 mA | E-0434 |
| iOS min94, pantalla apagada, DECON parado y 8 dominios apagados | 284 mA (IC95 276–293) | E-0312 |
| Linux (TWRP), mismo teléfono, pantalla apagada | 25–35 mA | E-0288 |

La CPU de los procesos ya es ~1 %: los ~250–300 mA que sobran respecto a Linux no vienen de ahí. La diferencia entre 340
y 284 mA no se ha investigado (entre medias hay Wi-Fi encendido, que costaba ~30 mA en E-0287, el servidor SSH y los
medidores).

## Lo descartado o poco rentable (ya probado)

- Reposo profundo de núcleos y apagado de clúster: sin ahorro demostrable (E-0295 a E-0301).
- Dominios sin uso y DECON: ya activos por defecto (E-0312).
- El PMIC no cambia nada al apagar la pantalla (E-0313, E-0314).

## Candidatos

1. **Clúster pequeño con la pantalla apagada.** iOS lo deja en 1066 MHz a 0,819 V; Linux en reposo baja a 0,600 V
   (E-0314). Ya hay código probado que cambia su frecuencia y tensión (parche 0465, cinco cambios sin fallos, E-0319);
   subir a 1586 MHz costó +153 mA, así que la palanca existe. Falta la fila ECT de 546 o 754 MHz
   (`~/HackiOS/lab/ect/ect_dvfs.txt`). Riesgo medio: una tensión mal puesta cuelga el sistema.
2. **Memoria y bus (MIF, INT).** 0,881 / 0,8125 V frente a 0,575 / 0,631 V de Linux. Probablemente lo que más vale y lo
   más peligroso: cambiar la frecuencia de la DRAM puede corromper datos. Y leer CMU_MIF0 colgó el teléfono (E-0315).
   No se toca todavía.

## Cómo probar sin una escritura por condición

Una sola imagen con un `sysctl` que active el candidato 1 **apagado por defecto** (p. ej. `kern.hero_little_idle_mhz`):

1. El Director desconecta el cable y bloquea.
2. Por SSH (la Wi-Fi sigue), el PC alterna el valor cada 3 minutos: 0, 546, 0, 546…
3. `hero-run` ya anota la corriente cada 30 s; se comparan los tramos (A/B dentro del mismo arranque).

Criterio fijado antes de mirar: se adopta si la mediana baja al menos 25 mA en los tres pares y no hay cuelgues.
Requiere autorización de BOOT (D-0127 no la cubre) y la imagen anterior como vuelta atrás.
