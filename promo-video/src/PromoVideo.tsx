import React from "react";
import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const gold = "#f3c866";
const lilac = "#d9b8ff";
const ink = "#100b1d";
const muted = "#aaa3ba";

const screenshots = {
  battle: "screenshots/02-battle-potion-sigils.png",
  map: "screenshots/04-realm-map.png",
  realms: "screenshots/03-campaign-unlock.png",
  workshop: "screenshots/07-arcane-workshop.png",
};

function fade(frame: number, start: number, length = 18) {
  return interpolate(frame, [start, start + length], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
}

function Background({ image = "feature" }: { image?: "feature" | "battle" }) {
  return (
    <>
      <AbsoluteFill style={{ background: ink }} />
      <Img
        src={staticFile(
          image === "feature"
            ? "feature-graphic.png"
            : screenshots.battle,
        )}
        style={{
          height: "100%",
          objectFit: "cover",
          opacity: image === "feature" ? 0.38 : 0.22,
          width: "100%",
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(12,7,22,.98) 0%, rgba(15,9,27,.78) 46%, rgba(12,7,20,.97) 100%)",
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(circle at 72% 44%, rgba(106,53,159,.33), transparent 34%), radial-gradient(circle at 18% 76%, rgba(24,111,139,.18), transparent 30%)",
        }}
      />
    </>
  );
}

function TopBrand() {
  return (
    <div
      style={{
        alignItems: "center",
        color: muted,
        display: "flex",
        fontFamily: "Arial, sans-serif",
        fontSize: 18,
        gap: 12,
        left: 80,
        letterSpacing: 5,
        position: "absolute",
        textTransform: "uppercase",
        top: 55,
      }}
    >
      <span style={{ color: gold, fontSize: 25 }}>✦</span>
      <span>Potion Rogue</span>
    </div>
  );
}

function FooterLabel({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        bottom: 55,
        color: "#827895",
        fontFamily: "Arial, sans-serif",
        fontSize: 16,
        letterSpacing: 3,
        position: "absolute",
        right: 80,
        textTransform: "uppercase",
      }}
    >
      {children}
    </div>
  );
}

function ScreenCard({
  src,
  left,
  top = 150,
  width = 440,
  rotate = 0,
  delay = 0,
}: {
  src: string;
  left: number;
  top?: number;
  width?: number;
  rotate?: number;
  delay?: number;
}) {
  const frame = useCurrentFrame();
  const progress = spring({
    frame: Math.max(0, frame - delay),
    fps: 30,
    config: { damping: 16, mass: 0.8, stiffness: 110 },
  });
  const scale = interpolate(progress, [0, 1], [0.92, 1]);
  return (
    <div
      style={{
        border: `2px solid ${gold}`,
        borderRadius: 28,
        boxShadow: "0 28px 70px rgba(0,0,0,.58), 0 0 0 8px rgba(230,185,103,.08)",
        left,
        overflow: "hidden",
        position: "absolute",
        top,
        transform: `rotate(${rotate}deg) scale(${scale})`,
        transformOrigin: "center bottom",
        width,
      }}
    >
      <Img
        src={staticFile(src)}
        style={{ display: "block", height: "auto", width: "100%" }}
      />
    </div>
  );
}

function Pill({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        border: "1px solid rgba(243,200,102,.55)",
        borderRadius: 999,
        color: gold,
        display: "inline-flex",
        fontFamily: "Arial, sans-serif",
        fontSize: 15,
        letterSpacing: 2,
        padding: "10px 18px",
        textTransform: "uppercase",
      }}
    >
      {children}
    </div>
  );
}

function CopyBlock({
  eyebrow,
  title,
  body,
  align = "left",
}: {
  eyebrow: string;
  title: string;
  body: string;
  align?: "left" | "center";
}) {
  const frame = useCurrentFrame();
  const opacity = fade(frame, 8);
  return (
    <div
      style={{
        alignItems: align === "center" ? "center" : "flex-start",
        display: "flex",
        flexDirection: "column",
        opacity,
        textAlign: align,
      }}
    >
      <Pill>{eyebrow}</Pill>
      <div
        style={{
          color: "#fff5db",
          fontFamily: "Georgia, serif",
          fontSize: 65,
          fontWeight: 400,
          letterSpacing: -2,
          lineHeight: 1.02,
          marginTop: 25,
          maxWidth: 720,
        }}
      >
        {title}
      </div>
      <div
        style={{
          color: muted,
          fontFamily: "Arial, sans-serif",
          fontSize: 25,
          lineHeight: 1.45,
          marginTop: 22,
          maxWidth: 650,
        }}
      >
        {body}
      </div>
    </div>
  );
}

function Opening() {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Background />
      <AbsoluteFill
        style={{
          background: "linear-gradient(90deg, rgba(12,7,20,.12), rgba(12,7,20,.72))",
        }}
      />
      <TopBrand />
      <div
        style={{
          alignItems: "center",
          display: "flex",
          flexDirection: "column",
          left: 160,
          position: "absolute",
          textAlign: "center",
          top: 315,
          width: 820,
        }}
      >
        <div style={{ color: gold, fontSize: 21, letterSpacing: 8, opacity: fade(frame, 12) }}>
          SORT  •  BREW  •  CONQUER
        </div>
        <div
          style={{
            color: "#fff4d7",
            fontFamily: "Georgia, serif",
            fontSize: 104,
            letterSpacing: -5,
            lineHeight: .96,
            marginTop: 22,
            opacity: fade(frame, 22),
            textShadow: "0 5px 24px rgba(0,0,0,.85)",
          }}
        >
          POTION
          <br />
          <span style={{ color: gold }}>ROGUE</span>
        </div>
        <div style={{ color: lilac, fontFamily: "Arial, sans-serif", fontSize: 23, letterSpacing: 6, marginTop: 25, opacity: fade(frame, 42) }}>
          SORT PUZZLE RPG
        </div>
      </div>
      <FooterLabel>Offline roguelike adventure</FooterLabel>
    </AbsoluteFill>
  );
}

function BattleScene() {
  return (
    <AbsoluteFill>
      <Background image="battle" />
      <TopBrand />
      <ScreenCard delay={5} left={180} top={130} src={screenshots.battle} width={470} rotate={-3} />
      <div style={{ left: 840, position: "absolute", top: 265 }}>
        <CopyBlock
          eyebrow="Puzzle combat"
          title="Every pour becomes a spell."
          body="Sort each potion to attack, shield, heal, or poison before the enemy gets its next move."
        />
        <div style={{ color: "#8edcff", fontFamily: "Arial, sans-serif", fontSize: 17, letterSpacing: 2, marginTop: 42 }}>
          LIVE TURN-BASED DECISIONS
        </div>
      </div>
      <FooterLabel>01  /  04</FooterLabel>
    </AbsoluteFill>
  );
}

function BuildScene() {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Background />
      <TopBrand />
      <div style={{ left: 120, position: "absolute", top: 240 }}>
        <CopyBlock
          eyebrow="Roguelike routes"
          title="Build a run that survives the dark."
          body="Choose your path, take calculated risks, and shape a build with relics, upgrades, events, and boss rematches."
        />
        <div style={{ display: "flex", gap: 12, marginTop: 38, opacity: fade(frame, 12) }}>
          <Pill>Map</Pill>
          <Pill>Events</Pill>
          <Pill>Bosses</Pill>
        </div>
      </div>
      <ScreenCard delay={12} left={1110} top={120} src={screenshots.map} width={500} rotate={3} />
      <FooterLabel>02  /  04</FooterLabel>
    </AbsoluteFill>
  );
}

function RealmsScene() {
  return (
    <AbsoluteFill>
      <Background />
      <TopBrand />
      <ScreenCard delay={5} left={160} top={135} src={screenshots.realms} width={485} rotate={-2} />
      <div style={{ left: 830, position: "absolute", top: 260 }}>
        <CopyBlock
          eyebrow="Five realms"
          title="A new threat waits behind every gate."
          body="Explore Shadow Crypt, Verdant Catacombs, Astral Foundry, Frostbound Reliquary, and Abyssal Apothecary."
        />
        <div style={{ color: gold, fontFamily: "Arial, sans-serif", fontSize: 19, letterSpacing: 2, marginTop: 42 }}>
          35+ ENCOUNTERS  •  5 BOSS FIGHTS
        </div>
      </div>
      <FooterLabel>03  /  04</FooterLabel>
    </AbsoluteFill>
  );
}

function UnlockScene() {
  const frame = useCurrentFrame();
  const glow = interpolate(Math.sin(frame / 12), [-1, 1], [0.35, 0.75]);
  return (
    <AbsoluteFill>
      <Background />
      <TopBrand />
      <div style={{ alignItems: "center", display: "flex", flexDirection: "column", left: 100, position: "absolute", top: 220, width: 760 }}>
        <div style={{ color: gold, fontFamily: "Arial, sans-serif", fontSize: 18, letterSpacing: 5, opacity: fade(frame, 10) }}>
          ONE-TIME PURCHASE
        </div>
        <div style={{ color: "#fff4d7", fontFamily: "Georgia, serif", fontSize: 71, lineHeight: 1.02, marginTop: 20, textAlign: "center" }}>
          Unlock every realm.
        </div>
        <div style={{ color: muted, fontFamily: "Arial, sans-serif", fontSize: 25, lineHeight: 1.45, marginTop: 23, textAlign: "center" }}>
          Permanent access to the full dark-fantasy campaign.
        </div>
        <div style={{ border: `2px solid rgba(243,200,102,${glow})`, borderRadius: 16, boxShadow: `0 0 40px rgba(243,200,102,${glow * .26})`, color: gold, fontFamily: "Arial, sans-serif", fontSize: 30, fontWeight: 700, letterSpacing: 3, marginTop: 40, padding: "18px 40px" }}>
          US$4.99
        </div>
      </div>
      <ScreenCard delay={8} left={1060} top={115} src={screenshots.workshop} width={510} rotate={3} />
      <FooterLabel>04  /  04</FooterLabel>
    </AbsoluteFill>
  );
}

function Closing() {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Background />
      <TopBrand />
      <div style={{ alignItems: "center", display: "flex", flexDirection: "column", left: 200, opacity: fade(frame, 8), position: "absolute", textAlign: "center", top: 300, width: 1520 }}>
        <div style={{ color: gold, fontFamily: "Arial, sans-serif", fontSize: 21, letterSpacing: 7 }}>POTION ROGUE</div>
        <div style={{ color: "#fff4d7", fontFamily: "Georgia, serif", fontSize: 86, letterSpacing: -3, lineHeight: 1, marginTop: 22 }}>Your next run starts now.</div>
        <div style={{ color: lilac, fontFamily: "Arial, sans-serif", fontSize: 25, letterSpacing: 3, marginTop: 28 }}>SORT PUZZLE RPG  •  PLAY FREE ON GOOGLE PLAY</div>
        <div style={{ border: `1px solid ${gold}`, borderRadius: 10, color: gold, fontFamily: "Arial, sans-serif", fontSize: 19, letterSpacing: 4, marginTop: 50, padding: "14px 26px" }}>DOWNLOAD THE ADVENTURE</div>
      </div>
      <FooterLabel>Fareza Games  •  Offline by design</FooterLabel>
    </AbsoluteFill>
  );
}

export const PromoVideo: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  return (
    <AbsoluteFill style={{ backgroundColor: ink }}>
      <Sequence durationInFrames={105}>
        <Opening />
      </Sequence>
      <Sequence from={105} durationInFrames={210}>
        <BattleScene />
      </Sequence>
      <Sequence from={315} durationInFrames={210}>
        <BuildScene />
      </Sequence>
      <Sequence from={525} durationInFrames={210}>
        <RealmsScene />
      </Sequence>
      <Sequence from={735} durationInFrames={105}>
        <UnlockScene />
      </Sequence>
      <Sequence from={840} durationInFrames={Math.max(1, durationInFrames - 840)}>
        <Closing />
      </Sequence>
      <div style={{ background: "rgba(255,255,255,.025)", height: 1, left: 80, position: "absolute", right: 80, top: 1040 }} />
      <div style={{ background: gold, height: 1, left: 80, position: "absolute", top: 1040, transform: `scaleX(${interpolate(frame, [0, 900], [0, 1], { extrapolateRight: "clamp" })})`, transformOrigin: "left", width: 1760 }} />
    </AbsoluteFill>
  );
};
