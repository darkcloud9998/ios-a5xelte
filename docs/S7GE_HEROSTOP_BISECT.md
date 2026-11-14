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

## Resultado de h08 (E-0067, 2026-11-14)
**Congeló** con el texto de las marcas 1-6c y la columna derecha exactamente como se predijo (0-8, hueco del 9, 10-12). El kernel ejecuta `arm_init` **hasta la marca 6c** y la parada funciona: **el reinicio es POSTERIOR a la marca 6c.** Esto valida el método y cierra las preguntas anteriores (el texto sí se imprime; antes solo era fugaz).
Consecuencia: h02, h04, h06 y h12 **ya no aportan nada** (esos puntos se han pasado). Quedan, en **orden de ejecución**: `9` (tras la marca 7) → `13` (inicio de `arm_vm_init`) → `14` → `15` → `16` → `17` → `18` → `19` (justo antes de apagar TTBR0). 8 posibilidades ⇒ 3 escrituras bastan: **h16** primero; si congela → **h18** (luego 17 o 19); si no → **h14** (luego 13 o 15, y 9).
Imágenes listas y verificadas: h09, h13, h14, h15, h16, h17, h18, h19 (E-0068…E-0073 y E-0063…E-0066).

## Resultado de h16 (E-0075, 2026-11-14)
**Congeló.** Texto hasta `7: rb: physmap_init` y 17 bloques: 0-13, hueco en 14, 15 y 16. El hueco del slot 14 **es esperado**: el bloque y la marca `rb: physmap tables` están dentro de `#if defined(ARM_LARGE_MEMORY)`, que no se compila para herolte (comprobado en `arm_vm_init.c` ~2051-2060); tampoco aparece `rb: identity map` (KTRR/CTRR, no definido). El kernel llega al **bloque 16 = justo antes de `arm_vm_physmap_init`**. **El reinicio ocurre después**: dentro de `arm_vm_physmap_init`, tras ella o más tarde.
Quedan: `17` (tras `arm_vm_physmap_init`), `18` (tras `set_mmu_ttb_alternate`), `19` (antes de apagar TTBR0). Siguiente: **h17**. Si **no** congela ⇒ el reinicio está **dentro de `arm_vm_physmap_init`** (mapeo de los bancos de RAM; el sospechoso histórico, 0326-0329); si congela ⇒ h18, luego h19.

## Resultado de h17 (E-0077, 2026-11-14)
**Congeló** con `7: rb: extra banks` y `7: rb: extra banks mapped` y un bloque nuevo al final de la columna (slot 17). **`arm_vm_physmap_init` termina bien.** El reinicio es posterior al bloque 17: quedan `18` (tras `set_mmu_ttb_alternate`, el cambio de TTBR1 a la tabla final), `19` (justo antes de apagar TTBR0) y lo que viene después (sin pantalla: el alias del framebuffer desaparece). Siguiente: **h18**.

## Resultado de h18 (E-0079, E-0080, 2026-11-14)
**Congeló con el bloque 18 visible** (el Director aclaró: los dos últimos bloques eran cian y marrón chocolate). **`set_mmu_ttb_alternate` se supera**: el kernel ejecuta con la tabla TTBR1 final. El reinicio es posterior al bloque 18. Queda un punto con pantalla: **19** (justo antes de `set_mmu_ttb(invalid_ttep)`, que apaga TTBR0 y el alias del framebuffer). Siguiente: **h19**. Si h19 congela ⇒ el reinicio está **después de apagar TTBR0** (sin pantalla; hace falta un kernel nuevo con un alias del framebuffer en la tabla final); si no congela ⇒ está entre 18 y 19 (`ml_enable_monitor` y poco más).
