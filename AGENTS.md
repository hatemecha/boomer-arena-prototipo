Para empezar bien, yo lo plantearía como **un arena shooter PSX/boomer shooter pequeño, rápido, feo a propósito y muy optimizado**, antes que intentar hacer “un FPS grande”. La clave es que desde el día 1 el juego corra bien en una PC basura y recién después agregar contenido.

Te dejo un roadmap pensado para **Godot 4**, porque ya venís trabajando con eso y te conviene mantenerte ahí.

---

# Objetivo base del juego

Un **arena shooter low poly para 2 jugadores**, con estética PlayStation 1, mapas cerrados, enemigos o bots simples opcionales, armas rápidas y movimiento ágil.

Prioridades:

1. Que corra en PC de bajos recursos.
2. Que se sienta divertido rápido.
3. Que tenga estética PSX coherente.
4. Que sea jugable con un amigo.
5. Que sea fácil de ampliar sin romper todo.

No busques realismo. Buscá una mezcla de:

* **Quake**
* **Doom**
* **Unreal Tournament viejo**
* **DUSK**
* **ULTRAKILL pero más simple**
* **Silent Hill / PSX en lo visual**
* **FNAF fangames en peso/ambiente si usás enemigos pesados**

---

# Fase 0 — Definir límites técnicos

Antes de tocar mucho código, definí estas reglas:

## Resolución objetivo

El juego debería renderizarse internamente a baja resolución, por ejemplo:

```txt
426x240
640x360
800x450
```

Y luego escalarse a pantalla completa.

Para PC muy baja, recomiendo:

```txt
640x360 interno
```

Con opción de bajar a:

```txt
426x240
```

Esto te da estética PSX y rendimiento.

---

## Target de FPS

Definí dos perfiles:

```txt
Modo rendimiento: 60 FPS estables
Modo ultra bajo: 30 FPS estables
```

No te obsesiones con gráficos. Si se ve feo pero corre perfecto, vas bien.

---

## Reglas visuales

Para que parezca PSX:

* Modelos low poly.
* Texturas chicas: 64x64, 128x128, máximo 256x256.
* Sin materiales complejos.
* Sin luces dinámicas excesivas.
* Sin sombras pesadas.
* Sin postprocesado caro.
* Paleta de color limitada.
* Dithering/filtro de color si podés.
* Movimiento de cámara con un toque tosco.
* Geometría simple, angular, algo “rota”.

---

# Fase 1 — Prototipo jugable mínimo

Esta fase tiene un solo objetivo: **entrar al juego, moverte, disparar y divertirte 30 segundos**.

## 1. Controlador del jugador

Necesitás un `PlayerController` limpio.

Debe tener:

* Caminar.
* Correr.
* Saltar.
* Doble salto opcional.
* Agacharse opcional.
* Aceleración rápida.
* Fricción clara.
* Control aéreo moderado.
* Sensibilidad configurable.
* FOV configurable.

Para boomer shooter, el movimiento tiene que sentirse así:

```txt
Rápido, seco, predecible, sin animaciones que estorben.
```

No hagas al personaje “realista”. Tiene que responder al instante.

---

## 2. Cámara

La cámara debería tener:

* FOV alto, por ejemplo 85–100.
* Bobbing sutil o desactivable.
* Pequeño recoil visual al disparar.
* Shake muy leve al recibir daño.
* Nada que maree demasiado.

Para PSX, podés agregar después:

* Resolución baja.
* Pixelación.
* Color limitado.
* Filtro de textura nearest.
* Warping ligero si querés imitar PlayStation.

---

## 3. Arma inicial

Hacé una sola arma primero.

Recomiendo empezar con una **pistola automática / SMG simple**.

Debe tener:

* Disparo con click.
* Raycast.
* Cadencia.
* Daño.
* Munición.
* Recarga con `R`.
* Recoil mínimo.
* Sonido seco.
* Muzzle flash simple.
* Decal o impacto básico.

Nada de animaciones complejas todavía.

Estados mínimos:

```txt
Idle
Firing
Reloading
NoAmmo
```

---

## 4. HUD mínimo

No hagas una HUD pixel art pesada al principio.

Usá una HUD minimalista:

```txt
VIDA: 100
ARMA: SMG
AMMO: 24 / 96
FPS: 60
PING: 20ms si hay online
```

Para desarrollo, también mostrás:

```txt
posición del jugador
velocidad actual
cantidad de objetos activos
cantidad de enemigos/balas
```

Eso te ayuda muchísimo a depurar.

---

# Fase 2 — Arena de prueba

Antes de hacer un mapa “lindo”, hacé una arena funcional.

## Mapa de prueba

Debe tener:

* Una zona central.
* Algunos pilares.
* Diferentes alturas.
* Rampas.
* Plataformas.
* Coberturas.
* Pasillos cortos.
* 2 o 4 puntos de spawn.
* Pickups de vida y munición.

La forma puede ser simple:

```txt
[spawn] — pasillo — arena central — pasillo — [spawn]
              |       |
           altura   cobertura
              |       |
           pickup   pickup
```

---

## Reglas para mapas low resource

Para que corra en PC baja:

* Pocas luces.
* Poca geometría.
* Nada de físicas complejas.
* No usar cientos de meshes separados.
* Reutilizar piezas.
* Texturas pequeñas.
* No abusar de partículas.
* No meter modelos pesados.
* No usar mapas gigantes.

El mapa ideal para empezar es chico, no enorme.

Algo como:

```txt
30m x 30m
```

O máximo:

```txt
50m x 50m
```

---

# Fase 3 — Estética PSX real

Esta fase es importante, pero no debería venir antes de que el juego sea jugable.

## Look visual recomendado

Usá una dirección clara:

```txt
PSX oscuro, sucio, industrial, pocos colores, rojo como color de peligro.
```

Como vos venís buscando blanco/negro/rojo y ambientes por hora, podés hacer:

### Mañana

```txt
colores lavados
niebla clara
sombras suaves
luz amarillenta pálida
```

### Tarde

```txt
naranjas apagados
rojos más presentes
sombras largas
más contraste
```

### Noche

```txt
azules/grises fríos
rojos fuertes
poca visibilidad
luces puntuales
```

Pero mantené paleta limitada.

Ejemplo:

```txt
Negro
Gris oscuro
Gris cemento
Rojo sangre
Amarillo sucio
Azul frío
Verde enfermo opcional
```

No uses 40 colores. La PSX se siente mejor cuando hay restricción.

---

## Texturas

Usá texturas:

```txt
64x64
128x128
```

Con:

* Pared de concreto.
* Metal oxidado.
* Piso industrial.
* Sangre o manchas.
* Señales rojas.
* Rejillas.
* Cielo simple.

Importante: filtro de textura en `nearest`.

Nada de suavizado moderno.

---

## Modelos

Regla general:

```txt
Mientras menos polígonos, mejor.
```

Para armas:

```txt
300 a 1000 triángulos
```

Para props:

```txt
50 a 500 triángulos
```

Para personajes:

```txt
800 a 2000 triángulos
```

Si metés un `.glb` más pesado, hacelo solo para enemigos importantes, no para todo.

---

# Fase 4 — Pickups y loop de arena

Ahora armás el loop del juego.

## Pickups mínimos

Necesitás:

* Vida pequeña.
* Vida grande.
* Munición.
* Armadura opcional.
* Arma nueva.
* Power-up opcional.

Ejemplo:

```txt
+25 vida
+50 vida
+30 balas SMG
+8 cartuchos escopeta
```

Los pickups deberían tener:

* Modelo simple.
* Giro lento.
* Glow barato o material emisivo.
* Sonido al recoger.
* Respawn después de X segundos.

---

## Loop de arena

Para jugar con un amigo, podés empezar con esto:

```txt
Aparecen ambos jugadores.
Corren por el mapa.
Recogen armas y munición.
Se disparan.
Mueren.
Respawnean.
Gana quien llega a X kills.
```

Modo básico:

```txt
Deathmatch 1v1
```

Reglas:

```txt
10 kills para ganar
respawn a los 3 segundos
invulnerabilidad 1 segundo al respawnear
pickup de vida cada 20 segundos
pickup de ammo cada 15 segundos
```

---

# Fase 5 — Multiplayer

Esta es una decisión importante.

Tenés tres caminos.

---

## Opción A — Pantalla dividida local

Es lo más simple y confiable.

Ventajas:

* No necesitás red.
* Ideal para jugar con un amigo en la misma PC.
* Menos bugs.
* Corre offline.
* Más fácil de terminar.

Desventajas:

* Necesitás dos controles o teclado + joystick.
* Renderiza dos cámaras, puede consumir más.

Para PC muy baja, puede ser pesado, pero si el juego es low poly debería andar.

---

## Opción B — LAN

Buena opción si cada uno tiene su PC.

Ventajas:

* Más cómodo.
* Una cámara por PC.
* Mejor rendimiento.
* No dependés de internet.

Desventajas:

* Más complejidad técnica.
* Sincronización de jugadores.
* Lag local menor pero existe.
* Tenés que manejar host/client.

---

## Opción C — Online

No lo recomiendo para empezar.

Ventajas:

* Podés jugar a distancia.

Desventajas:

* Mucho más difícil.
* NAT, puertos, lag, predicción, interpolación.
* Más bugs.
* Te puede consumir semanas.

---

## Recomendación

Para empezar:

```txt
Primero: singleplayer con dummy/bot.
Segundo: pantalla dividida local o LAN.
Tercero: online solo si el juego ya funciona.
```

Si tu amigo está cerca o pueden jugar en la misma PC:

```txt
Split-screen local.
```

Si cada uno tiene su PC:

```txt
LAN host/client.
```

---

# Fase 6 — Armas

No agregues 10 armas de golpe.

Hacé 3 armas buenas.

## Arma 1 — Pistola / SMG

Función:

```txt
arma base rápida
daño medio
cadencia alta
precisión decente
```

Ideal para empezar.

---

## Arma 2 — Escopeta

Función:

```txt
daño alto de cerca
mala a distancia
satisfactoria
```

Debe sentirse fuerte.

Elementos:

* Varios raycasts.
* Spread.
* Recoil más fuerte.
* Recarga lenta o por cartucho.

---

## Arma 3 — Lanzador / Rifle pesado

Función:

```txt
arma de control de zona
proyectil visible
daño explosivo
```

Para arena shooter suma muchísimo.

Puede ser:

* Lanzagranadas.
* Rocket launcher simple.
* Rifle de plasma lento.

---

# Fase 7 — Bots o enemigos simples

Como es para jugar con un amigo, los enemigos no son obligatorios. Pero pueden servir para probar.

## Bot básico

Estados:

```txt
Idle
Patrol
Chase
Attack
Retreat
Dead
```

Para PC baja, evitá navegación compleja si podés.

Opciones:

* NavMesh simple.
* Movimiento por puntos.
* Raycast para detectar jugador.
* Ataque cuando tiene línea de visión.

Para arena shooter, un bot tonto pero agresivo puede alcanzar.

---

## Enemigo pesado estilo FNAF fangame

Si querés usar un modelo tipo `springrap.glb`, hacelo como enemigo especial:

Comportamiento:

```txt
camina lento
pesa mucho
hace ruido
aparece en esquinas
se acerca directo
pega fuerte
no corre todo el tiempo
```

No lo uses como enemigo común si el modelo es pesado.

---

# Fase 8 — Optimización desde el inicio

Esta fase no va al final. Va desde el primer día.

## Configuración gráfica

Opciones mínimas:

```txt
Resolución interna: 426x240 / 640x360 / 800x450
Pantalla completa: on/off
VSync: on/off
FPS cap: 30/60/120
Sombras: off/low
Luces dinámicas: off/low
Postprocesado PSX: on/off
Partículas: low/high
```

---

## Cosas a evitar

No uses:

* Luces dinámicas por todos lados.
* Sombras en tiempo real innecesarias.
* Muchos rigidbodies.
* Muchos nodos sueltos.
* Partículas caras.
* Texturas grandes.
* Modelos con demasiados polígonos.
* Shaders complejos.
* IA compleja.
* Mapas enormes.

---

## Pooling

Para balas, impactos y partículas usá pooling.

En vez de crear y destruir objetos todo el tiempo:

```txt
crear una cantidad inicial
activar cuando se usa
desactivar cuando termina
reutilizar
```

Esto ayuda mucho en PCs bajas.

---

# Fase 9 — Sonido

El sonido en un boomer shooter es más importante de lo que parece.

Necesitás sonidos claros:

* Disparo.
* Recarga.
* Sin munición.
* Daño recibido.
* Muerte.
* Pickup.
* Respawn.
* Paso.
* Impacto en pared.
* Impacto en carne.
* Música de arena.

Para PSX:

* Sonidos comprimidos.
* Algo secos.
* Poca reverb.
* Música corta en loop.
* Ambientes industriales o de terror.

---

# Fase 10 — Menú y flujo completo

No hagas un menú gigante. Hacé esto:

```txt
Jugar
Opciones
Salir
```

Dentro de jugar:

```txt
Singleplayer test
1v1 local
LAN host
LAN join
```

Opciones:

```txt
Resolución interna
Pantalla completa
Sensibilidad
FOV
Volumen
VSync
FPS cap
Preset visual: Mañana / Tarde / Noche
```

---

# Roadmap por semanas

## Semana 1 — Base jugable

Objetivo: moverse y disparar.

Tareas:

```txt
- Crear proyecto limpio.
- PlayerController.
- Cámara.
- Arma inicial.
- Raycast de disparo.
- HUD simple.
- Arena gris de prueba.
- Contador de FPS.
- Recarga con R.
- Ammo pickup.
- Health pickup.
```

Resultado esperado:

```txt
Puedo correr por una arena, disparar, recargar y recoger munición.
```

---

## Semana 2 — Feel boomer shooter

Objetivo: que se sienta bien.

Tareas:

```txt
- Ajustar velocidad.
- Ajustar salto.
- Ajustar fricción.
- Agregar recoil.
- Agregar impactos.
- Agregar sonidos.
- Agregar daño.
- Agregar muerte/respawn.
- Agregar spawn points.
- Agregar escopeta.
```

Resultado esperado:

```txt
Ya es divertido moverse y disparar aunque sea feo.
```

---

## Semana 3 — Estética PSX

Objetivo: que tenga identidad.

Tareas:

```txt
- Texturas low res.
- Materiales nearest.
- Paleta limitada.
- Resolución interna baja.
- Filtro de color.
- Niebla.
- Preset mañana/tarde/noche.
- Modelos low poly para pickups.
- Arma low poly visible.
- Props simples.
```

Resultado esperado:

```txt
Se ve intencionalmente PSX, no simplemente feo.
```

---

## Semana 4 — Multiplayer básico

Objetivo: jugar con tu amigo.

Tareas según opción:

### Si hacés split-screen

```txt
- Input Player 1.
- Input Player 2.
- Dos cámaras.
- Viewports divididos.
- Respawn separado.
- Scoreboard.
- 10 kills para ganar.
```

### Si hacés LAN

```txt
- Host.
- Join.
- Sincronizar posición.
- Sincronizar disparos.
- Sincronizar vida.
- Sincronizar muerte.
- Sincronizar score.
```

Resultado esperado:

```txt
Ya pueden jugar 1v1.
```

---

## Semana 5 — Mapa real

Objetivo: una arena buena.

Tareas:

```txt
- Diseñar layout definitivo chico.
- Poner verticalidad.
- Poner coberturas.
- Poner pickups con intención.
- Testear spawns.
- Mejorar iluminación.
- Optimizar geometría.
- Agregar zonas visualmente reconocibles.
```

Resultado esperado:

```txt
Hay un mapa simple pero rejugable.
```

---

## Semana 6 — Pulido mínimo

Objetivo: que parezca juego y no prototipo.

Tareas:

```txt
- Menú principal.
- Menú de pausa.
- Opciones gráficas.
- Opciones de audio.
- Pantalla de victoria.
- Sonidos finales.
- Música.
- Balance de armas.
- Bugs grandes.
- Export para Windows/Linux.
```

Resultado esperado:

```txt
Build jugable para pasarle a tu amigo.
```

---

# Estructura recomendada del proyecto

Algo así:

```txt
res://
  scenes/
    main/
      Main.tscn
      Game.tscn
    player/
      Player.tscn
      PlayerCamera.tscn
    weapons/
      WeaponBase.tscn
      SMG.tscn
      Shotgun.tscn
      RocketLauncher.tscn
    maps/
      TestArena.tscn
      Arena01.tscn
    pickups/
      AmmoPickup.tscn
      HealthPickup.tscn
      ArmorPickup.tscn
    ui/
      HUD.tscn
      MainMenu.tscn
      PauseMenu.tscn
    multiplayer/
      NetworkManager.tscn

  scripts/
    player/
      player_controller.gd
      player_health.gd
      player_input.gd
    weapons/
      weapon_base.gd
      hitscan_weapon.gd
      projectile_weapon.gd
    pickups/
      pickup_base.gd
      ammo_pickup.gd
      health_pickup.gd
    game/
      game_manager.gd
      spawn_manager.gd
      score_manager.gd
    ui/
      hud.gd
      pause_menu.gd

  assets/
    models/
    textures/
    sounds/
    music/
    materials/
    fonts/
```

---

# Sistemas principales que deberías tener

## Player

Responsable de:

```txt
movimiento
cámara
input
vida
arma actual
interacción con pickups
```

---

## WeaponBase

Todas las armas deberían heredar de una base.

Campos comunes:

```txt
damage
fire_rate
ammo_in_mag
mag_size
reserve_ammo
reload_time
recoil
spread
range
```

Métodos comunes:

```txt
fire()
reload()
can_fire()
add_ammo()
```

---

## GameManager

Responsable de:

```txt
estado de partida
inicio
fin
score
respawn
pausa
modo de juego
```

---

## SpawnManager

Responsable de:

```txt
elegir spawn seguro
respawnear jugadores
evitar spawn encima del enemigo
```

---

## PickupManager

Responsable de:

```txt
respawn de pickups
timers
activación/desactivación
```

---

# Checklist de rendimiento

Cada vez que agregues algo, revisá esto:

```txt
¿Bajaron los FPS?
¿Hay muchos nodos activos?
¿Hay muchas luces?
¿Hay partículas innecesarias?
¿El modelo tiene demasiados polígonos?
¿La textura es demasiado grande?
¿Estoy instanciando y destruyendo objetos todo el tiempo?
¿Hay scripts corriendo en _process sin necesidad?
¿Hay raycasts excesivos?
¿Hay físicas innecesarias?
```

Regla práctica:

```txt
Si algo no se ve durante gameplay, no debería costar rendimiento.
```

---

# Dirección artística recomendada

Yo iría por esto:

```txt
Arena industrial abandonada.
PlayStation 1.
Colores reducidos.
Rojo como señal de peligro.
Luces frías de noche.
Cielo plano.
Niebla.
Paredes sucias.
Armas deformes low poly.
HUD minimalista.
Sonido seco y agresivo.
```

Nombre interno posible:

```txt
PSX Arena Prototype
```

O algo más con identidad:

```txt
BLOOD PIT
RUST ARENA
KILLBOX
RED HOUR
LOWFIRE
```

---

# Orden correcto de desarrollo

No hagas esto:

```txt
1. Menú hermoso
2. Historia
3. Modelos lindos
4. Online
5. Armas complejas
6. Después gameplay
```

Hacé esto:

```txt
1. Movimiento
2. Disparo
3. Daño
4. Respawn
5. Pickups
6. Arena
7. Segunda arma
8. 1v1
9. Estética PSX
10. Menú
11. Pulido
```

---

# Primer milestone realista

Tu primera meta debería ser esta:

```txt
Build 0.1 — Arena Test
```

Contenido:

```txt
- 1 mapa gris.
- 1 jugador.
- Movimiento rápido.
- 1 arma.
- Recarga.
- Munición.
- Vida.
- Pickups.
- FPS visible.
- Resolución baja.
```

Después:

```txt
Build 0.2 — Combat Feel
```

Contenido:

```txt
- Escopeta.
- Sonidos.
- Recoil.
- Daño.
- Muerte.
- Respawn.
```

Después:

```txt
Build 0.3 — PSX Look
```

Contenido:

```txt
- Texturas low res.
- Paleta.
- Niebla.
- Iluminación por hora.
- Props low poly.
```

Después:

```txt
Build 0.4 — 1v1
```

Contenido:

```txt
- Segundo jugador.
- Score.
- Respawn.
- Victoria.
```

---

# Recomendación final

Empezá con un **prototipo feo pero jugable**. En un arena shooter, si el movimiento y las armas no son divertidas, no importa que parezca PSX. Primero tiene que sentirse bien. Después lo ensuciás, lo pixelás, le bajás la resolución, le metés niebla, texturas feas y luces rojas.

Tu orden debería ser:

```txt
Movimiento → arma → arena → pickups → muerte/respawn → estética → multiplayer → pulido
```

Ese camino te evita el error típico de hacer primero una estética linda y después descubrir que el juego no tiene loop.
