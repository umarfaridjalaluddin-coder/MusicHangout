# MusicHangout

A Roblox music hangout and entertainment experience built with Roblox Studio, Rojo, Luau, Git, and GitHub.

## Development

- Roblox Studio — map and place development
- VS Code — source code editing
- Rojo — synchronization between source files and Roblox Studio
- Luau — scripting
- Git + GitHub — version control

## Project Structure

- `place/` — Roblox Studio place file
- `src/ReplicatedStorage/` — shared modules, remotes, and shared resources
- `src/ServerScriptService/` — server-side scripts
- `src/StarterGui/` — user interface
- `src/StarterPlayer/StarterPlayerScripts/` — client-side scripts

## Status

Phase 0 — Development Environment

## Rumah Hantu dark ride (Phase 5.6)

An automated four-seat ghost-train ride in the north-west corner, beside the Outdoor area.

- `src/ReplicatedStorage/Modules/HauntedRideConfig.lua` - all tuning: timings, speeds, the route, colours, sound placeholders
- `src/ServerScriptService/HauntedRideBuilder.server.lua` - builds the house, station, track, seven scenes and the cart (idempotent)
- `src/ServerScriptService/HauntedRideServer.server.lua` - server state machine: IDLE, BOARDING, DISPATCHING, RIDING, UNLOADING, RESETTING
- `src/StarterPlayer/StarterPlayerScripts/HauntedRideClient.client.lua` - darkens the screen and lowers the music only for players inside the house

Riders board with a prompt (1 to 4 players); the server moves the cart and fires every scene cue. Players never steer.

Audio: every entry in `HauntedRideConfig.SOUNDS` is `0` (silent placeholder) until an approved Roblox audio ID is filled in.

To test: press Play, walk west from the Outdoor area to the house, board a seat and ride. Set `DEBUG = true` in the config to show waypoints and log state changes.
