import React from "react";
import { Composition, registerRoot } from "remotion";
import { PromoVideo } from "./PromoVideo";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="PotionRoguePromo"
        component={PromoVideo}
        durationInFrames={900}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};

registerRoot(RemotionRoot);
