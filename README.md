# Brainrot Bay — a 3D Roblox brainrot collector

[![make.fun](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/cashbags/makefun-roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/cashbags/makefun-roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

An entry for make.fun's **roblox-brainrot-01** — "Make the best AI Roblox brainrot game" ($1,000 prize pool).

**Brainrot Bay** is a 3D Roblox game you play in Roblox's 3D world: you run around a sunny island, buy absurd meme-born characters off a conveyor belt, keep them on your own base, and watch them earn money every second. Climb the rarity ladder (Common → Rare → Epic → Legendary → Mythic → Brainrot God), chase Gold / Diamond / Rainbow / Cosmic mutations, and rebirth to double all future earnings forever. Two threats keep it tense: other players can hold E on your brainrots to steal them, and every four minutes a glowing wave sweeps the island — anyone caught outside their base loses 10% of their cash and is flung back to spawn, so every wave ends in a dash home.

Original cast, all invented for this game: Sir Toastalot, Captain Noodle, DJ Fridge, Baron Von Sock, Professor Pickle, Madame Microwave, Lord Llama Latte, General Gnome Chomps, Queen Quokka Couch, Turbo Toilet Terry, Sir Reginald Spoon and Emperor Eggplant.

## How to play

1. Walk onto a coloured pad to claim a base.
2. Watch the conveyor belt and hold **E** on a brainrot to buy it — it walks itself onto your base and starts earning $/sec.
3. Hold **E** on a rival's brainrot for 4 seconds to steal it (30s cooldown).
4. When the wave warning sounds, run back inside your base.
5. Own an Epic and $50,000 to **Rebirth**: your base resets, but all future income doubles.

## Layout

- `default.project.json` — Rojo project: the 3D island (beach, sea, conveyor, palms, plaza, spawn) plus the script services.
- `src/shared/` — `BrainrotData.luau` (cast, rarities, mutations, economy) and `CharacterFactory.luau` (builds each character's 3D body from parts).
- `src/server/init.server.luau` — plots, conveyor, earnings loop, stealing, the wave, rebirth, leaderstats.
- `src/client/Game.client.luau` — ScreenGui HUD (cash, income, rebirths, wave timer, banners, rebirth button).
- `main.ts` (Node 22, standard library only) — hands the game in: copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and writes `/output/dossier.json` with the vendored make.fun library.
- `game.rbxl` — the place, built with `rojo build default.project.json --output game.rbxl`.
- `PLAY.json` — play link (TODO: the place is not published yet; publishing needs Roblox Studio on Windows/macOS).

## Build it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## Referral

Play make.fun with my referral code: https://make.fun/r/qrg7fvky

## License

MIT — see [LICENSE](LICENSE).
