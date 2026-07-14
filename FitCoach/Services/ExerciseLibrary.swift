import Foundation

/// Built-in movement library. Tier 1 = default pick, tier 2 = rotation variant,
/// tier 3 = accessory / constrained-equipment fallback.
enum ExerciseLibrary {

    static let all: [Exercise] = [
        // MARK: Chest
        Exercise(id: "barbell-bench-press", name: "Barbell Bench Press", primary: .chest, secondary: [.triceps, .shoulders], equipment: [.fullGym, .barbellRack], isCompound: true, tier: 1, stressedAreas: [.shoulder], cueNotes: "Shoulder blades pinned, feet planted, bar to lower chest."),
        Exercise(id: "incline-db-press", name: "Incline Dumbbell Press", primary: .chest, secondary: [.shoulders, .triceps], equipment: [.fullGym, .dumbbellsOnly], isCompound: true, tier: 1, stressedAreas: [.shoulder], cueNotes: "30° incline, elbows ~45° from torso."),
        Exercise(id: "machine-chest-press", name: "Machine Chest Press", primary: .chest, secondary: [.triceps], equipment: [.fullGym, .machinesOnly], isCompound: true, tier: 2, stressedAreas: [], cueNotes: "Full stretch at the bottom without shoulder pain."),
        Exercise(id: "cable-fly", name: "Cable Fly", primary: .chest, equipment: [.fullGym], isCompound: false, tier: 2, stressedAreas: [], cueNotes: "Slight elbow bend, squeeze through the mid-line."),
        Exercise(id: "pec-deck", name: "Pec Deck Fly", primary: .chest, equipment: [.fullGym, .machinesOnly], isCompound: false, tier: 2, stressedAreas: [], cueNotes: "Deep stretch, controlled 2s negative."),
        Exercise(id: "pushup", name: "Push-Up", primary: .chest, secondary: [.triceps, .shoulders], equipment: [.bandsBodyweight, .dumbbellsOnly, .fullGym], isCompound: true, tier: 3, stressedAreas: [.wrist], cueNotes: "Body rigid, full range."),

        // MARK: Back
        Exercise(id: "pullup", name: "Pull-Up / Assisted Pull-Up", primary: .back, secondary: [.biceps], equipment: [.fullGym, .barbellRack, .bandsBodyweight], isCompound: true, tier: 1, stressedAreas: [.elbow, .shoulder], cueNotes: "Chest to bar, control the negative."),
        Exercise(id: "lat-pulldown", name: "Lat Pulldown", primary: .back, secondary: [.biceps], equipment: [.fullGym, .machinesOnly], isCompound: true, tier: 1, stressedAreas: [], cueNotes: "Drive elbows down and in."),
        Exercise(id: "barbell-row", name: "Barbell Row", primary: .back, secondary: [.biceps], equipment: [.fullGym, .barbellRack], isCompound: true, tier: 1, stressedAreas: [.lowerBack], cueNotes: "Hinge ~45°, pull to lower ribs, no torso heave."),
        Exercise(id: "chest-supported-row", name: "Chest-Supported Row", primary: .back, secondary: [.biceps], equipment: [.fullGym, .machinesOnly, .dumbbellsOnly], isCompound: true, tier: 1, stressedAreas: [], cueNotes: "Chest stays glued to the pad — no lower-back load."),
        Exercise(id: "seated-cable-row", name: "Seated Cable Row", primary: .back, secondary: [.biceps], equipment: [.fullGym, .machinesOnly], isCompound: true, tier: 2, stressedAreas: [], cueNotes: "Squeeze shoulder blades, slow release."),
        Exercise(id: "single-arm-db-row", name: "Single-Arm Dumbbell Row", primary: .back, secondary: [.biceps], equipment: [.fullGym, .dumbbellsOnly], isCompound: true, tier: 2, stressedAreas: [], cueNotes: "Row to hip, avoid torso rotation."),

        // MARK: Shoulders
        Exercise(id: "overhead-press", name: "Overhead Press", primary: .shoulders, secondary: [.triceps], equipment: [.fullGym, .barbellRack], isCompound: true, tier: 1, stressedAreas: [.shoulder, .lowerBack], cueNotes: "Glutes tight, ribs down, press slightly back over mid-foot."),
        Exercise(id: "seated-db-shoulder-press", name: "Seated Dumbbell Shoulder Press", primary: .shoulders, secondary: [.triceps], equipment: [.fullGym, .dumbbellsOnly], isCompound: true, tier: 1, stressedAreas: [.shoulder], cueNotes: "Elbows slightly in front of shoulders."),
        Exercise(id: "lateral-raise", name: "Dumbbell Lateral Raise", primary: .shoulders, equipment: [.fullGym, .dumbbellsOnly], isCompound: false, tier: 1, stressedAreas: [], cueNotes: "Lead with elbows, no swing — side delts respond to volume."),
        Exercise(id: "cable-lateral-raise", name: "Cable Lateral Raise", primary: .shoulders, equipment: [.fullGym], isCompound: false, tier: 2, stressedAreas: [], cueNotes: "Constant tension, stay strict."),
        Exercise(id: "reverse-fly", name: "Reverse Pec Deck / Rear Delt Fly", primary: .shoulders, secondary: [.back], equipment: [.fullGym, .machinesOnly, .dumbbellsOnly], isCompound: false, tier: 2, stressedAreas: [], cueNotes: "Rear delts: high reps, strict form."),

        // MARK: Quads
        Exercise(id: "barbell-back-squat", name: "Barbell Back Squat", primary: .quads, secondary: [.glutes, .hamstrings], equipment: [.fullGym, .barbellRack], isCompound: true, tier: 1, stressedAreas: [.knee, .lowerBack, .hip], cueNotes: "Brace hard, sit between the hips, depth you can control."),
        Exercise(id: "hack-squat", name: "Hack Squat / Pendulum", primary: .quads, secondary: [.glutes], equipment: [.fullGym, .machinesOnly], isCompound: true, tier: 1, stressedAreas: [.knee], cueNotes: "Deep, controlled reps — great low-back-friendly squat."),
        Exercise(id: "leg-press", name: "Leg Press", primary: .quads, secondary: [.glutes], equipment: [.fullGym, .machinesOnly], isCompound: true, tier: 2, stressedAreas: [.knee], cueNotes: "Feet mid-platform, don't let hips tuck."),
        Exercise(id: "bulgarian-split-squat", name: "Bulgarian Split Squat", primary: .quads, secondary: [.glutes], equipment: [.fullGym, .dumbbellsOnly, .bandsBodyweight], isCompound: true, tier: 2, stressedAreas: [.knee], cueNotes: "Torso slightly forward for glutes, upright for quads."),
        Exercise(id: "leg-extension", name: "Leg Extension", primary: .quads, equipment: [.fullGym, .machinesOnly], isCompound: false, tier: 2, stressedAreas: [.knee], cueNotes: "Full squeeze at the top, slow negative."),

        // MARK: Hamstrings / Glutes
        Exercise(id: "romanian-deadlift", name: "Romanian Deadlift", primary: .hamstrings, secondary: [.glutes, .back], equipment: [.fullGym, .barbellRack, .dumbbellsOnly], isCompound: true, tier: 1, stressedAreas: [.lowerBack, .hip], cueNotes: "Hips back, soft knees, stretch not depth."),
        Exercise(id: "seated-leg-curl", name: "Seated Leg Curl", primary: .hamstrings, equipment: [.fullGym, .machinesOnly], isCompound: false, tier: 1, stressedAreas: [], cueNotes: "Seated beats lying for hamstring growth (long-length loading)."),
        Exercise(id: "lying-leg-curl", name: "Lying Leg Curl", primary: .hamstrings, equipment: [.fullGym, .machinesOnly], isCompound: false, tier: 2, stressedAreas: [], cueNotes: "Hips down, no lumbar arch."),
        Exercise(id: "hip-thrust", name: "Barbell Hip Thrust", primary: .glutes, secondary: [.hamstrings], equipment: [.fullGym, .barbellRack], isCompound: true, tier: 1, stressedAreas: [.hip], cueNotes: "Posterior pelvic tilt at lockout, chin tucked."),
        Exercise(id: "glute-bridge", name: "Dumbbell Glute Bridge", primary: .glutes, equipment: [.dumbbellsOnly, .bandsBodyweight], isCompound: true, tier: 3, stressedAreas: [], cueNotes: "Pause 1s at the top."),
        Exercise(id: "back-extension", name: "45° Back Extension", primary: .glutes, secondary: [.hamstrings, .back], equipment: [.fullGym, .machinesOnly], isCompound: true, tier: 3, stressedAreas: [.lowerBack], cueNotes: "Round-back glute bias or neutral for erectors."),

        // MARK: Arms
        Exercise(id: "db-curl", name: "Dumbbell Curl", primary: .biceps, equipment: [.fullGym, .dumbbellsOnly], isCompound: false, tier: 1, stressedAreas: [.elbow], cueNotes: "Supinate through the curl, no swing."),
        Exercise(id: "incline-db-curl", name: "Incline Dumbbell Curl", primary: .biceps, equipment: [.fullGym, .dumbbellsOnly], isCompound: false, tier: 2, stressedAreas: [.elbow], cueNotes: "Long-length bias — arms hang behind torso."),
        Exercise(id: "cable-curl", name: "Cable EZ Curl", primary: .biceps, equipment: [.fullGym], isCompound: false, tier: 2, stressedAreas: [.elbow, .wrist], cueNotes: "Constant tension."),
        Exercise(id: "triceps-pushdown", name: "Cable Triceps Pushdown", primary: .triceps, equipment: [.fullGym], isCompound: false, tier: 1, stressedAreas: [.elbow], cueNotes: "Elbows pinned, full lockout."),
        Exercise(id: "overhead-triceps-extension", name: "Overhead Cable Triceps Extension", primary: .triceps, equipment: [.fullGym, .dumbbellsOnly], isCompound: false, tier: 1, stressedAreas: [.elbow, .shoulder], cueNotes: "Long-head bias at long muscle length."),
        Exercise(id: "skull-crusher", name: "EZ-Bar Skull Crusher", primary: .triceps, equipment: [.fullGym, .barbellRack], isCompound: false, tier: 2, stressedAreas: [.elbow], cueNotes: "Bar behind head for stretch, elbows steady."),
        Exercise(id: "close-grip-bench", name: "Close-Grip Bench Press", primary: .triceps, secondary: [.chest], equipment: [.fullGym, .barbellRack], isCompound: true, tier: 2, stressedAreas: [.shoulder, .wrist], cueNotes: "Grip just inside shoulder width."),

        // MARK: Calves & Abs
        Exercise(id: "standing-calf-raise", name: "Standing Calf Raise", primary: .calves, equipment: [.fullGym, .machinesOnly, .dumbbellsOnly, .bandsBodyweight], isCompound: false, tier: 1, stressedAreas: [.ankle], cueNotes: "Pause at the stretch, full range."),
        Exercise(id: "seated-calf-raise", name: "Seated Calf Raise", primary: .calves, equipment: [.fullGym, .machinesOnly], isCompound: false, tier: 2, stressedAreas: [.ankle], cueNotes: "Soleus bias — slow tempo."),
        Exercise(id: "cable-crunch", name: "Cable Crunch", primary: .abs, equipment: [.fullGym], isCompound: false, tier: 1, stressedAreas: [], cueNotes: "Flex the spine, don't pull with arms."),
        Exercise(id: "hanging-leg-raise", name: "Hanging Leg Raise", primary: .abs, equipment: [.fullGym, .barbellRack, .bandsBodyweight], isCompound: false, tier: 1, stressedAreas: [.shoulder], cueNotes: "Posterior tilt, no swing."),
        Exercise(id: "weighted-plank", name: "Weighted Plank", primary: .abs, equipment: [.bandsBodyweight, .dumbbellsOnly, .fullGym, .machinesOnly], isCompound: false, tier: 3, stressedAreas: [], cueNotes: "30–45s, ribs down.")
    ]

    static func byID(_ id: String) -> Exercise? {
        all.first { $0.id == id }
    }

    /// Exercises usable given equipment and injury exclusions, best tier first.
    static func candidates(for muscle: MuscleGroup,
                           equipment: EquipmentSetting,
                           avoiding injuries: [InjuryArea]) -> [Exercise] {
        all.filter { ex in
            ex.primary == muscle
                && ex.equipment.contains(equipment)
                && ex.stressedAreas.allSatisfy { !injuries.contains($0) }
        }
        .sorted { ($0.tier, $0.isCompound ? 0 : 1) < ($1.tier, $1.isCompound ? 0 : 1) }
    }
}
