param([string]$OutputDir = (Join-Path $PSScriptRoot '..\assets\audio'))

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if (-not ('PotionRogueCampaignAudio' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;

public static class PotionRogueCampaignAudio {
    const int Rate = 22050;
    const int Duration = 16;
    static short Clip(double value) {
        return (short)(Math.Max(-0.95, Math.Min(0.95, value)) * 32767.0);
    }
    public static void Build(string path, double root, double tempo, uint seed, double energy, bool verdant) {
        int frames = Rate * Duration;
        double beat = 60.0 / tempo;
        double[] scale = verdant ? new double[] {1.0, 1.2, 1.5, 1.8}
                                  : new double[] {1.0, 1.25, 1.5, 2.0};
        using (var stream = File.Create(path))
        using (var writer = new BinaryWriter(stream)) {
            writer.Write(new char[] {'R','I','F','F'}); writer.Write(36 + frames * 4);
            writer.Write(new char[] {'W','A','V','E','f','m','t',' '}); writer.Write(16);
            writer.Write((short)1); writer.Write((short)2); writer.Write(Rate);
            writer.Write(Rate * 4); writer.Write((short)4); writer.Write((short)16);
            writer.Write(new char[] {'d','a','t','a'}); writer.Write(frames * 4);
            double filtered = 0.0;
            for (int i = 0; i < frames; i++) {
                double t = (double)i / Rate;
                seed = seed * 1664525u + 1013904223u;
                double noise = ((seed >> 8) / 16777215.0) * 2.0 - 1.0;
                filtered += (noise - filtered) * (verdant ? 0.0035 : 0.0022);
                int note = ((int)(t / (beat * 2.0))) % scale.Length;
                double f = root * scale[note];
                double phrase = Math.Pow(0.5 + 0.5 * Math.Cos(Math.PI * ((t % (beat * 2.0)) / (beat * 2.0))), 2.0);
                double drone = Math.Sin(Math.PI * 2.0 * root * t) * 0.48
                    + Math.Sin(Math.PI * 2.0 * root * 1.5 * t) * 0.20;
                double melody = (Math.Sin(Math.PI * 2.0 * f * t)
                    + Math.Sin(Math.PI * 2.0 * f * 2.01 * t) * 0.18) * phrase;
                double pulsePhase = (t % beat) / beat;
                double pulse = Math.Sin(Math.PI * 2.0 * (verdant ? 62.0 : 74.0) * t)
                    * Math.Exp(-pulsePhase * 12.0);
                double baseMix = drone * energy + melody * energy * 0.34
                    + filtered * energy * (verdant ? 0.65 : 0.42) + pulse * energy * 0.22;
                double pan = Math.Sin(t * (verdant ? 0.23 : 0.31)) * 0.018;
                writer.Write(Clip(baseMix + pan)); writer.Write(Clip(baseMix - pan));
            }
        }
    }
}
'@
}

[PotionRogueCampaignAudio]::Build((Join-Path $OutputDir 'verdant_ambient.wav'), 65.41, 76.0, 88271, 0.085, $true)
[PotionRogueCampaignAudio]::Build((Join-Path $OutputDir 'verdant_boss.wav'), 58.27, 116.0, 88291, 0.125, $true)
[PotionRogueCampaignAudio]::Build((Join-Path $OutputDir 'astral_ambient.wav'), 55.00, 84.0, 99181, 0.082, $false)
[PotionRogueCampaignAudio]::Build((Join-Path $OutputDir 'astral_boss.wav'), 49.00, 126.0, 99203, 0.132, $false)
Write-Host "Generated four original campaign loops in $OutputDir"
