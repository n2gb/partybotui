# Changelog

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
