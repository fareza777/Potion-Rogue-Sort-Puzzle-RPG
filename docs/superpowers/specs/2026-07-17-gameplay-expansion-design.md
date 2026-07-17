# Potion Rogue — Gameplay Expansion Design

**Tanggal:** 17 Juli 2026  
**Status:** Disetujui untuk perencanaan implementasi  
**Arah:** Roguelike build + variasi puzzle + battle spectacle

## 1. Tujuan

Revisi ini mengubah Potion Rogue dari rangkaian battle sort-puzzle yang linear menjadi roguelike singkat yang menghasilkan keputusan, puzzle, dan build berbeda pada setiap run. Identitas utama tetap: pemain menyortir cairan untuk membuat potion, lalu potion tersebut digunakan dalam battle.

Target pengalaman:

- Satu run berdurasi sekitar 12–18 menit.
- Battle reguler berdurasi 60–100 detik.
- Pemain menghadapi keputusan taktis setiap beberapa langkah puzzle.
- Build yang berhasil terasa berbeda, bukan hanya memiliki angka damage lebih besar.
- Boss menjadi klimaks dengan beberapa fase dan presentasi audiovisual khusus.
- Battle awal tetap ramah pemain baru; kompleksitas bertambah melalui mekanik, bukan lonjakan statistik.

## 2. Masalah pada Loop Saat Ini

Versi saat ini mempunyai tujuh battle dalam urutan tetap, enam tabung dengan objective yang sama, empat potion dengan fungsi tetap, dan mayoritas upgrade berupa penambahan statistik. Musuh memiliki beberapa kemampuan, tetapi pemain tetap melakukan tindakan puzzle yang hampir identik pada setiap encounter. Akibatnya variasi visual tidak menghasilkan variasi keputusan yang cukup.

## 3. Prinsip Desain

1. **Sort tetap menjadi sumber kekuatan.** Skill dan efek baru mendukung puzzle, bukan menggantikannya.
2. **Variasi harus mengubah keputusan.** Modifier kosmetik atau sekadar tambahan HP tidak dihitung sebagai variasi gameplay.
3. **Intent harus terbaca.** Pemain mengetahui ancaman utama sebelum melakukan langkah.
4. **Build harus mengubah aturan.** Upgrade terbaik memodifikasi potion, combo, skill, atau resource.
5. **Kekalahan harus terasa adil.** Hazard diperkenalkan satu per satu dan selalu memiliki counterplay.
6. **Konten bersifat data-driven.** Encounter, modifier, relic, event, dan boss phase dapat ditambah tanpa menulis ulang battle screen.

## 4. Core Run Loop

Alur satu run:

1. Pemain memilih satu dari tiga starting kits.
2. Sistem membuat peta bercabang dengan 10–12 node dan satu boss.
3. Pemain memilih jalur menuju node berikutnya.
4. Battle atau event memberikan reward, risiko, atau perubahan build.
5. Setelah elite, pemain memilih satu relic kuat.
6. Campfire memberi pilihan heal, upgrade, atau cleanse.
7. Shop menukar crystal run dengan relic, catalyst, atau jasa.
8. Boss menyelesaikan run dan memberi meta currency serta unlock.

Jenis node awal:

- **Battle:** encounter standar dengan satu modifier.
- **Elite:** musuh kuat dengan dua modifier dan reward relic.
- **Event:** pilihan naratif dengan trade-off eksplisit.
- **Treasure:** catalyst, crystal, atau relic dengan peluang kutukan.
- **Shop:** pembelian dan reroll terbatas.
- **Campfire:** heal, empower satu potion, atau menghapus curse.
- **Boss:** encounter multi-phase tanpa modifier acak yang merusak pola boss.

Peta memastikan minimal satu jalur aman dan tidak menempatkan dua elite berurutan. Node yang tidak valid diganti menggunakan fallback battle standar.

## 5. Encounter Contract

Setiap battle dibentuk oleh `EncounterContract` yang berisi enemy, objective, modifier, reward, dan seed. Battle screen tidak menentukan aturan sendiri; screen hanya menampilkan state dari contract dan battle systems.

Objective awal:

1. **Defeat:** kalahkan musuh seperti sistem sekarang.
2. **Survive:** bertahan hingga sejumlah serangan musuh selesai.
3. **Brew Order:** aktifkan urutan warna tertentu sebelum musuh kalah.
4. **Armor Break:** hancurkan beberapa lapisan armor dengan potion yang tepat.
5. **Cleanse:** bersihkan sejumlah cursed layers dari board.

Battle reguler memakai satu objective utama. Elite dapat menambahkan bonus objective opsional yang memberi reward tambahan. Boss menggunakan objective phase-specific.

## 6. Puzzle Modifier dan Hazard

Modifier awal:

- **Frozen Tube:** tabung tidak dapat digunakan sampai pemain menyelesaikan potion tertentu atau membayar mana.
- **Cursed Layer:** layer teratas menonaktifkan efek potion sampai dipindahkan ke cleansing flask atau dihancurkan skill.
- **Volatile Liquid:** layer memiliki counter; jika tidak dipindahkan tepat waktu, musuh mendapat bonus attack.
- **Hidden Layer:** warna tertutup sampai menjadi layer teratas.
- **Wild Essence:** dapat menyatu dengan warna apa pun, tetapi hasil akhirnya lebih lemah kecuali di-upgrade.
- **Chain Lock:** dua tabung saling terikat; menuang dari satu memengaruhi lock counter lainnya.
- **Corruption:** setiap enemy attack menambahkan satu layer pengganggu pada tabung yang valid.
- **Unstable Flask:** kapasitas tabung berubah antara tiga dan lima untuk encounter tersebut.

Aturan keselamatan:

- Encounter awal hanya memakai Frozen Tube atau Hidden Layer.
- Modifier tidak boleh membuat board tanpa legal move.
- Board generator melakukan solvability check sebelum battle dimulai.
- Bila generation gagal setelah batas percobaan, digunakan preset board yang telah tervalidasi.
- Dua modifier yang saling mengunci tidak boleh dipilih bersama.

## 7. Enemy Intent dan Tempo Battle

Musuh menampilkan satu intent utama dan, bila relevan, satu intent sekunder:

- Attack dan estimasi damage.
- Defend atau menambah armor.
- Lock tube.
- Add corruption.
- Poison player.
- Summon hazard.
- Enrage atau phase transition.

Intent dihitung sebelum pemain melakukan langkah pertama pada siklus tersebut. Jika stat berubah, preview diperbarui. Random critical tidak boleh membuat preview palsu; intent menampilkan rentang damage atau ikon critical chance.

Enemy attack counter tetap berbasis jumlah move. Namun, beberapa objective dapat menggunakan turn khusus agar pemain tidak dihukum saat animasi atau pemilihan reward berlangsung.

## 8. Mana, Skill Aktif, dan Ultimate

Penyelesaian satu potion memberi mana berdasarkan tingkat kesulitan pembuatannya. Mana maksimum awal adalah 100.

Starting kits:

- **Ember Adept:** fokus Fire dan combo agresif. Skill `Flash Boil` menggandakan efek Fire berikutnya.
- **Verdant Warden:** fokus Heal/Shield. Skill `Purify` membersihkan satu curse dan memberi shield.
- **Void Brewer:** fokus Poison dan kontrol board. Skill `Transmute` mengubah satu exposed layer menjadi Wild Essence.

Setiap kit memiliki:

- Satu passive.
- Satu active skill dengan biaya mana.
- Satu ultimate yang diisi melalui combo dan objective progress.

Skill puzzle awal:

- Pindahkan satu exposed layer tanpa menghabiskan enemy move.
- Bekukan enemy attack counter selama satu move.
- Pecahkan satu lock atau curse.
- Gandakan potion effect berikutnya.
- Ubah exposed layer menjadi warna target atau Wild Essence.

Skill tidak boleh menyelesaikan seluruh board otomatis. Semua skill memiliki biaya, cooldown, atau batas penggunaan yang terlihat jelas.

## 9. Combo System

Combo dua potion yang dipertahankan dan diperluas:

- Fire → Fire: Fire Burst.
- Heal → Shield: restorative barrier.
- Shield → Fire: reflected blaze.
- Poison → Fire: toxic detonation.
- Fire → Poison: burning venom, damage-over-time meningkat.
- Shield → Shield: fortify dan satu charge counterattack.
- Heal → Heal: regeneration beberapa enemy turns.
- Poison → Shield: venom ward yang meracuni attacker.

Combo tiga potion membangun ultimate pattern. Pattern ditampilkan sebagai tiga slot di HUD. Contoh:

- Fire → Poison → Fire: Inferno Catalyst.
- Shield → Heal → Shield: Sanctuary.
- Poison → Poison → Fire: Plague Nova.

Relic dapat mengubah pola, mempertahankan satu slot antar-battle, atau memberi wildcard. Combo resolver terpisah dari `BattleManager` agar mudah dites dan ditambah.

## 10. Build System

Build terdiri dari empat lapisan:

1. **Starting kit:** identitas awal run.
2. **Potion mutations:** mengubah efek salah satu warna.
3. **Relics:** passive kuat yang menciptakan sinergi.
4. **Catalysts:** modifier kecil yang dipasang pada skill atau potion.

Upgrade numerik tetap ada sebagai opsi sederhana, tetapi tidak mendominasi pool. Minimal 60% pilihan reward harus mengubah aturan atau menciptakan sinergi.

Target konten rilis sistem:

- 3 starting kits.
- 24 potion mutations, enam per warna.
- 18 relic.
- 12 catalyst.
- 10 upgrade statistik pendukung.

Contoh mutation:

- Fire menembus armor tetapi damage dasar berkurang.
- Heal memberi regeneration jika HP sudah penuh.
- Shield memantulkan sebagian damage yang terserap.
- Poison berpindah ke summoned enemy setelah target mati.

Reward generator menghindari pilihan identik dan meningkatkan bobot item yang kompatibel dengan build saat ini tanpa menjamin satu archetype tertentu.

## 11. Events, Shop, dan Campfire

Event awal berjumlah minimal enam dan selalu menampilkan hasil utama sebelum konfirmasi. Random outcome hanya dipakai untuk bonus, bukan penalti besar tersembunyi.

Contoh event:

- Menukar HP untuk relic cursed.
- Membersihkan curse dengan kehilangan crystal.
- Mengambil potion mutation acak atau memilih heal.
- Melawan mimic untuk treasure tambahan.
- Mengorbankan satu relic untuk meningkatkan relic lain.
- Menerima kontrak bonus objective untuk dua battle berikutnya.

Shop menjual tiga item, satu jasa, dan satu reroll. Campfire menawarkan tiga pilihan tetapi hanya satu dapat dipakai.

## 12. Boss dan Battle Spectacle

Boss memakai state machine phase terpisah. Setiap phase mengubah intent set, hazard, animasi, dan musik.

Fire Golem redesign:

- **Phase 1 — Armored Core:** armor tinggi; pemain belajar Armor Break.
- **Phase 2 — Molten Floor:** menambahkan Volatile Liquid dan serangan area.
- **Phase 3 — Inferno:** enrage, attack lebih cepat, ultimate window terbuka setelah combo tertentu.

Transisi phase:

- Menghentikan input puzzle sementara.
- Menjalankan animasi maksimal 1,8 detik.
- Mengubah musik atau menambah layer audio.
- Menampilkan rule change singkat.
- Tidak mengurangi enemy attack counter secara diam-diam.

Battle spectacle mencakup screen shake terkontrol, hit pause singkat, projectile unik per potion, damage number, phase banner, defeat dissolve, dan finisher untuk ultimate. Reduced Effects menonaktifkan shake besar, flash cepat, dan partikel padat tanpa menghilangkan informasi gameplay.

## 13. Difficulty dan Anti-Frustration

Difficulty ditentukan oleh `ThreatBudget`, bukan hanya urutan battle. Budget memilih statistik enemy, jumlah modifier, dan reward multiplier.

- Battle 1–2: satu mekanik, attack interval longgar, board tutorial-safe.
- Battle 3–5: satu modifier penuh dan intent kombinasi.
- Elite: dua modifier kompatibel, reward tinggi.
- Boss: mekanik phase tetap dan tidak mengambil modifier acak.

Proteksi pemain:

- Battle pertama tidak boleh menghasilkan board tanpa match yang jelas.
- Undo minimal tiga dan dapat ditambah build.
- Setelah dua kekalahan beruntun pada battle awal, game menawarkan Assist Mode secara non-intrusif.
- Assist Mode menambah enemy delay dan preview legal move; reward tetap sama.
- Tidak ada hidden damage scaling berdasarkan performa real-time.

## 14. Arsitektur

Komponen baru:

- `RunGenerator`: membuat graph map dan seeded content.
- `EncounterContract`: resource/data object untuk aturan battle.
- `ObjectiveController`: memantau progress dan kondisi menang.
- `ModifierController`: menerapkan hazard pada board melalui interface terbatas.
- `EnemyIntentController`: memilih dan mengeksekusi intent.
- `ComboResolver`: menyimpan history potion dan menghasilkan combo.
- `SkillController`: mana, cooldown, active skill, dan ultimate.
- `RewardGenerator`: pilihan mutation, relic, catalyst, dan upgrade.
- `BossPhaseController`: state machine boss.
- `ThreatBudget`: difficulty composition.

`BattleManager` tetap menjadi pemilik HP, shield, armor, status, dan damage resolution. `PuzzleBoard` tetap menjadi pemilik tabung dan legal pour. Sistem baru berkomunikasi melalui signal dan typed methods; modifier tidak mengubah array tabung secara langsung.

Alur data:

1. `RunGenerator` membuat node dan seed.
2. Node menghasilkan `EncounterContract`.
3. Battle screen membangun board dan controller dari contract.
4. Puzzle move masuk ke `PuzzleBoard`, lalu signal diteruskan ke intent, objective, dan battle manager.
5. Potion completion masuk ke combo dan skill systems sebelum final effect dipresentasikan.
6. Victory menghasilkan reward melalui seeded `RewardGenerator`.
7. `RunState` menyimpan build dan posisi map.

Semua content definition disimpan sebagai JSON atau Godot Resource dengan validation layer dan default fallback.

## 15. Save Compatibility dan Error Handling

- Save lama tanpa field baru otomatis mendapat default starting kit dan run baru.
- Save version dinaikkan dan migrasi bersifat idempotent.
- Active run lama yang tidak dapat dimigrasikan dikonversi menjadi crystal compensation, tidak menyebabkan crash.
- ID content yang hilang diabaikan dengan warning dan diganti fallback reward.
- Encounter contract yang invalid kembali ke battle standar Cave Slime.
- Setiap seeded generator mempunyai batas percobaan agar tidak loop selamanya.
- Animasi tidak menjadi sumber state gameplay; jika tween gagal atau dipercepat, state tetap selesai melalui controller.

## 16. Audio dan Feedback

- Layer musik eksplorasi, battle, elite, dan boss.
- Setiap potion mempunyai motif suara berbeda.
- Intent berbahaya memiliki anticipation cue.
- Combo mempunyai escalation sound berdasarkan panjang rantai.
- Ultimate mempunyai build-up, impact, dan decay.
- Semua suara penting tetap memiliki pasangan visual untuk pengguna tanpa audio.

## 17. Pengujian

Unit tests:

- Solvability board untuk setiap modifier.
- Objective progress dan kondisi menang/kalah.
- Intent preview sama dengan resolusi damage.
- Combo mapping dua dan tiga potion.
- Mana, cooldown, mutation, relic, dan catalyst stacking.
- Boss transition hanya terjadi sekali per threshold.
- ThreatBudget tidak menghasilkan kombinasi terlarang.
- Save migration dari versi saat ini.

Property/seed tests:

- Minimal 1.000 seed map menghasilkan jalur valid menuju boss.
- Minimal 1.000 encounter board mempunyai legal move dan fallback valid.
- Reward set tidak mengandung tiga pilihan identik.

Integration tests:

- Menyelesaikan satu run untuk tiap starting kit.
- Resume run setelah aplikasi ditutup pada map dan battle reward.
- Assist Mode tidak mengubah reward.
- Reduced Effects tidak mengubah timing logic.

Visual QA:

- HUD intent, mana, objective, combo, dan skill terbaca pada 576×1280 dan 720×1280.
- Tidak ada tombol di luar safe area.
- Boss phase dan hazard dapat dibedakan tanpa hanya mengandalkan warna.

## 18. Tahapan Delivery

1. Foundation: contract, objective, intent, modifier API, dan seeded tests.
2. Puzzle variety: delapan modifier dan lima objective.
3. Combat depth: mana, skill, combo resolver, dan mutation.
4. Roguelike build: kits, relic, catalyst, reward generator.
5. Run structure: branching map, event, shop, campfire, treasure.
6. Spectacle: boss phases, finisher, audio layers, dan accessibility.
7. Balance and content: full content target, seed simulation, device QA, APK.

Setiap tahap harus menghasilkan build yang dapat dimainkan dan tidak meninggalkan save pada format sementara.

## 19. Acceptance Criteria

Revisi dianggap selesai ketika:

- Peta bercabang menghasilkan minimal dua pilihan jalur pada mayoritas floor.
- Lima objective dan delapan modifier aktif serta tervalidasi.
- Tiga starting kit memiliki passive, skill, dan ultimate berbeda.
- Combo dua dan tiga potion bekerja dengan feedback lengkap.
- Target mutation, relic, catalyst, dan event terpenuhi.
- Fire Golem memiliki tiga phase yang berfungsi.
- Satu run dapat diselesaikan, disimpan, dan dilanjutkan.
- Semua logic, seed, integration, dan visual tests lulus.
- APK Android tervalidasi dan diuji pada portrait phone profile.

