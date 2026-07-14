# The science behind FitCoach's plan engine

FitCoach's programming is not a template — it is generated from parameters with
direct support in the hypertrophy/strength literature and refined from
bodybuilding coaching practice. This document maps each engine decision to its
evidence base.

## Training frequency: ~2× per muscle per week

Every split the engine can select (full body, upper/lower, U/L+PPL, PPL×2)
trains each muscle roughly twice weekly. Schoenfeld, Ogborn & Krieger (2016,
*Sports Medicine*) meta-analysis: training a muscle 2× per week produces
greater hypertrophy than 1× at matched volume. Beyond 2× the effect flattens
when volume is equated — so frequency is a volume-distribution tool, not a goal
in itself.

## Volume: MEV → MAV progression, MRV cap

The engine uses per-muscle weekly-set landmarks popularised by Dr. Mike
Israetel (Renaissance Periodization):

- **MEV** (minimum effective volume): where each mesocycle starts.
- **MAV** (maximum adaptive volume): where accumulation weeks ramp to.
- **MRV** (maximum recoverable volume): a hard cap, even for priority muscles.

Dose–response support: Schoenfeld et al. (2017) — more weekly sets produce more
growth up to a point of diminishing (and eventually negative) returns.
Landmarks are scaled by training age (beginners: ×0.7 — they grow on less;
advanced: ×1.15) and by a recovery modifier derived from wearable data.

Per-session sets per muscle are capped at ~8: sets beyond that in one session
show poor marginal stimulus ("junk volume"); volume is better spread across
the week.

## Effort: reps in reserve (RIR)

Accumulation weeks progress RIR 3 → 1. Proximity to failure is what recruits
high-threshold motor units; grinding to absolute failure every set adds
disproportionate fatigue for little extra stimulus (Helms et al., RIR-based RPE
literature). Deload week trains at RIR 4.

## Progression: double progression

Add reps within the prescribed range first; when all sets hit the top of the
range, add ~2.5% load and restart at the bottom. The app computes this
automatically from your logged sets and pre-fills the suggestion.

## Periodization: 5-week mesocycles with deload

4 accumulation weeks (volume and effort ramp) + 1 deload (~60% volume, −10%
load, RIR 4). Deloads dissipate accumulated neuromuscular fatigue and
resensitise muscle to volume. Fixed-length deloads are standard practice in
evidence-based bodybuilding programming; the coach can also trigger one on
demand ("I need a deload").

## Autoregulation from wearable data

The recovery modifier (0.8–1.0×) shrinks volume targets when:
- 7-day average sleep < 6 h (sleep restriction measurably impairs hypertrophy
  and increases catabolism), or
- Ultrahuman-style recovery score averages < 50, or
- 7-day HRV falls > 25% below the longer-term baseline.

## Rep ranges

Hypertrophy is achievable across 6–30+ reps when sets approach failure
(Schoenfeld 2021 load meta-analysis); ranges are chosen for practicality:
compounds 6–10 (or 3–6 for strength goal — specificity), isolation 10–15 where
low loads are joint-friendlier and less fatiguing.

## Exercise selection

Tiered library: stable, loadable, long-range movements first (tier 1), variants
for repeat days second. Variants rotate between A/B days for fuller regional
coverage. Injury filters remove movements that load a flagged joint
(e.g. shoulder → no barbell bench/OHP/dips; replaced with machine press and
neutral-grip work).

## Nutrition

- **BMR**: Katch-McArdle when body-fat % is available (lean mass is what drives
  metabolism — better for trained users), else Mifflin-St Jeor.
- **Deficit/surplus**: −20% for fat loss (targets 0.5–0.75% BW/week — the rate
  shown to preserve lean mass), +10% for lean gaining, ~maintenance for recomp.
- **Protein**: 1.6–2.2 g/kg (Morton et al. 2018 meta-analysis); top of range
  when dieting; scaled to lean mass at high body-fat.
- **Fat floor**: ≥0.8 g/kg and ≥20% of calories (hormonal support).
- **Carbs**: remainder, biased around training.
- **Adjustment loop**: weekly check-ins compare the *measured* trend-weight
  rate against the goal rate and nudge calories ±100–200 kcal — the same
  feedback loop a good prep coach runs.

## Supplements (only what has evidence)

Creatine monohydrate 3–5 g/day (strongest evidence in sports nutrition),
caffeine 2–3 mg/kg pre-training, protein powder as convenience, vitamin D and
omega-3 as insurance. Deliberately excluded: BCAAs (redundant with adequate
protein), fat burners, test boosters.

## Data scepticism

Consumer data is noisy: BIA body-fat swings with hydration, MFP logging is
typically under-reported (validated in doubly-labelled-water studies), scale
weight swings 1–2% daily on water alone. FitCoach therefore:
- smooths weight with an EMA and uses only the trend,
- flags impossible jumps, out-of-range values and macro/calorie inconsistencies,
- cross-checks logged intake against the energy balance implied by actual
  weight change, and anchors calorie targets to the measured side when they
  disagree.
