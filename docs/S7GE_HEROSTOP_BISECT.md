# S7GE — bisección con `herostop=N` (tanda D-0041, 2026-11-14)
**Qué es:** el kernel (0341) congela la CPU (`wfe` en bucle) justo después de dibujar el bloque N de la columna x≈1300. Con eso el resultado es una **imagen fija**, no unos fotogramas fugaces. Cada imagen = la misma que min2 más `herostop=N`.

## Slots (columna derecha, de arriba abajo; y = 88 + 32·slot)
0 `arm_init` entrada · 1 `PE_init_platform`… (ver `S7GE_MIN5_DESIGN.md`, `S7GE_ARM_VM_INIT_ANALYSIS.md` §4). Para esta bisección: **2** tras `PE_init_platform` · **4** tras `cpu_bootstrap` · **6** tras 6a (`processor_bootstrap`) · **8** tras 6c · **12** tras `immediate_NMI`, justo antes de `arm_vm_init` · **16** antes de `arm_vm_physmap_init` · **19** justo antes de apagar TTBR0.
(Los slots 0 y 1 no pueden congelar: el 0 va antes de leer la boot-arg y el 1 se dibuja con la marca de etapa 2, ver patch.)

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
