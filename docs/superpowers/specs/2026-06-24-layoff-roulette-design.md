# Layoff Roulette — Design Spec (Lean)

*Date: 2026-06-24 · Status: design locked, pre-implementation*

## One-liner
A daily mobile game where you run a startup that's out of money and must **fire exactly one person each payday to survive** — but titles lie, and the "useless" intern might be the only one keeping the company alive. Survive as many paydays as you can.

## Why it can spread (the thesis)
- **Wordle engine:** one seeded company per day, identical for everyone → results are *comparable* → a spoiler-safe share card that posts itself.
- **Hard to leave:** engineered near-miss ("I *should've* seen it") + no clean stopping point + run-to-run variance.
- **The clip is the marketing:** a built-in ~15s regret-reveal beat designed for the face-cam.
- **The mechanic is the message:** economic-precarity catharsis through role-inversion (you become the boss with the axe), not a theme skinned on.

## Locked decisions
| Decision | Choice |
|---|---|
| Platform | Mobile app (+ instant-play web for sharing) |
| Stack | TypeScript, web-first PWA, wrapped to iOS/Android via **Capacitor**. Deterministic core engine stays pure TS, reused on web + app. |
| Modes | **Daily** (viral hero) + **Endless** (retention/story machine) |
| Difficulty | **Honest, masterable math early; board ratchets the squeeze the longer you survive.** Collapse eventually guaranteed; day-count is the score. |
| Shape | Single-player + share |
| Win state | Survival score is the goal; a **rare acquisition/liquidity event = real win** (hope-sliver, anti-hopelessness) |
| Streak | Daily streak with **one grace token** (anti rage-quit) |
| Monetization | F2P. Daily is 100% free/fair forever. Opt-in rewarded video only; IAP = ad-removal, cosmetics, "Pro" Endless pack. **No pay-to-win on the daily.** |
| Name | "Layoff Roulette" (working title) |

## Core loop (one payday)
1. **Payday hits:** `Payroll due $X · Bank $Y · Short $Z. Cut payroll or go under.`
2. **Roster:** grid of employee cards. Each shows **honest signals** (name, title, salary, tenure) + **soft tells** (status line, one-line bio with a buried clue, relationship tags). Salary is the lever; the gap between title and true value is the game.
3. **The cut:** drag one card into the shredder (math sometimes forces two). Confirm.
4. **Cascade reveal** (the heart): ~1.5s dramatic pause → card flips → consequence stinger exposes the hidden role (`"Maya — 'Junior Designer.' Actually held the deploy keys. Prod down. −30 days runway."` or relief: `"Chad — 'VP of Synergy.' Did nothing. Morale +15."`).
5. **Time advances:** events fire (funding round, lawsuit, client renewal, sleeper ramping). Runway recalculates. Repeat.

**Endings:** bankruptcy (runway → 0) · **the board fires *you*** (survived too long) · rare **acquisition win**.

## Hidden-role system (the depth engine)
**Iron rule: every consequence is fair in hindsight — the clue was always there.** The reveal names the tell you could have read, so a loss reads as self-efficacy ("next time I'll see it"), not a cheat. This is the #1 retention risk; fairness is the top design priority.

Each employee has a hidden **true role**, only *partially* correlated with visible signals (deliberate noise; titles mislead):
- **Load-Bearing** — firing collapses something (secret sysadmin, owner of the big account).
- **Dead Weight** — safe cut, small morale boost (usually expensive/loud — the bait).
- **Morale Anchor** — cheap, but firing tanks morale → chain-quits.
- **Liability** — firing them *helps* (toxic exec, lawsuit risk).
- **Sleeper** — useless now, critical in ~3 paydays (fire early = fine, late = catastrophe).
- **Connected** — firing triggers a relationship chain (friend/spouse walks too).

**Skill = reading signals over titles**, weighing salary-relief vs hidden-value risk, tracking who's becoming load-bearing as events unfold. Seeded generator → never "solved."

## Economy
- **Runway (days) = cash ÷ burn** is the master resource; survive = runway > 0 each payday.
- Cutting salary lowers burn (good) but can cut revenue/morale (bad).
- **Early:** clean masterable math — smart play visibly buys weeks.
- **Late squeeze:** survive longer → board raises payroll/targets, events turn nastier (down-round, crash). Higher day-count, but collapse guaranteed.

## Daily mode + share artifact
- One seeded company/day worldwide, midnight reset, **one quality-gated run** (must resolve, no skip-spam).
- **Pink Slip Receipt** — copy-paste text+emoji, **spoiler-safe** (shows *how well* you cut, never *who* was load-bearing, so it doesn't ruin today's puzzle), no link/install needed in the share:
```
LAYOFF ROULETTE — Day 247 💼
Survived 18 paydays
🟩🟩🟨🟩🟥🟩🟩🟨🟩🟩🟥🟩🟩🟩🟨🟩🟥💀
Severance paid: $2.1M · Rank: Ruthless (top 12%)
```
Each square = a payday cut quality (🟩 clean · 🟨 risky · 🟥 disaster · 💀 fatal).

## Endless mode + meta-progression
- Unlocked after first daily. Roguelike, unique-to-you company, escalating difficulty.
- Roster is yours → Endless cards can be **fully spoiler-able and unhinged** (the anecdote engine).
- Roguelike depth via severance-bought **perks**: HR Consultant (reveal one role), Golden Parachute (survive one fatal mistake), Exit Interview (see true role before confirming).
- **Manager Rank ladder:** Intern Manager → Middle Manager → Ruthless Exec → Corporate Legend.
- **Unlocks:** company archetypes (crypto startup, dying legacy giant, VC-poisoned unicorn), event decks, cosmetic shredders/office skins.

## Tone & visual direction
Corporate-SaaS satire — looks like HR dashboard × Slack × LinkedIn: clean, flat, "friendly," quietly menacing. Termination emails in real corporate-speak. The shredder is the one violent, satisfying piece of juice. Gags: fired employees flip to "#OpenToWork"; passive-aggressive Slackbot; board emails get colder as you survive. **Self-implicating** (the board can fire *you*; no "save everyone" win) so it never punches down. Onboarding teaches "titles lie" in 10s via a tutorial company with one safe-looking load-bearing intern.

## Architecture
- **Deterministic, headless core engine** (pure TS, seeded, runs offline): `RosterGenerator` · `RoleEngine` · `CascadeEngine` · `Economy`. Same seed → identical company everywhere.
- **Daily seed derived from the date** (works offline; server distributes/confirms).
- **Thin backend:** leaderboard + rank percentiles + streak sync. **Anti-cheat for free:** client submits the move log; server re-simulates against the seed to validate the score (so "top 12%" is real).
- **Share renderer** (spoiler-safe text/emoji + optional image card).
- **Meta store:** local-first, cloud-synced.

## MVP scope (Daily only — the growth loop)
1. Deterministic core engine (6 role types, cascade, economy, late squeeze) — heavily unit-tested; **fairness lives here.**
2. Single-screen play: roster grid → drag-to-shredder → payday flow.
3. **The reveal beat** (dramatic pause + consequence stinger) — non-negotiable.
4. Daily seed + spoiler-safe share card.
5. Basic rank/leaderboard with server-side score validation.
6. Tone/juice pass + fairness playtest + late-squeeze balancing.

**Build order:** engine (headless + tested) → play screen → reveal beat → daily/share → backend/rank → polish & balance.
**Deferred to Phase 2:** Endless, perks, multiple archetypes, cosmetics, ads.

## Top risks
1. **Fairness ("fair in hindsight").** If consequences feel random, the retry loop dies. Mitigation: every reveal surfaces the readable tell; tune signal/noise in playtests.
2. **Clone-ability.** Mechanic is simple to copy; moat = daily-seed ritual + brand + tone + content depth (archetypes/event decks).
3. **Tone.** Must stay self-implicating satire, never mock real grief. Keep it system-level; the player is also precarious.
4. **Late-squeeze tuning.** Must reward skill (higher day-count) without feeling like the rug-pull happens too early.

## Open questions (for next session / build)
- Exact runway/burn/revenue/morale formulas + late-squeeze curve.
- Roster size per payday and how many forced double-cuts.
- Rank percentile bootstrapping before there's a player base.
- Backend choice (serverless KV + a re-sim validator is enough for MVP).
