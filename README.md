# Serene Driving

A calm, endless 3D driving game for iPhone. No missions, no timers, no score —
you drive, and every minute the world quietly becomes somewhere else.

## The idea

You start in an endless forest. Every 60 seconds the scene fades and you arrive
somewhere new, with a vehicle that suits it:

| World            | Vehicle    | Notes                                        |
|------------------|------------|----------------------------------------------|
| Whispering Forest| car        | rolling hills, pines, drifting pollen        |
| Amber Dunes      | quad       | ridged dunes, cacti, blown sand              |
| Sunlit Shore     | quad       | sand, lagoons, palms                         |
| Open Sea         | boat       | faceted waves, islands, buoys                |
| Quiet Snowfield  | car        | falling snow, snow-capped pines              |
| Moon Basin       | rover      | craters, Earth in the sky, long shadows      |
| Deep Space       | spaceship  | asteroid field, nebula, no ground at all     |

## Controls

Drag anywhere on screen. A thumb-stick appears where you touch: up to accelerate,
down to brake and reverse, left/right to steer. Release and the vehicle coasts.

Three buttons, top right:
- **speaker** — mute the generated ambient audio
- **leaf / bolt** — Serene mode ↔ Speed mode
- **cycle** — skip to the next world now

## Two modes

- **Serene** — gentle speeds, high grip, made for wandering.
- **Speed** — ~1.85× top speed, sharper steering and much lower lateral grip, so
  the vehicle slides through corners. Braking mid-corner breaks the back end
  loose. Sliding throws tyre smoke and leaves deeper marks.

## What's procedural

Everything. There are no art assets in the project — the whole game is generated
in code at runtime:

- **Terrain** — value-noise height fields, streamed as 80 m chunks around the
  player and rebuilt as flat-shaded, vertex-coloured low-poly meshes.
- **Skies** — each world's sky is drawn with Core Graphics into an equirectangular
  image, used as both the background and the image-based lighting environment.
- **Props** — trees, cacti, palms, rocks, asteroids and satellites are built from
  primitives and faceted icosahedral blobs, then cloned across chunks.
- **Vehicles** — assembled from boxes, cylinders and cones.
- **Audio** — a slow chord pad, wind and engine hum synthesised sample-by-sample
  with `AVAudioSourceNode`. Nothing loops.
- **App icon** — rendered by `icon.swift` (see repo history).

## Systems worth knowing about

- `VehicleController` — kinematic driving with real lateral inertia. Steering
  rotates the body first, then the world velocity is re-read in the new body
  frame; whatever sideways component is left over *is* the drift, scrubbed off at
  a `traction` rate. Nothing can flip or crash.
- `TerrainSystem` — chunk streaming plus a collider registry. Every prop with a
  solid base registers a circle; the controller pushes out of overlaps and keeps
  only the tangential motion, so you scrape past a trunk instead of stopping dead.
- `TrackSystem` — tyre marks on sand, snow and moon dust. Both ribbons live in one
  geometry that is rebuilt when a new sample is laid, and the tail dissolves back
  into the ground colour.
- `WaterSystem` — two layers: a flat plane out to the horizon and a faceted wave
  mesh around the player, regenerated at 30 Hz. The boat floats on exactly the
  surface that is drawn.
- `AmbienceDirector` — every 10–22 s something small happens nearby: a deer walks
  past, a flock crosses, dolphins leap, a tumbleweed rolls, a star falls.

## Build

```bash
./build-run.sh                    # build, install and launch on the simulator
SD_DEVICE="iPhone 16" ./build-run.sh
python3 gen_pbxproj.py            # regenerate the project after adding files
```

Portrait only. iOS 17+. Bundle id `com.lno.serenedriving`.

## Releasing to TestFlight

Two paths, both needing an App Store Connect API key (Users and Access →
Integrations → App Store Connect API).

**CI** — every push to `main` runs `.github/workflows/testflight.yml`. Add these
repo secrets under Settings → Secrets and variables → Actions:

| Secret | Where it comes from |
|---|---|
| `ASC_KEY_ID` | the `XXXX` in `AuthKey_XXXX.p8` |
| `ASC_ISSUER_ID` | shown above the key list in App Store Connect |
| `ASC_KEY_P8` | the full contents of the `.p8` file |
| `IOS_DEV_CERT_P12` | `base64 -i CI_Development.p12` |
| `IOS_DEV_CERT_PASSWORD` | the password for that `.p12` |

**From this Mac** — no secrets stored anywhere:

```bash
export ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=…/AuthKey_….p8
./release.sh
```
