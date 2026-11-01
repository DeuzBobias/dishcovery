# Flutter verification — 30 October 2026

## Delivered changes

This pass preserves the existing Flutter design and original DM Sans/Lobster fonts, imagery, colors and navigation. It restores the daily tracker’s original progress card, date field, dashed empty state, meal grouping, recipe/manual entry dialog and bottom navigation. Recipe entries retain their nutrition snapshot and fractional servings. Food entries can be edited, removed and restored. The log dialog includes the date eaten.

The recovered stylesheet specifies 220 ms page entry with a five-pixel translation and opacity from 0.4 to 1. Flutter now applies this to tab changes, signup/login, preference steps and recipe-editor stages; primary-button press timing remains 150 ms. The Home fitness summary now uses the original large number with smaller units.

The added Fitness feature reuses existing cards, fields and buttons. Find it at **Home → Track your day → Set up calorie plan**. Users with Recipes or Community as their purpose do not see it.

## Personalized calorie plan

Setup uses age, height in cm, weight in kg, an explicitly selected equation coefficient, activity level and a 10%, 15% or 20% reduction (default 10%). It shows a preview before saving. The resting-energy calculation is `10 × kg + 6.25 × cm − 5 × age + coefficient`, where the published male/female coefficients are +5/−161. This is an equation input, not inferred account identity. Maintenance uses approximate activity factors 1.2, 1.375, 1.55 or 1.725; these rough multipliers are product estimation assumptions, not a measurement or an output established by the original paper.

- Estimated maintenance = rounded resting estimate × activity factor.
- Food target = rounded maintenance × (1 − selected reduction).
- Planned deficit = maintenance − food target.
- Logged intake = sum of each active entry’s per-serving calories × servings for the selected local date.
- Completed-day balance = estimated maintenance − logged intake. Negative values display as an estimated surplus.

A blank/incomplete day does not earn a deficit result. The user must explicitly mark a nonempty food log complete. Adding, editing, moving, removing or restoring food reopens the affected date. The display does not measure calories burned or confirm weight loss; it does not reward larger deficits or add exercise calories.

Plans are dated snapshots, stored locally and included in backups. Editing or pausing takes effect today, preserving earlier dates. Same-day plan changes replace that day’s plan. Existing manual calorie and macro targets are retained; an active plan supplies the calorie target while macro targets remain user-set. Pausing returns to the existing manual targets.

Automatic planning is restricted to adults aged 18–100 who confirm they are not pregnant or breastfeeding. Inputs must be finite and within the supported ranges; underweight BMI values below 18.5 are not offered an automatic deficit. Targets below 1,500 kcal are rejected. These are conservative product restrictions, not personalized clinical thresholds or a guarantee that a suggested target is suitable. Users can still log food without this optional plan.

Calculation reference: [Mifflin et al., 1990](https://doi.org/10.1093/ajcn/51.2.241). Scope reference: [NIDDK Body Weight Planner](https://www.niddk.nih.gov/bwp), which is intended for adults and excludes pregnancy/breastfeeding. This app is a simpler estimation tool, not an implementation of NIDDK’s model.

## Evidence and checks

`flutter analyze`: no issues. All 24 automated Flutter tests pass, including signup/onboarding, editor drafts, recipe nutrition and timers, pantry navigation, local credentials, fractional logging, formula guardrails, plan history/pause, storage round-trip, Fitness-only visibility, removal reopening the log, and the exact page-entry duration/translation. Image comparison tests cover the restored welcome, signup, home and tracker screens. Screenshots were reviewed; a passing golden establishes regression stability, not proof of universal pixel equivalence.

- [Original tracker comparison capture](../tmp/audit-oct30/pwa-tracker-full.png)
- [Flutter restored tracker](../app/test/goldens/tracker-restored-oct30.png)
- [Flutter Fitness plan](../app/test/goldens/fitness-deficit-oct30.png)
- [Flutter home](../app/test/goldens/restored-home.png)
- [Final test output](../tmp/oct30-final-tests.txt)
- [Build output](../tmp/oct30-build.txt)

The comparison capture uses the browser’s desktop presentation shell, whereas Flutter screenshots show a 390×844 phone viewport. Android date pickers, keyboards, file pickers and permission prompts deliberately use Android system UI. This pass is not an exhaustive pixel or accessibility certification across all Android phones and text sizes.

## Phone acceptance check

Install `Dishcovery-Android.apk` (version 1.0.1, build 2) on an arm64 Android phone, using the same app signature for an update. It is development-signed for presentation, not a Play Store release. Existing local data should be retained when updating; exporting a backup before updating is supported.

1. Open an existing account; check the original navigation, recipe imagery, signup/preferences and recipe-editor transitions.
2. With Fitness selected, open the tracker and create a plan. Confirm the preview, calorie target and unchanged macro targets.
3. Log a recipe with fractional servings and a manual meal. Mark the day complete; edit/remove/restore a meal and verify the day reopens.
4. Change the plan on a later day; inspect an earlier date. Pause the current plan and verify manual targets return.
5. Relaunch the app and export/import a backup. Check the saved plan and food log.
6. Test Android photo/file selection, sharing, notification permission and a cooking reminder in the background.

No Android phone or emulator was connected for this build. Installation, Android plugin behavior, keyboard/gesture interactions and frame pacing still need device verification. Accounts, community activity and the assistant remain local presentation features; no cloud service or wearable calorie measurement was added.
