# Potion Rogue Art Overhaul Design

## Objective

Transform the existing Godot prototype into a polished portrait dark-fantasy mobile game whose in-game battle screen can credibly produce Play Store marketing screenshots. Preserve all current game rules and data while replacing placeholder procedural presentation with a cohesive, animated production-art layer.

The approved benchmark is the high-fidelity Cave Slime battle concept generated on 2026-07-16: torch-lit stone dungeon, expressive glossy enemy, carved dark panels with aged-gold trim, jewel-like potion liquids, readable combat hierarchy, and impactful but controlled VFX.

## Scope

This overhaul covers:

- Main menu and persistent visual identity.
- Dungeon map and encounter nodes.
- Battle arena, enemies, potion vessels, HUD, controls, overlays, tutorial, and combat feedback.
- Upgrade, relic, shop, settings, credits, victory, defeat, and run-complete screens.
- Reusable illustrated icons for currencies, stats, potion effects, relics, upgrades, and actions.
- Animation, particles, transitions, and responsive audio/visual feedback.
- A representative set of Play Store screenshots derived from the real implemented game.
- Android performance and fallback behavior.

The overhaul does not change battle balance, progression rules, save data schema, monetization, or core puzzle logic.

## Visual Direction

### Theme

The game uses a polished storybook dark-fantasy aesthetic with a slightly gothic alchemy identity. It should feel adventurous and tactile rather than grim or horrific.

- Backgrounds: charcoal stone, deep indigo shadows, warm torchlight, restrained violet magic.
- Frames: carved stone or dark stained wood with aged bronze and muted gold edges.
- Liquids: saturated jewel colors reserved for gameplay-critical potion states.
- Characters: expressive, readable silhouettes; cute enough for broad appeal, dangerous enough to support combat.
- Texture: subtle grain, scratches, soot, glass reflections, liquid bubbles, and cloth wear.
- Typography: Cinzel or a compatible display serif for major fantasy headings; a highly readable complementary font for body text and numbers.

The design avoids flat rounded rectangles, generic vector icons, uniform purple gradients, tiny labels, excessive ornament, and photorealistic rendering.

### Lighting

All screens follow one lighting model:

- Warm primary light from torches or candles at the sides.
- Cool blue-violet rim light from magic and potion effects.
- UI panels remain darker than the playfield and receive restrained gold edge highlights.
- VFX may briefly exceed normal brightness during attacks, potion completion, rewards, and boss events.

## Production Strategy

Use a hybrid 2D pipeline.

### Layered Art

Large enemies are authored as layered high-resolution PNG assets or compact atlases. Layers isolate the body, face, eyes, mouth, foreground appendages, glow, shadow, and effect anchors. Godot composes these layers under an `EnemyView` presentation node.

Layered animation handles:

- Idle breathing and body settling.
- Eye movement and blinking.
- Subtle hovering, bubbling, flame, or cloth motion.
- Anticipation and recovery.
- Reusable hit reaction and enrage treatment.

### Short Sprite Sequences

Short sprite sequences are reserved for motion that would look mechanical when produced only with transforms:

- Slime splash or deformation accents.
- Skeleton bone breakup.
- Golem rock fragments and magma bursts.
- Mage spell release.
- Beast claw or bite smear.
- Boss defeat and phase-transition accents.

Sequences should be brief, tightly cropped, and packed into atlases. They augment layered animation rather than replacing it.

### Procedural Presentation

Godot tweens, shaders, and particles supply reusable feedback:

- Squash and stretch.
- Hit-stop and restrained camera shake.
- White hit flash, poison tint, shield shimmer, and enrage pulse.
- Pour trails, liquid slosh, bubbles, sparks, healing wisps, poison fumes, and shield fragments.
- Floating combat text and combo banners.
- Panel transitions and reward reveals.

## Architecture

The existing logic/presentation separation remains intact.

### Asset Registry

Add a data-driven visual registry that maps existing IDs to presentation resources:

- Enemy ID to portrait layers, animation configuration, shadow, and effect anchors.
- Potion color to vessel fill texture, glow, pour particle, completion VFX, and effect icon.
- Upgrade and relic IDs to icon textures and rarity frames.
- Dungeon area to background layers, map skin, torch palette, and ambient particles.

Missing mappings fall back to safe built-in resources and log a warning in development builds.

### EnemyView

Replace direct procedural drawing in `EnemyDisplay` with an `EnemyView` scene while preserving the existing public presentation calls such as configuration, enrage state, and hit playback. `EnemyView` owns art layers, animation state, effect anchors, and local particles. Battle logic remains unaware of sprites.

### PotionView

Retain `PotionTube` as the puzzle-state owner. Move its rendering into a themed `PotionView` that combines:

- Reusable bottle or vial frame sprite.
- Masked dynamic liquid segments driven by existing contents.
- Highlight, glass reflection, rim, selected state, locked state, and completion flash.
- Pour animation between source and target without delaying logical state changes.

The initial release uses one premium bottle family for battle consistency. Alternate silhouettes can be added later only if they do not make capacity harder to read.

### UiTheme and Nine-Slice Assets

Expand `UiKit` into a bridge between code-built layouts and reusable themed resources. Panels and buttons use nine-slice textures so they scale without distortion. Shared typography, margins, focus states, disabled states, and rarity treatments remain centralized.

### Screen Composition

Existing screens keep their scene entry points and navigation. Presentation may move from monolithic code construction into reusable `.tscn` components as each screen is reskinned. Logic signals and autoload interfaces remain stable.

## Battle Screen Design

The battle screen is the visual benchmark and is completed first.

### Layout

From top to bottom:

1. Compact stage and currency strip within the safe area.
2. Enemy name and readable HP bar.
3. Large arena with the enemy occupying the focal center.
4. Combat status and telegraph area integrated near the arena boundary.
5. A clear `YOUR TURN` divider or context-sensitive banner.
6. Two-row potion puzzle using large touch targets and readable liquid units.
7. Three primary utility controls with illustrated icons and remaining counts.

Player HP, shield, poison, enemy armor, countdown, and boss state remain readable without competing with the enemy art.

### Animation States

Every enemy supports the following normalized state interface:

- `intro`
- `idle`
- `anticipate`
- `attack`
- `recover`
- `hit`
- `status_tick`
- `enrage` when supported
- `defeat`

Animation playback is event-driven from existing battle signals. Visual sequences never determine damage or battle state.

### Combat Timing

Baseline presentation timing:

- Potion completion anticipation: 100–160 ms.
- Projectile or effect travel: 180–320 ms depending on effect.
- Hit-stop: 45–75 ms on normal attacks and up to 110 ms on major combos.
- Camera shake: 120–220 ms with low amplitude.
- Enemy hit recovery: 250–450 ms.
- Reward reveal: 450–700 ms per staged element.

Input locking is minimal and only prevents contradictory taps during a pour or decisive battle transition. Cosmetic animation can continue after the logical event when safe.

### Potion Feedback

- Fire: warm directional burst, embers, brief orange rim light, strong hit spark.
- Healing: green-gold wisps drawn toward the player HP bar, soft value pulse.
- Shield: blue glasslike ring, refracted shimmer, fragment response when absorbing damage.
- Poison: violet-green fumes, droplets, persistent low-intensity enemy status layer.
- Combos: unique compact banner plus blended VFX from the contributing potion types.

## Enemy Asset Set

The MVP enemy roster receives individual silhouettes and motion language:

- Cave Slime: glossy elastic mass, bubbles, squash, angry face.
- Skeleton: brittle bone motion, loose jaw, red eye sparks, breakup defeat.
- Poison Beast: hunched feline or batlike silhouette, toxic saliva, fast anticipation.
- Stone Golem: heavy segmented rock, dust, blue rune light, slow weighty impact.
- Dark Mage: layered hood and cloth, floating hands or focus, violet spell glyphs.
- Blood Slime: denser red translucent body, sharper expression, aggressive splashes.
- Fire Golem boss: large magma-cracked silhouette, armor feedback, flame layers, enrage phase, major defeat sequence.

Visual scale varies by threat level. Elite and boss encounters receive stronger arena lighting, banners, and intro timing rather than merely changing frame color.

## Other Screens

### Main Menu

Use a layered dungeon doorway or alchemy chamber background, animated torchlight, a strong Potion Rogue title treatment, a hero potion or enemy silhouette, and a single dominant Play control. Secondary navigation is visually quieter.

### Dungeon Map

Replace the text list with an illustrated branching path over a vertically composed dungeon environment. Nodes use distinct battle, elite, treasure, shop, and boss icons. Completed, current, available, and locked states are readable by shape as well as color.

### Rewards and Upgrades

Victory and relic rewards use a chest or magical altar scene with three clearly separated choice cards. Cards combine an illustrated icon, short title, concise description, rarity frame, and focused reveal animation.

### Permanent Upgrades

Group related upgrades visually rather than presenting eight identical rows. Each upgrade uses a unique icon, level pips, clear cost, enabled/disabled treatment, and purchase feedback.

### Settings and Credits

Use the same material system but reduce decorative density. Readability and touch accessibility take priority.

## Asset Organization

Suggested project layout:

```text
assets/
  art/
    backgrounds/
    enemies/<enemy_id>/
    potions/
    ui/frames/
    ui/icons/
    upgrades/
    relics/
    map/
    vfx/
  animation/
  themes/
```

Source-generation artifacts and rejected drafts stay outside runtime import folders. Only approved, optimized assets enter `assets/art`.

Runtime PNG textures use appropriate Godot import compression. UI textures avoid lossy compression where it causes edge halos. Large backgrounds may use WebP or compressed textures after visual comparison on device.

## Performance Budget

Target a stable 60 FPS on mainstream Android devices and a functional 30 FPS fallback on low-end devices.

- Base viewport remains 720×1280.
- Limit simultaneously active particle systems and reuse pooled effects.
- Keep layered backgrounds to a small number of parallax planes.
- Atlas small UI icons and short effect sequences.
- Avoid full-screen overdraw from stacked transparent layers.
- Cap shake, blur, distortion, and glow intensity.
- Provide a reduced-effects mode that lowers particles, disables nonessential distortion, reduces ambient animation, and shortens secondary transitions.

The first performance gate is the battle screen with the Fire Golem, active status effects, potion pour, and combat text occurring together.

## Accessibility and Readability

- Preserve large touch targets appropriate for portrait mobile play.
- Potion colors also receive distinct effect icons or patterns where practical.
- Critical text and numbers use strong contrast and outlines when placed over art.
- Motion does not hide state changes.
- Reduced-effects mode also reduces screen shake and flash intensity.
- Safe-area padding remains compatible with notches and Android navigation areas.

## Failure Handling

- Missing textures fall back to a clearly identifiable placeholder without crashing gameplay.
- Missing animation clips fall back to idle plus transform-based hit feedback.
- Unsupported shaders fall back to unshaded or simple canvas rendering.
- Failed audio or particle playback never blocks state transitions.
- Asset registry validation runs in tests or development startup and reports missing enemy, potion, upgrade, relic, and map mappings.

## Verification

### Automated

- Existing gameplay logic tests must remain green.
- Add registry coverage tests for every data ID.
- Add scene-loading smoke tests for main menu, map, battle, shop, settings, and credits.
- Verify animation events do not mutate battle results.
- Verify missing-resource fallbacks load without errors.

### Visual

- Capture standardized screenshots for main menu, normal battle, boss battle, map, reward choice, and shop.
- Compare at 720×1280 and at representative tall Android aspect ratios.
- Inspect text, touch-target size, nine-slice scaling, clipped particles, and safe areas.
- Verify normal and reduced-effects modes.
- Check that every screen belongs to the same lighting, material, and icon system.

### Performance

- Profile normal battle and worst-case boss battle on desktop compatibility renderer and at least one Android target.
- Measure frame time during simultaneous pour, enemy attack, status tick, particles, and floating text.
- Check texture memory and loading hitches when entering battle or reward screens.

## Play Store Deliverables

Marketing images are produced after the representative screens exist in the real build. The screenshots may add a restrained headline, device framing, or feature caption outside the gameplay viewport, but they must not invent unavailable game systems.

Initial set:

1. Battle Sort — Cave Slime impact moment.
2. Upgrade Choice — premium three-card reward reveal.
3. Dungeon Map — illustrated branching progression.
4. Boss Battle — Fire Golem phase or enrage moment.
5. Gear and Growth — use the implemented relic/permanent-upgrade experience rather than an unimplemented equipment system.

## Delivery Order

1. Establish the asset registry, theme resources, shared animation/VFX helpers, and missing-resource fallbacks.
2. Produce and implement the battle benchmark with Cave Slime, potion vessels, HUD, and core VFX.
3. Validate visual quality and Android performance before multiplying assets.
4. Produce the remaining enemy roster and boss presentation.
5. Reskin map, reward, relic, shop, menu, settings, tutorial, and result screens.
6. Run full visual, logic, and performance verification.
7. Capture and compose the Play Store screenshot set from the final build.

## Acceptance Criteria

- The implemented Cave Slime battle is recognizably consistent with the approved concept's quality, mood, hierarchy, and material richness.
- All seven enemy presentations are distinct, animated, and connected to real battle events.
- Potion sorting remains immediately readable during motion and effects.
- No current gameplay, save, or progression behavior is lost.
- Main menu, map, battle, rewards, shop, settings, and result screens share one coherent art system.
- The battle screen maintains target performance or automatically reduces secondary effects.
- Play Store screenshots are derived from implemented screens and need no misleading gameplay reconstruction.
