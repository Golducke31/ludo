# BLENDER_RELIEF — relieve y rugosidad del tablero 3D

Cómo quitar el aspecto "excesivamente liso" del kit del tablero
(`assets/models/*.glb`) añadiendo **relieve (bump/normal)**, **rugosidad
variable** y **moteado de albedo**, y cómo hornearlo (bake) a texturas que
Godot sí puede mostrar.

## 1. Diagnóstico (por qué se ve liso)

Inspección de los GLB originales (`tools/inspect_glb.py`):

| Hecho | Consecuencia |
|---|---|
| `images = 0` en todos los GLB | Los materiales son **color plano**, sin ninguna textura. |
| Sin atributo `NORMAL` en la malla | Sombreado plano: no hay micro-variación de superficie. |
| `TEXCOORD_0` diminuto o ausente (la base del tablero **no tiene UVs**) | Aunque se añada una textura, el detalle se comprime en un rincón del mapa. |

Conclusión: hay que **descomprimir los UVs**, construir un material procedural
con relieve y **hornearlo** a imágenes. glTF no exporta nodos procedurales: sin
bake, el relieve no llega a Godot.

## 2. Pasos

### 2.1 Automático (recomendado, reproducible)

```bash
# Piezas pequeñas (tiles, carriles, banderines) a 512 px
blender --background --python tools/blender_relief.py -- \
  --in  "<proyecto>/assets/models" \
  --out "<proyecto>/assets/models" \
  --res 512 --only "Tile_,FinalLane6,Banner_"

# Piezas grandes (base, plataformas, altar, mansión) a 1024 px
blender --background --python tools/blender_relief.py -- \
  --in "<proyecto>/assets/models" --out "<proyecto>/assets/models" \
  --res 1024 --only "HomePlatform,tablero_halloween_base,altar_calabaza,mansion_embrujada"
```

El script hace, por cada GLB:

1. **UV**: **un atlas COMPARTIDO por asset** — modo edición multi-objeto,
   *Smart UV Project* (`angle_limit = 66°`, `island_margin = 0.02`) sobre todas
   las mallas y **un solo `pack_islands`** (`margin = 0.02`, `rotate = True`).
   ⚠️ Empaquetar **por objeto** es el error clásico: cada objeto escala sus islas
   a 0–1 y **se solapan** entre sí (el cuerpo de la casilla y su motivo acaban
   peleando por los mismos téxeles).
2. **Material de relieve** por perfil según el nombre del material
   (stone / wood / gold / tint) — ver tabla de valores.
3. **Bake** de cuatro mapas al atlas compartido: `NORMAL` (tangente),
   `ROUGHNESS`, `AO` y `DIFFUSE`. Ajustes: `margin = 16 px`, `samples = 8`,
   `use_denoising = False`.
   ⚠️ **`use_clear` solo en el primer objeto**: si se limpia en cada uno, cada
   bake borra los anteriores y en la textura **solo sobrevive la última malla**
   (la superficie queda casi negra con motas claras). Para el color:
   `DIFFUSE` con `use_pass_direct = False`,
   `use_pass_indirect = False`, `use_pass_color = True` (la escena de bake no
   tiene luces: sin filtrar el pase COLOR el albedo sale **negro**).
4. **Albedo** = color horneado × `AO^0.85` (oscurece grietas y rincones).
5. **Reconexión + export**: el material se reconstruye con las imágenes
   horneadas (Base Color ← albedo, Roughness ← rugosidad, Normal Map ← normal
   con `strength = 1.0`) y se re-exporta el GLB **con las texturas embebidas**.
6. Copia los PNG sueltos en `assets/models/baked/` por si se quieren editar.

### ⚠️ Trampa 3 — nunca hornear sobre tu propia salida (pierde el color)

El albedo se hornea leyendo `Base Color` del material de origen. En el kit
original esa entrada tiene el **color plano** (`default_value`, p. ej.
`special_orange` = 0.92/0.46/0.10) y **no está conectada**. Pero tras un primer
bake, el material reconstruido tiene `Base Color` **conectado a la textura de
albedo**, y entonces `default_value` cae al gris por defecto (0.8).

Consecuencia: si vuelves a ejecutar el script con `--in` apuntando a una carpeta
ya horneada, **todo el kit se vuelve gris**. Lo delata el nombre del material:
`relief_relief_relief_special_orange` (prefijo repetido = se horneó varias veces).

Blindaje aplicado en `tools/blender_relief.py`:

- `clean_name()` elimina los prefijos repetidos (`relief_relief_…` → `relief_…`).
- `base_color_of()` detecta `Base Color` conectado y promedia la textura enlazada
  para recuperar el tinte en vez de caer al gris.
- El script avisa por consola si el asset de entrada ya estaba horneado.

Regla de oro: **`--in` debe apuntar siempre a los GLB prístinos** (los del
`Desktop/ludo` original). Con `--in` = `--out` = `assets/models` funciona
mientras esos ficheros sean los originales, que es el caso tras restaurarlos.

### Comprobación rápida tras el bake

Midiendo **solo los píxeles de isla** del albedo (luminancia > 0.02; el fondo
del atlas es negro):

| Métrica | Valor sano | Síntoma si falla |
|---|---|---|
| Luminancia media de isla | **0.60 – 0.90** | **0.30** ⇒ se perdió todo menos la última malla (`use_clear` por objeto) |
| Reparto de islas | la pieza **más grande** ocupa la mayor parte del mapa y las pequeñas quedan como islas proporcionalmente diminutas | islas del mismo tamaño apiladas ⇒ `pack_islands` por objeto (solape) |
| Cobertura del atlas | depende del asset | no es un umbral fijo: `pack_islands` **preserva la densidad de téxeles relativa**, así que un asset con piezas de tamaños muy dispares (una plataforma de 2,76 uds + 6 motivos de 0,15) deja mucho negro **a propósito** |
| Rugosidad media de isla | **0.45 – 0.70** (mate) | < 0.35 ⇒ aspecto plastificado |

En el motor, el síntoma de un atlas roto se ve como **superficie casi negra con
motas claras** (los UVs caen en el fondo negro del mapa). Si eso aparece,
revisa primero `use_clear` y el empaquetado multi-objeto.

### 2.2 Manual (mismos pasos en la UI de Blender)

1. Importar el GLB (`File > Import > glTF 2.0`).
2. `Object Data Properties > UV Maps`: **seleccionar TODAS las mallas** y entrar
   en modo edición (Tab) con todas activas → `U > Smart UV Project`
   (`Angle Limit 66°`, `Island Margin 0.02`) → `U > Pack Islands`
   (`Margin 0.02`). Empaquetar con todas las mallas seleccionadas a la vez es lo
   que reparte las islas en un atlas común sin solapes.
3. `Shader Editor`: crear el material (perfil de la tabla), con
   `Texture Coordinate (Object) → Noise/Voronoi → Bump → Principled.Normal`
   y `Noise → Map Range → Principled.Roughness`.
4. `Render Properties > Render Engine = Cycles`; en `Bake`:
   `Bake Type = Normal` (`Space = Tangent`), `Margin = 16 px`, `Samples = 8`.
   Con el objeto seleccionado y un nodo **Image Texture** (imagen nueva
   `Non-Color`) **activo** → botón `Bake`. Para el segundo objeto y siguientes
   del mismo asset: **desmarcar `Clear Image`** (si no, se borra lo horneado por
   los anteriores) y repetir con `Roughness`, `Ambient Occlusion` y `Diffuse`
   (solo pase Color: desmarcar `Direct` e `Indirect`).
5. Guardar las imágenes (`Image > Save As`, PNG).
6. Reconectar: `Image Texture → Normal Map → Principled.Normal`, la rugosidad
   a `Principled.Roughness`, el albedo a `Base Color`.
7. `File > Export > glTF 2.0` (`.glb`, `Apply Modifiers`).

## 3. Valores recomendados

Perfiles del script (`PROFILES` en `tools/blender_relief.py`). Se aplican por
nombre de material: `*tint*` → tint, `*gold|ring|star|emblem|glow*` → gold,
`*wood|spine*` → wood, resto → stone.

| Parámetro | stone | wood | gold | tint |
|---|---:|---:|---:|---:|
| Ruido fino — `Scale` | **32** | 9 | 40 | 48 |
| Ruido fino — `Detail` | **8** | 6 | 6 | 6 |
| Ruido fino — `Roughness` | **0.62** | 0.70 | 0.55 | 0.55 |
| Voronoi (grietas) — `Scale` | **11** | 26 | 14 | 18 |
| Voronoi — `Randomness` | **1.0** | 0.9 | 1.0 | 1.0 |
| Bump fino — `Strength` | **0.28** | 0.22 | 0.18 | 0.14 |
| Bump fino — `Distance` | **0.012** | 0.010 | 0.008 | 0.006 |
| Bump grietas — `Strength` | **0.55** | 0.35 | 0.30 | 0.22 |
| Bump grietas — `Distance` | **0.030** | 0.018 | 0.014 | 0.010 |
| Rugosidad base | **0.62** | 0.70 | 0.30 | 0.55 |
| Rugosidad ±variación | **0.22** | 0.16 | 0.12 | 0.12 |
| Metallic | **0.0** | 0.0 | **0.85** | 0.0 |
| Moteado de albedo | **8 %** | 7 % | 5 % | 4 % |

Notas de ajuste:

- **Demasiado ruido / "arena"**: baja `Bump fino Strength` a 0.18–0.22 y sube
  `Distance` a 0.008 (más suave y ancho).
- **Grietas exageradas**: baja `Bump grietas Strength` a 0.35 y sube el
  `ColorRamp` de 0.08 a 0.12 (grietas más finas).
- **Superficie "plastificada"**: sube `Rugosidad base` a 0.70–0.75 y la
  variación a 0.25 (la rugosidad variable es lo que más "mata" el plástico).
- La red de grietas se encadena **debajo** del bump fino
  (`bump_crack.Normal → bump_fine.Normal`), así el grano se suma al relieve
  grande en vez de competir con él.

## 4. Valores del lado Godot

El GLB re-exportado ya trae albedo + rugosidad + normal embebidos; Godot crea
el `StandardMaterial3D` automáticamente. Recomendado tras importar:

| Ajuste | Valor | Por qué |
|---|---|---|
| `normal_scale` | **1.0** (subir a 1.2 si se quiere más relieve) | El bake ya trae la fuerza real; >1.3 produce artefactos. |
| `uv1_scale` | **(1, 1, 1)** — no repetir | Los UVs están empaquetados 0–1 y el detalle es único por objeto. |
| `roughness` | dejar **la textura** (no forzar valor) | La variación horneada es la que quita el aspecto liso. |
| Filtrado | **lineal** para estos GLB | Son texturas pintadas, no pixel art. |

## 5. Verificación

```bash
python tools/inspect_glb.py          # los GLB deben mostrar images > 0
python tools/hash_assets.py          # manifiesto actualizado
python tools/audit_palette.py        # paleta (neón/cian prohibidos)
bash   tools/run_tests.sh            # 3 PASS
```

Las fuentes maestras intactas viven en `C:/Users/emanu/Desktop/ludo/`: este
script sobreescribe las copias del proyecto, nunca las originales.
