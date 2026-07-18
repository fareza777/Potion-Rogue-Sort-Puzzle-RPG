# Five-realm sprite production report

Built-in image generation was used once per ID. Each source used a flat chroma key, then the installed soft-matte/despill helper. Final PNGs were alpha-padded non-destructively to preserve at least 12% transparent margin on each edge.

| ID | Final prompt subject | Source / final | Alpha bounds validation |
|---|---|---|---|
| frost_mite | compact crystalline six-legged ice arthropod | tmp/five-realm-sprites/frost_mite-source.png -> assets/art/enemies/frost/frost_mite.png | 967x914 bbox; pads 153/145; RGBA and corners transparent |
| rime_squire | skeletal frost duelist with rapier and ward shield | tmp/five-realm-sprites/rime_squire-source.png -> assets/art/enemies/frost/rime_squire.png | 1027x1183; pads 163/187; RGBA and corners transparent |
| icefang_wolf | lean white wolf with ice fangs and frozen mane | tmp/five-realm-sprites/icefang_wolf-source.png -> assets/art/enemies/frost/icefang_wolf.png | 1148x1152; pads 182/182; RGBA and corners transparent |
| hoarfrost_witch | hooded frost mage, icicle wand, orbiting shards | tmp/five-realm-sprites/hoarfrost_witch-source.png -> assets/art/enemies/frost/hoarfrost_witch.png | 837x1238; pads 133/196; RGBA and corners transparent |
| crystal_yeti | shaggy white ice-crystal juggernaut | tmp/five-realm-sprites/crystal_yeti-source.png -> assets/art/enemies/frost/crystal_yeti.png | 934x1003; pads 148/159; RGBA and corners transparent |
| reliquary_seraph | winged ice-metal guardian with soul reliquary | tmp/five-realm-sprites/reliquary_seraph-source.png -> assets/art/enemies/frost/reliquary_seraph.png | 860x1342; pads 136/212; RGBA and corners transparent |
| winter_lich | crowned skeletal frost sovereign with ice staff | tmp/five-realm-sprites/winter_lich-source.png -> assets/art/enemies/frost/winter_lich.png | 827x1389; pads 131/220; RGBA and corners transparent |
| ink_slime | glossy navy one-eyed blob with ink tendrils | tmp/five-realm-sprites/ink_slime-source.png -> assets/art/enemies/abyss/ink_slime.png | 1052x947; pads 167/150; RGBA and corners transparent |
| drowned_acolyte | hooded seaweed-robed cultist with censer | tmp/five-realm-sprites/drowned_acolyte-source.png -> assets/art/enemies/abyss/drowned_acolyte.png | 825x1286; pads 132/204; RGBA and corners transparent |
| brine_stalker | finned teal amphibious hunter | tmp/five-realm-sprites/brine_stalker-source.png -> assets/art/enemies/abyss/brine_stalker.png | 1049x891; pads 166/141; RGBA and corners transparent |
| abyssal_crab | verdigris-armored guardian with shield claw | tmp/five-realm-sprites/abyssal_crab-source.png -> assets/art/enemies/abyss/abyssal_crab.png | 1079x774; pads 171/123; RGBA and corners transparent |
| lantern_horror | hooded apparition with antique lantern head | tmp/five-realm-sprites/lantern_horror-source.png -> assets/art/enemies/abyss/lantern_horror.png | 746x1342; pads 118/212; RGBA and corners transparent |
| plague_alchemist | masked deep-sea alchemist with plague vial | tmp/five-realm-sprites/plague_alchemist-source.png -> assets/art/enemies/abyss/plague_alchemist.png | 897x1249; pads 142/198; RGBA and corners transparent |
| deep_oracle | pearl-masked jellyfish-mantled floating seer | tmp/five-realm-sprites/deep_oracle-source.png -> assets/art/enemies/abyss/deep_oracle.png | 873x1156; pads 138/183; RGBA and corners transparent |
| leviathan_apothecary | armored deep-sea apothecary with tentacles and pressure flask staff | tmp/five-realm-sprites/leviathan_apothecary-source.png -> assets/art/enemies/abyss/leviathan_apothecary.png | 932x1111; pads 148/176; RGBA and corners transparent |

Shared prompt additions for every row: premium painterly dark-fantasy mobile-RPG render; upper-left rim light; one complete frontal three-quarter silhouette; no crop/floor/shadow/UI/text; uniform #00ff00 key for frost or #ff00ff for abyss.

## Integration and verification

- Redirected all 15 enemy records from fallback five_realm paths to new frost/abyss paths. No visual-registry fallback remained.
- Imported once with Godot 4.7.1 headless editor.
- Focused suite res://tests/five_realm_content_test.tscn: 217 checks, 0 failures.
