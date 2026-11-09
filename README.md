# RABuffs (ClassicAPI edition)

This build of RABuffs requires the [ClassicAPI](https://github.com/brues-code/ClassicAPI) DLL for the 1.12.1 client (Turtle WoW). Without the DLL it does nothing except print a line at login saying it needs ClassicAPI; your saved bars and profiles are left untouched.

## ClassicAPI edition

- **Buffs are read directly.** Bars count auras with `C_UnitAuras.UnitAura`, matched by spell ID or by name and icon, and update the moment a buff lands or drops. SuperWoW and the hidden-tooltip scans are no longer needed.
- **Real fading times.** The recast window and the "time left" in bar and unit-frame tooltips come from each aura's own expiry.
- **Casting never touches your target.** Buffs, resurrects and soulstones go straight to the chosen player (`C_Spell.CastAtUnit`, `C_Item.UseAtUnit`); range comes from `C_Spell.IsSpellInRange`. Greater Blessings, Gift of the Wild and other group buffs are found by name, so they cast reliably.
- **Fewer false warnings.** No "on cooldown" message during the global cooldown, a clear message when a spell can't be used, and feigning hunters are no longer counted as dead.
- **New debuff bars.** Magic Debuffs, Curses, Poisons, Diseases and Debuffs I Can Cure, under the *Debuffs* group in the bar editor.
- **AddOn Options pages.** Game Menu > AddOn Options > RABuffs has six pages: RABuffs (bar window), Appearance, Buffing, Profiles, Bars and Buff list. They replace the old settings window; `/rab` opens them.
- **Live tooltips.** Pressing or releasing Shift or Alt over a bar redraws its tooltip straight away.
- **Fixes.** Text reports from `/rabq` and Ctrl-click work in a party, bars whose query no longer exists are dropped instead of breaking the window, the "Self only" checkbox works for every bar, the health query reports correctly, and a number of leaked globals are gone. The 30-second raid buff broadcast and its hidden chat channel were removed; version checks still work by whisper.

### Install

Extract the release zip into `Interface\AddOns` (it contains the `Rabuffs` folder), replacing any older RABuffs. Settings and profiles from 0.12 carry over.

### Version history

- **0.13.1** - New Appearance options page: bar texture (any texture path), bar height and bar width, and separate tick boxes to hide the title bar, the window background and the window border. With the title bar hidden, drag any bar to move the window. Right-clicking a bar opens the window menu. "Preview bar window" shows the window and every bar while the options are open, whatever the group, combat and hide-active settings.
- **0.13.0** - First ClassicAPI edition (everything above).

## WARNING
This version is not backwards compatible with the original - it uses a new format in the WTF file as the original was very impractical to work with.

I would recommend backing up your WTF folder or SavedVariables\Rabuffs.lua in case you ever want to revert.

## Pepo Changes

- All buffs can be toggled self only rather than having two versions
- Options for hiding in combat and hiding buffs that are active
- Reorganized all the buff menus to make it easier to find things
- Made settings window draggable
- Ability to ignore player names on specific buffs
- Better identification of buffs with the same texture/tooltip
- Added profile system to save and load buff sets

## About RABuffs

An addon to track raid wide and your personal buffs and personal weapon enchants.

It provides a panel of clickable buttons that light up when a buff is found.

You can click on the panel to buff up, which saves space from your action bars.

A lot of the functionality is also available in macros via the /rab and /rabq commands.

There is also an addon based on Rabuffs that can log buffs to a file for tracking https://github.com/Loogosh/Rabuffs_Logger.

## Slash Commands

### Basic Commands (`/rab` or `/rabuffs`)

- `/rab` - Open the AddOn Options pages and list the commands
- `/rab show` - Display the RABuffs UI frame (if hidden)
- `/rab hide` - Hide the RABuffs UI frame
- `/rab info` - List the buffs and debuffs on your current target, with spell IDs and matching query keys
- `/rab versioncheck [target]` - Check RABuffs versions
  - `/rab versioncheck` - Check raid/party (default based on group type)
  - `/rab versioncheck raid` - Check current raid
  - `/rab versioncheck party` - Check current party
  - `/rab versioncheck guild` - Check guild members
  - `/rab versioncheck PlayerName` - Check specific player via whisper

### Profile Management (`/rab profile`)

- `/rab profile` - Show profile command help
- `/rab profile list` - List all available profiles
- `/rab profile current` - Show current active profile
- `/rab profile save <name>` - Save current bars to named profile
- `/rab profile load <name>` - Load named profile
- `/rab profile delete <name>` - Delete named profile

### Advanced Commands

- `/rab regtest` - Perform query regression test (debug)
- `/rab coreinfo` - Display core addon information

### Buff Query Commands (`/rabq` or `/rq`)

Query and report buff status with flexible targeting:

- `/rabq [target] <query> [groups] [classes]`

**Target Options:**
- (none) - Output to console/chat
- `raid` - Output to raid chat
- `party` - Output to party chat
- `officer` - Output to officer chat
- `w PlayerName` - Whisper to player
- `c ChannelName` - Output to channel

**Query Examples:**
- `/rabq motw` - Check Mark of the Wild (console)
- `/rabq raid fort` - Check Fortitude to raid chat
- `/rabq party not pws` - Check who's missing Power Word: Shield
- `/rabq officer ai 12 mp` - Check Arcane Intellect on groups 1-2, mages and priests only

**Group Limits:** Numbers 1-8 (e.g., `12345` for groups 1-5)

**Class Limits:** Letters for each class
- `m` = Mage
- `l` = Warlock  
- `p` = Priest
- `r` = Rogue
- `d` = Druid
- `h` = Hunter
- `s` = Shaman
- `w` = Warrior
- `a` = Paladin

Use `not` prefix to invert queries (show who's missing the buff).

![screenshot](ss.png?raw=true "screenshot")
![screenshot2](ss2.png?raw=true "screenshot2")
