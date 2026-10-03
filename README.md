# PartyBotUI

PartyBotUI v1.10.0 is a World of Warcraft Vanilla 1.12.1 addon for servers running the vMaNGOS PartyBot companion system. It replaces routine `.partybot` chat commands with a Blizzard-style manager for summoning bots, inspecting characters and bags, and issuing tactical orders.

## Features

### Roster

![Roster tab showing active PartyBot slots, the account character grid, and quick-add controls](screenshots/roster.png)

- Manage up to four active PartyBots, jump directly to a bot's character sheet, or dismiss a bot.
- Discover account characters with `.partybot alts` and show up to nine characters in a 3x3 grid.
- Summon an account character with one click. Hover a character for level, race, class, and party status.
- Add generic role or class bots quickly: Tank, Healer, DPS, Warrior, Priest, Mage, Rogue, Druid, or Hunter.

### Character Sheet

![Character Sheet tab showing a selected bot, its model, stats, and equipment slots](screenshots/character-sheet.png)

- Switch among active bots and inspect each bot's level, class icon, health, primary profession levels, hearthstone bind location, 3D model, and 19 equipment slots.
- Right-click equipped items to move them to the bot's bags, or drag items from the player inventory onto an equipment slot.
- Open a trade directly with the selected bot or jump to that bot's bags.

### Bot Bags

![Bot Bags tab showing the continuous inventory grid, equipped bags, wallet, and transfer controls](screenshots/bot-bags.png)

- Inspect the selected bot's backpack and four equipped bags in one continuous grid of up to 88 slots.
- Left-click an item to retrieve it with `.partybot giveback`; the addon waits for server confirmation before clearing and refreshing the slot.
- Right-click an item to equip it on the selected bot.
- Upgrade one of the bot's four bag slots by dragging an empty, larger player bag onto it, or by selecting an eligible bag in the bot inventory and then choosing the destination slot.
- View the bot wallet, deposit 1g or 5g, or retrieve all bot gold.

### Tactical Dock

- The former Tactics tab now lives in a movable, two-row dock at the top of the screen.
- First row: Pull, Attack, Stop, Regroup, Pause, Resume, AOE, Object, and PB (open manager).
- Second row: Tank, Healer, DPS, Melee, Ranged, CC Mark, Focus, and Clear. Roles apply to the targeted PartyBot.
- CC Mark and Focus open a compact eight-choice picker. The buttons use readable mark abbreviations (Sta through Sku) and full-name hover tips, so the controls remain usable even when a Vanilla client lacks raid-mark artwork.
- The dock starts hidden on every login or UI reload. Open the Roster with the PB minimap button, then use Show Dock / Hide Dock at the top right. `/pb dock` also toggles it; the dock still shows the bot count and can be dragged.

### Notes

- Keep one shared notepad for party plans, reminders, and loot goals across all characters on the account.
- Changes update the addon's saved variables as you type and persist when you log out or reload the UI.
- Click the Notes tab or inside the notepad to focus it and type. Scroll through longer notes; up to 20,000 characters are supported.

### Chat Filtering

PartyBotUI consumes its structured `[PB_*]` data messages and suppresses successful command output for five seconds after an addon-issued PartyBot command. Errors remain visible, including failed commands, invalid requests, full bags, and cannot-equip messages.

## Installation

1. Download the latest [`PartyBotUI.zip`](https://github.com/n2gb/partybotui/releases/latest/download/PartyBotUI.zip).
2. Extract it into the World of Warcraft addon directory so the final path is:

   ```text
   World of Warcraft\Interface\AddOns\PartyBotUI\
   ```

3. Launch World of Warcraft, or run `/console reloadui` if it is already open.
4. Enable PartyBotUI in the character-selection AddOns menu.

## Slash Commands

| Command | Action |
| --- | --- |
| `/pb` or `/partybot` | Toggle the PartyBot Manager |
| `/pb dock` | Show or hide the floating tactical dock |
| `/pb pull` | Order the Tank bot to pull the current target |
| `/pb atk` or `/pb attack` | Order all bots to attack the current target |
| `/pb stop` | Order all bots to stop attacking |
| `/pb follow` or `/pb regrp` | Call bots to the player's coordinates |
| `/pb aoe` | Toggle bot AOE spells |
| `/pb bags` | Query the targeted bot's bags |

## Compatibility

- Client: World of Warcraft Vanilla 1.12.1 (build 5875)
- Server: vMaNGOS with the PartyBot system and PartyBotUI server messages/commands

## Release

The addon version is 1.10.0. See [CHANGELOG.md](CHANGELOG.md) for its release history.
