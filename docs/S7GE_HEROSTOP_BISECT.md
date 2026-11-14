# S7GE — bisección con `herostop=N` (tanda D-0041, 2026-11-14)
**Qué es:** el kernel (0341) congela la CPU (`wfe` en bucle) justo después de dibujar el bloque N de la columna x≈1300. Con eso el resultado es una **imagen fija**, no unos fotogramas fugaces. Cada imagen = la misma que min2 más `herostop=N`.

## Slots (columna derecha; y = 88 + 32·slot) y **orden real de ejecución**
El número de slot **no es monotónico con la ejecución** (0340 añadió los 10-12 entre medias). Orden en que se dibujan:
`0` entrada a `arm_init` · `1` tras `PE_init_platform` · `2` tras `ml_parse_cpu_topology` · `3` tras `cpu_bootstrap` · `4` tras `kernel_startup_bootstrap` · `5` tras `cpu_init` · `6` tras 6a · **`10`** tras la cadena `maxmem` · `7` tras 6b · **`11`** · **`12`** tras `immediate_NMI` · `8` tras 6c · `9` marca 7 · `13`… dentro de `arm_vm_init` · `19` justo antes de apagar TTBR0.
Un freeze en `herostop=N` deja visibles **los bloques ya dibujados** (no 0..N). El slot 0 no puede congelar (va antes de leer la boot-arg); el 1 y siguientes sí (la boot-arg se lee antes de la marca 2).
| `herostop` | punto | bloques visibles al congelar (por slot) | cantidad |
|---|---|---|---|
| 2 | tras `ml_parse_cpu_topology` | 0,1,2 | 3 |
| 4 | tras `kernel_startup_bootstrap` | 0-4 | 5 |
| 6 | tras 6a | 0-6 | 7 |
| **8** | tras 6c | 0-8 y 10, 11, 12 (**falta el hueco del slot 9**) | **12** |
| 12 | tras `immediate_NMI` | 0-7 y 10, 11, 12 | 11 |
| 16 | antes de `arm_vm_physmap_init` | 0-16 salvo ninguno (12 ya dibujado) → 0-16 | 17 |
| 19 | justo antes de apagar TTBR0 | 0-19 | 20 |
Los bloques tienen **colores repetidos**; se cuentan por posición (y). El hueco del slot 9 (y=376) en h08 es normal.

## Cómo se interpreta cada intento
| Se ve | Significa |
|---|---|
| **Pantalla congelada** con N+1 bloques en la columna | el kernel **llegó** al bloque N; el reinicio es posterior |
| El reinicio de siempre (azul/cian/magenta + `XNU MMU ON`, sin columna) | el kernel **no llegó** al bloque N; el reinicio es anterior |
| Congelada pero con menos bloques de los esperados | revisar: algún bloque no se dibujó (mirar el vídeo) |
| Negro o algo nuevo | transcribir literal |

## Orden de la búsqueda (mínimo de escrituras)
1. **h08** (escrita, E-0059/0060). Si **congela** → siguiente **h12**; si **no** → **h04**.
2. Tras h12 congelada → **h16**, luego **h19**; si h19 también congela, el reinicio es **después** de apagar TTBR0: siguiente paso = marcas tras `serial_init` (kernel nuevo).
3. Tras h04 no congelada → **h02**; tras h04 congelada → **h06**.
Imágenes ya construidas y verificadas (E-0061…E-0066): h02, h04, h06, h12, h16, h19. La tanda permite 8 escrituras: h08 + 7.
