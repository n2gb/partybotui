# Changelog

## 1.10.1

- Remove the unusable Object button from the tactical dock and spread the remaining top-row buttons across it. Future bot interaction and looting work is tracked with quest acceptance and turn-in.

## 1.10.0

- Make the minimap PB button open the manager on the Roster tab. Add a Show Dock / Hide Dock button on Roster.
- Start the tactical dock hidden on every login or UI reload, ignoring the previous saved visibility setting. `/pb dock` remains available.

## 1.9.1

- Move the Hearthstone bind area into the top Character Sheet line, beside the bot name and level. Replace race/class text with the class icon before the name.
- Remove the Professions label from the health line and remove the two model rotation arrows; dragging the model still rotates it.

## 1.9.0

- Show the selected bot’s hearthstone bind area below the Character Sheet model. The existing `.partybot professions <name>` response now includes the server’s localized home-bind area name.

## 1.8.0

- Replace Character Sheet mana/energy and unit tracking text with each bot’s two primary professions and current/maximum skill levels. The server supplies those values through `.partybot professions <name>`.

## 1.7.0

- Make the Notes edit box focus when the tab opens or the notepad is clicked, and anchor it explicitly inside its scroll frame.
- Add a PB minimap button: left-click toggles the dock, right-click opens the manager. Dock visibility persists through UI reloads and is shared with /pb dock.

## 1.6.0

- Move every Tactics and Roles control into a two-row, movable dock and remove the redundant Tactics tab.
- Add compact CC and Focus mark pickers with visible text labels and full-name tooltips, plus a Clear button.
- Keep Roster, Character Sheet, Bot Bags, and Notes as the four manager tabs.

## 1.5.1

- Fix the Notes tab crash on Vanilla 1.12 by using Blizzard's scrolling edit helper instead of the unavailable FontString:GetStringHeight method.

## 1.5.0

- Add an account-wide Notes tab with a scrolling, multiline notepad. Changes are saved automatically through the addon's existing saved variables.
- Fit five navigation buttons inside the existing manager window.

## 1.4.6

- Load each crowd-control and focus-mark button icon from Vanilla's complete `UI-RaidTargetingIcon_1` through `UI-RaidTargetingIcon_8` textures.
- Use full texture coordinates so the raid-target artwork renders correctly on every mark button without relying on later-client texture helpers or atlas layouts.

## 1.4.5

- Render crowd-control and focus marks through the native raid-target texture helper, with explicit coordinates for Vanilla's four-by-two icon atlas as a fallback.
- Keep the icon texture above the button artwork so every raid mark remains visible.
- Balance vertical spacing across the Tactics & Roles sections to use the full manager height consistently with the roster tab.

## 1.4.4

- Replace the abbreviated text on crowd-control and focus-mark buttons with the matching in-game raid-target icon textures.
- Map Star through Skull to `UI-RaidTargetingIcon_1` through `UI-RaidTargetingIcon_8`.

## 1.4.3

- Limit the **Your Account Characters** roster to nine entries in a three-by-three grid.
- Balance the vertical spacing between the active bots, account characters, and quick-add sections.
- Use the existing 530-by-550 roster window more evenly, reducing unused space at the bottom without enlarging it.
