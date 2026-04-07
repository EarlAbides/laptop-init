# Claude Code Buddy Reroller

Want a cooler Claude Code companion? Your buddy is deterministically generated from your account UUID — but you can tweak the last segment to reroll.

## How it works

- Your companion (species, rarity, eyes, hat, shiny) is derived from `hash(accountUuid + salt)` using a seeded PRNG
- The `accountUuid` lives in `~/.claude.json` under `oauthAccount`
- By changing only the last segment of your UUID, you get a completely different roll
- **Results are unique to your UUID prefix** — you must run the script yourself

## Rarity odds

| Rarity | Chance |
| --- | --- |
| Common | 60% |
| Uncommon | 25% |
| Rare | 10% |
| Epic | 4% |
| Legendary | 1% |
| Shiny | 1% (independent) |
| Shiny Legendary | 0.01% (1 in 10,000) |
| Specific shiny legendary combo | ~1 in 8,640,000 |

## Example output

```
=== YOUR CURRENT ROLL ===
common     capybara   [°] none

=== SEARCHING 50M UUIDS (this takes ~60s) ===

legendary  dragon     [✦] crown      ✨SHINY  00000000085d
legendary  chonk      [✦] halo               00000000072f
legendary  robot      [@] propeller           0000000003ae
epic       ghost      [◉] wizard     ✨SHINY  000000001a4f
epic       axolotl    [·] crown               0000000008b2
rare       penguin    [✦] tophat     ✨SHINY  0000000241de
...
```

## Steps

1. Install [Bun](https://bun.sh) — **required** (the Claude Code binary uses `Bun.hash`, not the Node FNV fallback)
2. Save the script below as `find-legendary.ts`
3. Run: `bun find-legendary.ts`
4. Pick a suffix from the output
5. In `~/.claude.json`, replace your `accountUuid`'s last segment with the chosen suffix
6. Delete the `"companion"` block from `~/.claude.json`
7. Restart Claude Code — your new buddy will hatch

**To revert:** Restore your original `accountUuid` and delete the `"companion"` block again.

> **Note:** Changing `accountUuid` may affect auth. Save your real UUID somewhere before editing.

## Script

```ts
import { readFileSync } from 'fs'
import { homedir } from 'os'
import { join } from 'path'

const RARITIES = ['common', 'uncommon', 'rare', 'epic', 'legendary'] as const
const RARITY_WEIGHTS = { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 }
const SPECIES = ['duck','goose','blob','cat','dragon','octopus','owl','penguin','turtle','snail','ghost','axolotl','capybara','cactus','robot','rabbit','mushroom','chonk']
const EYES = ['·', '✦', '×', '◉', '@', '°']
const HATS = ['none','crown','tophat','propeller','halo','wizard','beanie','tinyduck']

function mulberry32(seed: number): () => number {
  let a = seed >>> 0
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function hashString(s: string): number {
  if (typeof Bun !== 'undefined') {
    return Number(BigInt(Bun.hash(s)) & 0xffffffffn)
  }
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i); h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

function pick<T>(rng: () => number, arr: readonly T[]): T {
  return arr[Math.floor(rng() * arr.length)]!
}

function rollRarity(rng: () => number) {
  const total = Object.values(RARITY_WEIGHTS).reduce((a, b) => a + b, 0)
  let roll = rng() * total
  for (const rarity of RARITIES) {
    roll -= RARITY_WEIGHTS[rarity]
    if (roll < 0) return rarity
  }
  return 'common' as const
}

function rollFull(userId: string, salt: string) {
  const rng = mulberry32(hashString(userId + salt))
  const rarity = rollRarity(rng)
  const species = pick(rng, SPECIES)
  const eye = pick(rng, EYES)
  const hat = rarity === 'common' ? 'none' : pick(rng, HATS)
  const shiny = rng() < 0.01
  return { rarity, species, eye, hat, shiny }
}

// Read UUID from ~/.claude.json
const configPath = join(homedir(), '.claude.json')
let uuid: string
try {
  const config = JSON.parse(readFileSync(configPath, 'utf8'))
  uuid = config.oauthAccount?.accountUuid ?? config.userID
  if (!uuid) {
    console.error('No accountUuid or userID found in ~/.claude.json')
    process.exit(1)
  }
} catch (e) {
  console.error('Could not read ~/.claude.json:', (e as Error).message)
  process.exit(1)
}

const prefix = uuid.slice(0, uuid.lastIndexOf('-') + 1)
const SALT = 'friend-2026-401'

console.log(`UUID prefix: ${prefix}***\n`)
console.log('=== YOUR CURRENT ROLL ===')
const current = rollFull(uuid, SALT)
console.log(`${current.rarity.padEnd(10)} ${current.species.padEnd(10)} [${current.eye}] ${current.hat}${current.shiny ? ' ✨SHINY' : ''}\n`)

console.log('=== SEARCHING 50M UUIDS (this takes ~60s) ===\n')

const target = new Set(['rare', 'epic', 'legendary'])
const seen = new Map<string, string>()

for (let i = 0; i < 50_000_000; i++) {
  const suffix = i.toString(16).padStart(12, '0')
  const result = rollFull(prefix + suffix, SALT)
  if (!target.has(result.rarity)) continue
  const key = `${result.rarity}|${result.species}|${result.eye}|${result.hat}|${result.shiny}`
  if (!seen.has(key)) seen.set(key, suffix)
}

const order = { legendary: 0, epic: 1, rare: 2 }
const entries = [...seen.entries()].sort((a, b) => {
  const [ra] = a[0].split('|')
  const [rb] = b[0].split('|')
  return (order[ra as keyof typeof order] ?? 9) - (order[rb as keyof typeof order] ?? 9) || a[0].localeCompare(b[0])
})

for (const [key, suffix] of entries) {
  const [rarity, species, eye, hat, shiny] = key.split('|')
  console.log(`${rarity.padEnd(10)} ${species.padEnd(10)} [${eye}] ${hat.padEnd(10)} ${shiny === 'true' ? '✨SHINY' : ''}\t${suffix}`)
}

console.log(`\nTotal unique combinations: ${entries.length}`)
console.log(`\nTo apply: replace the last segment of your accountUuid in ~/.claude.json with a suffix above.`)
```
