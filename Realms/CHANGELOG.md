# Changelog

## 1.1.4

- Fixed multiplayer stuttering caused by frequent network activity

## 1.1.3

- Fixed a Social menu crash with more than four players

## 1.1.2

- Restored preparation is_finalizing function for other mods

## 1.1.1

- Fixed error spam related to voice chat

## 1.1.0

- Added experimental voice chat

## 1.0.0-rc2

- Fixed a crash that could occur when loading into a Realms game

## 1.0.0-rc1

- Added separate hosting options for local Mourningstar and Psykhanium sessions
- Fixed unintended server startup for temporary local sessions

## 1.0.0

- Fixed a crash when SocialNotifications displays friend status updates
- Fixed duplicate server port notifications
- The join address field now normalizes common full-width punctuation when you leave the field or connect
- Fixed for the Depths of the Damned update

## 0.7.3

- Fixed some crashes related to player data and unit cleanup

## 0.7.2

- Enabled Mourningstar features in locally hosted Mourningstar and Psykhanium

## 0.7.1

- Loadout restrictions no longer apply in the Mourningstar or the Psykhanium
- Removed the automatic exit timer from mission results

## 0.7.0

- Increased the player limit and bot-fill target to 12, with up to 7 bots
- Added player ping to Mission Preparation
- Fixed a host crash when someone joined a session with more than 3 bots
- Fixed a crash when leaving a session with the Social menu open
- Fixed a startup error that could prevent the loadout hotkey from working
- Fixed repeated network errors after a player disconnected
- Fixed failures when rejoining a server in a short time

## 0.6.1

- Fixed enemy and resource generation reusing the same random seed across missions
- Fixed preparation-screen elements appearing over menus opened on top

## 0.6.0

- Added a configurable UDP listening port for hosted Realms servers
- Added a server option to allow players to change loadouts during missions
- Fixed a crash when changing the bot fill target during an active mission

## 0.5.2

- Fixed Realms connection errors not returning players to the Mourningstar correctly
- Fixed missions started from the Mourningstar leaving players on a black screen

## 0.5.1

- Realms players now appear as in Psykhanium in the Social menu

## 0.5.0

- Added an option to keep local games in their original single-player mode without starting a Realms server
- Fixed missions getting stuck when a player disconnected during Mission Preparation
- Fixed missing loading screens and mission briefings when Mission Preparation was disabled

## 0.4.0

- Starting another local mission now keeps connected players together and sends everyone through the correct preparation or loading state
- Added options for syncing invulnerability, invisibility, and sound muffling in the Psykhanium
- Hosts can now kick Realms players from the Social menu
- Havoc rank is now shown in Mission Preparation
- Failed connections now show a readable message instead of internal connection details
- Fixed Mission Preparation appearing after returning to a local hub from the results screen
- Fixed a team wipe sending the host and clients to different screens instead of the results screen
- Fixed a specific host crash when the host died with a Daemonhost or Ritual Host active
- Fixed a specific native host crash during Havoc missions
- Fixed joining another Realm or reconnecting to the current address becoming stuck
- Fixed the Psykhanium loadout chest opening without an active user or remaining open after everyone left it

## 0.3.0

- Fixed an error when opening the pause menu
- Fixed crashes and loading hangs when starting another mission
- Fixed local hubs incorrectly showing Mission Preparation
- Fixed private skill markers appearing for the wrong player
- Fixed crashes when player is in a strike-team and joining local hubs
- Fixed long preparation lists overflowing their panels

## 0.2.0

- Supported text chat in Realms server
- Added an option to hide the server address on the Join Server screen
- Server passwords are now hidden while typing
- Fixed a crash that could occur shortly after entering a mission when a player’s equipment had changed
- Fixed a crash that could occur when a queued notification referenced a player who had already left
- Fixed a crash when starting a local mission while no game mode was active
- Optimized performance

## 0.1.0

- Initial release
