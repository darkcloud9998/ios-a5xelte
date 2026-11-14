#!/usr/bin/env python3
"""herolte-diag-patch-check.py PATCH... : ¿tocan los parches SOLO ficheros de diagnóstico de arranque temprano?

Respalda la autorización amplia de diagnóstico (D-0043): un kernel solo entra si todos los parches nuevos o cambiados
desde el último kernel aprobado tocan únicamente ficheros de esta lista blanca (arranque temprano: dibujo en pantalla,
marcas, boot-arg herostop, contadores). No juzga el CONTENIDO de los cambios: eso lo revisa y registra el ingeniero.
Salida 0 = todos dentro de la lista; 1 = algún parche toca otro fichero (se imprime cuál); 2 = uso incorrecto.
"""
import sys, re
ALLOWED = {
    'osfmk/arm/arm_init.c',
    'osfmk/arm64/arm_vm_init.c',
    'osfmk/arm64/start.s',
    'osfmk/arm64/sweet_early.c',
    'osfmk/arm64/sweet_early.h',
}
def files(path):
    out = []
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'^\+\+\+ b/(\S+)', line)
        if m: out.append(m.group(1))
    return out
def main(argv):
    if len(argv) < 2: print(__doc__); return 2
    bad = 0
    for p in argv[1:]:
        fs = files(p)
        if not fs: print('FALLA  %s: no se encontraron ficheros (¿parche vacío?)' % p); bad += 1; continue
        extra = [f for f in fs if f not in ALLOWED]
        if extra: print('FALLA  %s toca fuera de la lista blanca: %s' % (p, ', '.join(extra))); bad += 1
        else: print('OK     %s: %s' % (p, ', '.join(fs)))
    return 1 if bad else 0
if __name__ == '__main__': sys.exit(main(sys.argv))
