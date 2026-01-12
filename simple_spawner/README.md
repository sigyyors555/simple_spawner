# Simple Spawner (Horses & Peds)

A standalone RedM script for spawning persistent herds of horses or groups of peds at specific coordinates. This script is designed to be lightweight, performance-friendly, and highly customizable.

## 🌟 Features

*   **Herd Spawning:** Spawn multiple horses or peds in a group with a customizable radius.
*   **Persistent & Performance Friendly:** Entities spawn when players are nearby and automatically despawn when players leave the area.
*   **Wild Horse Support:** Spawned horses act like genuine wild animals (grazing, wandering, and fleeing when spooked).
*   **Custom Breaking System:** Includes a built-in minigame to break wild horses by mounting them and pressing keys (Spacebar/Enter/E).
*   **Visibility Fix:** Automatically applies random outfit/coat variations to ensure horses are visible and have diverse appearances.
*   **Standalone:** Works on any framework (RSG, Vorp, RedEM:RP, etc.) as it relies primarily on native RedM logic.
*   **Debug Blips:** Optional (enabled by default) map blips to help locate spawned wild horses.

## 🛠️ Installation

1.  Download the `simple_spawner` folder.
2.  Place it in your server's `resources/[standalone]` directory.
3.  Add `ensure simple_spawner` to your `server.cfg`.
4.  (Optional) Ensure `ox_lib` is installed if you want to use the notification system.

## ⚙️ Configuration (`config.lua`)

The script is configured via `config.lua`. You can add as many herds as you like.

```lua
Config.Herds = {
    {
        name = "Valentine Herd",
        coords = vector3(-5590.86, -3059.03, 1.74), -- Center point
        radius = 15.0,                             -- Spreading distance
        amount = 4,                                -- Number of entities
        models = {                                 -- Models to pick randomly from
            "a_c_horse_arabian_white",
            "a_c_horse_morgan_bay",
        },
        wander = true,                             -- true: wander around | false: graze in place
        invincible = false,                        -- Should they be killable/tamable?
    },
}
```

## 🏇 Taming & Adoption

*   **Breaking:** Approach a spawned wild horse and mount it. A progress bar will appear. Press **SPACEBAR** repeatedly to calm the horse until the bar reaches 100%.
*   **Adoption:** Once broken, the horse is marked as tamed. If you use a horse stable script (like SireVLC), you should be able to "Adopt" or "Save" the horse to your stable as usual.

## 📜 Requirements

*   `ox_lib` (For notifications and progress bars).

## 🚀 Technical Details

*   **Native Z-Check:** Uses raycasting to ensure horses spawn exactly on the ground, preventing them from falling through the map or spawning in the air.
*   **Outfit Logic:** Invokes specific game natives (`0x283978A15512B2FE`) to force the engine to render coats, fixing the common "invisible horse" bug in RedM.
