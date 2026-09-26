# PartyBotUI

**PartyBotUI** is a comprehensive World of Warcraft (Vanilla 1.12.1) client interface addon built for servers running the **vMaNGOS** PartyBot companion engine.

It replaces raw chat slash commands with an authentic Blizzard-style management window, paperdoll character sheet, full bag inspection grid, floating combat HUD, and gear upgrade advisor.

---

## Features

### 1. Roster & Account Alts Manager
* **Dynamic Alt Discovery:** Automatically queries the server (`.partybot alts`) to discover all characters created on your account.
* **1-Click Alt Summoning:** Click any alt's name to summon them as an active partybot into your group (`.partybot load`).
* **Hover Details:** Hover over any alt to view their level, race, class, and whether they are currently in your party.
* **Manual Refresh:** Re-query the server anytime with the "Refresh" button.
* **Quick-Add Class Roles:** One-click summoning for generic roles (`Tank`, `Healer`, `DPS`, `Warrior`, `Priest`, `Mage`, `Rogue`, `Druid`, `Hunter`).
* **Party Slot Management:** Inspect active bots and dismiss them cleanly with one click (`.partybot remove`).

### 2. Paperdoll Character Sheet (Multi-Bot)
* **Equipment Inspection:** Live display of all 19 equipment slots for each active partybot with classic Vanilla slot frames and quality highlights.
* **3D Standing Character Model:** Features a standing character model matching your bot's race, gender, and gear. Click and drag or use the arrow buttons to spin the model.
* **Right-Click Unequip:** Right-click any equipped item on your bot to order them to unequip it into their bags (`.partybot unequip`).
* **Direct Trade Access:** One-click button to open a direct trade window with the bot.

### 3. Bot Bags & Inventory Grid
* **Live Bag Visualization:** Inspect your bot's 16-slot backpack and all 4 equipped container bags (up to 88 total inventory slots), framed like Vanilla item slots.
* **Icon-Only Bag Strip:** View all bags in one grid, or click a backpack/bag icon beneath it to inspect just that container. Click the selected icon again to return to all bags; no bag-number or slot-count tabs clutter the view.
* **1-Click Item Retrieval:** Left-click any item in your bot's inventory to order them to hand it over directly into your bags (`.partybot giveback`). The slot clears after the server confirms the transfer, and the addon refreshes the bag snapshot automatically.

### 4. Tactics & Combat Commands
* **Role Switcher:** Change bot combat roles on the fly (`Tank`, `Healer`, `DPS`, `Melee DPS`, `Ranged DPS`).
* **Combat Flow:** Order your tank to `Pull`, command all bots to `Attack` or `Stop`, call bots to `Come To Me`, or freeze/unfreeze bot AI.
* **AOE Toggle:** Safely toggle Area-of-Effect spells on or off to prevent unwanted pack pulls in tight dungeons.
* **Raid Target Marks:** Set Crowd Control (CC) marks and Focus Fire target icons for your bots.

### 5. Floating Tactical Dock
* A compact, draggable HUD positioned at the top of your screen for combat commands without keeping the main manager window open.
* Includes quick buttons for `Pull`, `Atk`, `Stop`, `Regrp`, `AOE`, and toggling the main window (`PB`).

### 6. Tooltip Gear Upgrade Advisor
* Automatically evaluates items in your bags and equipment against all active partybots.
* Appends a clean upgrade notification at the bottom of standard item tooltips showing which bot would benefit most from the gear.

---

## Installation

1. Download the latest pre-packaged **[`PartyBotUI.zip`](https://github.com/n2gb/partybotui/releases/latest/download/PartyBotUI.zip)** from GitHub Releases.
2. Extract the archive directly into your World of Warcraft `Interface\AddOns\` directory:
   ```text
   World of Warcraft\Interface\AddOns\PartyBotUI\
   ```
   > [!IMPORTANT]
   > The archive extracts directly as `PartyBotUI/`. Ensure the folder is placed in `Interface\AddOns\` matching `PartyBotUI.toc`.
3. Launch WoW (or run `/console reloadui` if already in-game).
4. Verify **PartyBotUI** is enabled in your character select **AddOns** menu.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/pb` or `/partybot` | Toggle the main PartyBot Manager window |
| `/pb dock` | Show or hide the floating tactical combat dock |
| `/pb pull` | Order your Tank bot to pull your current target |
| `/pb atk` or `/pb attack` | Order all bots to attack your target |
| `/pb stop` | Order all bots to stop attacking |
| `/pb follow` or `/pb regrp` | Force bots to run to your coordinates |
| `/pb aoe` | Toggle AOE spells on/off |
| `/pb bags` | Query targeted bot's bags in chat |

---

## Compatibility
* **Client:** World of Warcraft (Vanilla 1.12.1 / Build 5875)
* **Server:** vMaNGOS (Vanilla mangos core)
