#!/usr/bin/env python
"""
analyze_buzz.py — Quantify the per-note "buzz" on a Zelda port audio dump.

Reads a WAV file produced by BizHawk's --dump-type=WavWriter, slices out a
sustained-music window (after boot silence), and runs an FFT to report:

  * Spectral flatness / noise floor above 4 kHz
  * Inharmonic vs harmonic energy ratio around the dominant pitch
  * RMS envelope (to detect per-note amplitude spikes)

Usage:
  python tools/analyze_buzz.py <wav-file>

No scipy dependency — numpy + stdlib wave only.
"""

import sys
import wave
import numpy as np


def load_wav(path):
    with wave.open(path, "rb") as w:
        nch = w.getnchannels()
        sw = w.getsampwidth()
        fr = w.getframerate()
        nf = w.getnframes()
        raw = w.readframes(nf)
    if sw == 2:
        data = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    elif sw == 1:
        data = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    else:
        raise RuntimeError(f"unsupported sample width {sw}")
    if nch > 1:
        data = data.reshape(-1, nch).mean(axis=1)
    return data, fr


def find_music_window(data, fr, target_sec=3.0):
    """Find first sustained loud window of target_sec length after boot silence."""
    win = int(0.1 * fr)  # 100 ms chunks
    rms = np.array([np.sqrt(np.mean(data[i:i+win]**2))
                    for i in range(0, len(data) - win, win)])
    # Threshold at 5% of peak RMS
    thresh = 0.05 * rms.max()
    loud = np.where(rms > thresh)[0]
    if len(loud) == 0:
        print("WARN: no loud region found, using middle of file")
        start = len(data) // 2
    else:
        start = loud[0] * win
    end = min(start + int(target_sec * fr), len(data))
    return start, end


def spectral_flatness(x):
    """Geometric mean / arithmetic mean of spectrum magnitude. 0=pure tone, 1=white noise."""
    X = np.abs(np.fft.rfft(x))
    X = X[X > 1e-12]
    if len(X) == 0:
        return 0.0
    log_gm = np.mean(np.log(X))
    am = np.mean(X)
    return float(np.exp(log_gm) / am) if am > 0 else 0.0


def band_energy(x, fr, lo, hi):
    X = np.abs(np.fft.rfft(x))
    freqs = np.fft.rfftfreq(len(x), 1.0 / fr)
    mask = (freqs >= lo) & (freqs < hi)
    return float(np.sum(X[mask] ** 2))


def dominant_pitch(x, fr, lo=80.0, hi=1200.0):
    """Crude: find strongest peak in [lo, hi] Hz band."""
    X = np.abs(np.fft.rfft(x))
    freqs = np.fft.rfftfreq(len(x), 1.0 / fr)
    mask = (freqs >= lo) & (freqs < hi)
    idx = np.argmax(X[mask])
    return float(freqs[mask][idx]), float(X[mask][idx])


def harmonic_ratio(x, fr, f0, n_harm=8, band=0.03):
    """Energy at harmonics vs total energy in (f0, n_harm*f0) band."""
    X = np.abs(np.fft.rfft(x)) ** 2
    freqs = np.fft.rfftfreq(len(x), 1.0 / fr)
    total_mask = (freqs >= f0 * 0.5) & (freqs < f0 * n_harm * 1.1)
    total = float(X[total_mask].sum())
    harm = 0.0
    for n in range(1, n_harm + 1):
        fn = f0 * n
        mask = (freqs >= fn * (1 - band)) & (freqs < fn * (1 + band))
        harm += float(X[mask].sum())
    return (harm / total) if total > 0 else 0.0


def analyze(path):
    print(f"=== {path} ===")
    data, fr = load_wav(path)
    dur = len(data) / fr
    print(f"length: {dur:.2f} s @ {fr} Hz, {len(data)} samples")
    print(f"peak: {np.max(np.abs(data)):.4f}, rms: {np.sqrt(np.mean(data**2)):.4f}")

    start, end = find_music_window(data, fr, target_sec=2.0)
    print(f"analyzing window [{start/fr:.2f}s .. {end/fr:.2f}s]")
    win = data[start:end]
    # Window the signal to reduce FFT leakage
    w = np.hanning(len(win))
    winw = win * w

    sf = spectral_flatness(winw)
    print(f"spectral flatness (0=tone, 1=noise): {sf:.4f}")

    # Band energies
    e_lf = band_energy(winw, fr, 20, 500)
    e_mf = band_energy(winw, fr, 500, 4000)
    e_hf = band_energy(winw, fr, 4000, 12000)
    e_vhf = band_energy(winw, fr, 12000, fr / 2 - 1)
    total = e_lf + e_mf + e_hf + e_vhf
    if total > 0:
        print(f"band ratios: LF={e_lf/total*100:5.1f}%  MF={e_mf/total*100:5.1f}%  "
              f"HF={e_hf/total*100:5.1f}%  VHF={e_vhf/total*100:5.1f}%")

    f0, amp = dominant_pitch(winw, fr)
    print(f"dominant pitch ~{f0:.1f} Hz (amp {amp:.2f})")
    if f0 > 0:
        hr = harmonic_ratio(winw, fr, f0)
        print(f"harmonic ratio at f0={f0:.0f}: {hr*100:.1f}% (100%=pure harmonic, 0%=inharmonic noise)")

    # Top 20 spectral peaks
    X = np.abs(np.fft.rfft(winw))
    freqs = np.fft.rfftfreq(len(winw), 1.0 / fr)
    # Limit to audible range
    mask = (freqs >= 20) & (freqs < 8000)
    Xm = X.copy()
    Xm[~mask] = 0
    top_idx = np.argsort(Xm)[-20:][::-1]
    print("\ntop 20 spectral peaks (20-8000 Hz):")
    for i in top_idx:
        if Xm[i] > 0:
            print(f"  {freqs[i]:7.1f} Hz  amp={Xm[i]:8.2f}")

    # High-freq buzz signature: is there significant energy above 6 kHz?
    if total > 0:
        above_6k = band_energy(winw, fr, 6000, fr / 2 - 1) / total
        print(f"\nenergy above 6 kHz (buzz signature): {above_6k*100:.2f}% of total")
        if above_6k > 0.1:
            print("  ^^^ NOTABLE high-frequency content — likely audible as buzz")

    print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python tools/analyze_buzz.py <wav-file>")
        sys.exit(1)
    for p in sys.argv[1:]:
        analyze(p)
