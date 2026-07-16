param([string]$OutputDir = (Join-Path $PSScriptRoot '..\assets\audio'))

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if (-not ('PotionRogueAmbient' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;

public static class PotionRogueAmbient {
    const int Rate = 22050;
    const int Duration = 24;

    static double CyclicBell(double t, double at, double frequency, double length) {
        double distance = (t - at + Duration) % Duration;
        if (distance > length) return 0.0;
        double attack = Math.Min(1.0, distance / 0.025);
        double envelope = attack * Math.Exp(-distance * 2.15) * (1.0 - distance / length);
        return (Math.Sin(Math.PI * 2.0 * frequency * distance)
            + Math.Sin(Math.PI * 2.0 * frequency * 2.01 * distance) * 0.34) * envelope;
    }

    static short Clip(double value) {
        value = Math.Max(-0.96, Math.Min(0.96, value));
        return (short)(value * 32767.0);
    }

    public static void Build(string path, bool boss) {
        int frames = Rate * Duration;
        using (var stream = File.Create(path))
        using (var writer = new BinaryWriter(stream)) {
            writer.Write(new char[] {'R','I','F','F'});
            writer.Write(36 + frames * 4);
            writer.Write(new char[] {'W','A','V','E','f','m','t',' '});
            writer.Write(16); writer.Write((short)1); writer.Write((short)2);
            writer.Write(Rate); writer.Write(Rate * 4); writer.Write((short)4); writer.Write((short)16);
            writer.Write(new char[] {'d','a','t','a'}); writer.Write(frames * 4);
            uint noise = boss ? 99173u : 73129u;
            double filtered = 0.0;
            double root = boss ? 49.0 : 55.0;
            for (int i = 0; i < frames; i++) {
                double t = (double)i / Rate;
                noise = noise * 1664525u + 1013904223u;
                double raw = ((noise >> 8) / 16777215.0) * 2.0 - 1.0;
                filtered += (raw - filtered) * 0.0028;
                double breath = 0.72 + 0.28 * Math.Sin(Math.PI * 2.0 * t / 12.0);
                double drone = Math.Sin(Math.PI * 2.0 * root * t) * 0.43
                    + Math.Sin(Math.PI * 2.0 * root * 1.5 * t) * 0.22
                    + Math.Sin(Math.PI * 2.0 * root * 2.0 * t) * 0.12;
                double pulse = boss
                    ? Math.Pow(Math.Max(0.0, Math.Sin(Math.PI * 2.0 * t / 1.5)), 10.0) * 0.18
                    : Math.Sin(Math.PI * 2.0 * t / 8.0) * 0.035;
                double bells = CyclicBell(t, boss ? 3.0 : 5.5, boss ? 196.0 : 220.0, 2.8)
                    + CyclicBell(t, boss ? 11.0 : 14.0, boss ? 233.08 : 277.18, 3.1) * 0.78
                    + CyclicBell(t, boss ? 18.5 : 20.5, boss ? 293.66 : 329.63, 2.6) * 0.62;
                double baseMix = drone * breath * (boss ? 0.105 : 0.085)
                    + filtered * (boss ? 0.11 : 0.075) + pulse + bells * 0.07;
                double shimmerL = Math.Sin(Math.PI * 2.0 * (root * 4.0) * t + Math.Sin(t * 0.23)) * 0.012;
                double shimmerR = Math.Sin(Math.PI * 2.0 * (root * 4.02) * t - Math.Sin(t * 0.19)) * 0.012;
                writer.Write(Clip(baseMix + shimmerL));
                writer.Write(Clip(baseMix + shimmerR));
            }
        }
    }
}
'@
}

[PotionRogueAmbient]::Build((Join-Path $OutputDir 'dungeon_ambient.wav'), $false)
[PotionRogueAmbient]::Build((Join-Path $OutputDir 'boss_ambient.wav'), $true)
Write-Host "Generated original looping ambience in $OutputDir"
