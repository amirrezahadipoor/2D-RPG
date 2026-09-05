# Balance doctrine

The game is tuned *harder than a casual default* on purpose: survival, elite
rolls and dungeon depth all gate behind talents, levels and side quests.
These are the relationships the automated checks (`tests/verify.gd`,
`_check_balance`) pin down, so any future number tweak stays honest.

## Combat bands (per hero level 1/3/5/7/9)

| relationship | band | why |
|---|---|---|
| hits to kill a same-level normal monster | 2-8 | fights stay readable; 8 is a tanky orc, never a sponge |
| hits a same-level monster needs to kill the hero | >= 3 | mistakes are punishible, not instant death |
| hits to kill the dragon | ~15-18 raw (fewer with combo/heavy) | a boss is a set piece, not a mob |
| combo finisher / heavy cleave vs opener | 1.35x / 2.2x | skill expression must out-damage button mashing |
| parry / perfect dodge | negates damage | timing beats facetanking |

Growth curves (src/data/enemies.gd):
- hp x (1 + 0.18/level) - slower than hero damage growth, so TTK compresses as you gear
- damage x (1 + 0.15/level)
- xp x (1 + 0.25/level), gold x (1 + 0.22/level) - deeper floors stay worth diving

## Progression

- xp to next level = 100 * level^1.3
- target per level: ~1 quest (+27*L+54 xp estimate) plus 2-16 same-tier kills
- talent point per level; vigour +10 max hp, might +2 damage per rank

## Economy

- gold sinks, in order: potions (25 + 8/level), greater potions (60 + 16/level),
  seeded shop equipment (40*(rarity+1) + 15/level)
- a health potion costs 1.2-10 kills of the level-appropriate monster -
  cheap enough to buy, never free
- potion heal = 45% max hp (greater 80%) and must out-heal two hits of a fair
  same-level enemy
- chests: 8-25 G (+30 in hidden chambers); secret chambers also pay in relics
- quest gold: side 8*(tier+1)*(1-2), main 15*(chapter+1)

## Drops

- 35% loot chance per kill; potions bias in early, equipment rarity scales
  with monster level (0.03*level, capped 0.15) plus hero luck re-rolls upward
- relics (Amulet of Depths, Idol of Embers, Dragonfang Talisman) never drop:
  hidden chambers and the dragon's hoard only

## Difficulty gates

- elite roll 12% per spawn, deeper biomes roll stronger tables
- dungeon depth d spawns at hero level + d - 1, cap 6 monsters, boss at depth 6
- main story gates on level (1 + chapter*4 + stage/2): side quests are the
  intended bridge
