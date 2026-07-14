# FitCoach — bespoke, science-based training for iPhone

FitCoach generates a personal weight-training plan from your objectives,
biology and constraints (time, weekly sessions, equipment, injuries) — then
keeps it honest with data from **MyFitnessPal, Withings and Ultrahuman**, keeps
*you* honest with workout companionship and weekly photo check-ins, and lets
you pivot the whole plan conversationally ("more chest", "I only have 45
minutes now", "my shoulder hurts").

Built with SwiftUI for iOS 17+ (iPhone 17 ready). No backend — your data stays
on device; the only network call is the optional AI coach.

## Features

| Area | What it does |
|---|---|
| **Onboarding questionnaire** | Biology (sex, age, height, weight, body fat), goal, experience, days/week, minutes/session, equipment, injuries, activity level, priority muscles |
| **Plan engine** | 5-week mesocycles: MEV→MAV volume ramp per muscle (MRV-capped), RIR 3→1 effort progression, deload week, ~2×/week frequency, sessions auto-fitted to your time budget, injury-aware exercise selection. See [docs/SCIENCE.md](docs/SCIENCE.md) |
| **Connectivity** | Primary: **Apple Health** (MFP, Withings and Ultrahuman all sync into it — one link covers all three). Fallback: CSV/JSON file import with native-format parsers for each app |
| **Data scepticism** | Sanity checker flags implausible weights, BIA body-fat jumps, under-logged calories (cross-checked against your actual energy balance); trends use EMA smoothing, never raw readings |
| **Conversational pivots** | Rule-based coach works offline (volume shifts, day/time changes, injuries, goal switches, deloads). Add an Anthropic API key in Settings for free-form Claude-powered coaching that can also restructure the plan |
| **Workout companion** | Session clock, auto-starting rest timer per exercise, set-by-set kg/reps logging pre-filled with double-progression suggestions from your last session |
| **Accountability** | Weekly check-in (weigh-in, front/side/back photo request, subjective scores) with scheduled reminder + overdue nudge, automated progress analysis and calorie adjustments |
| **Autoregulation** | Poor sleep/HRV/recovery trends (Ultrahuman/Apple Watch) trim volume targets ~10–20% and surface a heads-up on training days |
| **Nutrition** | Calorie target + macro ratios (Katch-McArdle / Mifflin-St Jeor, goal-adjusted), meal-timing guidance and evidence-graded supplement advice — deliberately not a meal planner |

## Project layout

```
project.yml                 # XcodeGen project definition
FitCoach/
  App/                      # Entry point + AppState (single source of truth)
  Models/                   # Profile, biometrics, training, nutrition, check-ins
  Services/
    PlanEngine.swift        # Mesocycle generation, progression, autoregulation
    NutritionEngine.swift   # BMR/TDEE, macros, supplements, meal timing
    DataSanityChecker.swift # Flags implausible imported data
    ProgressAnalyzer.swift  # EMA trends, e1RM, check-in analysis, kcal adjustments
    HealthKitService.swift  # Apple Health sync (weight, BF, HRV, sleep, nutrition…)
    ImportService.swift     # MFP / Withings / Ultrahuman CSV+JSON parsers
    CoachService.swift      # Conversational pivots (offline rules + Claude API)
    ExerciseLibrary.swift   # Tiered, injury-tagged movement library
    NotificationService.swift, PersistenceStore.swift
  Views/                    # Onboarding, Dashboard, Plan, Workout, Check-in,
                            # Nutrition, Coach chat, Progress/Import, Settings
docs/SCIENCE.md             # Evidence base for every programming decision
```

## Building

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open FitCoach.xcodeproj
```

Select your signing team, then run on a device (HealthKit works fully on
hardware; the simulator has an empty Health store).

## Connecting your apps

1. **MyFitnessPal** → enable Apple Health sync in MFP settings (writes dietary
   energy & macros).
2. **Withings / Health Mate** → enable Apple Health sync (writes weight, body
   fat, lean mass).
3. **Ultrahuman** → enable Apple Health sync (writes sleep, HRV, RHR).
4. In FitCoach: onboarding → *Link Apple Health* (or Progress → Import Data →
   Re-sync any time).

No Apple Health? Export files instead: MFP *Nutrition Summary* CSV, Withings
*weight.csv*, Ultrahuman CSV/JSON — Progress → Import Data.

MyFitnessPal's partner API is closed and Withings/Ultrahuman OAuth apps require
registered credentials, so direct API clients are intentionally out of scope
for v0.1; the service layer is structured so they can be added per-source later.

## Roadmap ideas

- Withings & Ultrahuman OAuth clients (needs registered API credentials)
- Apple Watch companion for in-set logging and rest-timer haptics
- Save completed workouts to Apple Health
- Unit tests for PlanEngine volume math and ImportService parsers
