import {writeFileSync} from 'node:fs';

const sampleRate = 44100;
const duration = 12;
const samples = sampleRate * duration;
const data = new Float32Array(samples);
const notes = [261.63, 329.63, 392, 493.88, 440, 392, 329.63, 293.66];

const addBell = (start, frequency, length, gain) => {
  const startSample = Math.floor(start * sampleRate);
  const count = Math.floor(length * sampleRate);
  for (let i = 0; i < count && startSample + i < samples; i++) {
    const t = i / sampleRate;
    const envelope = Math.exp(-3.6 * t) * Math.min(1, t * 55);
    const tone = Math.sin(2 * Math.PI * frequency * t) + 0.24 * Math.sin(2 * Math.PI * frequency * 2.01 * t);
    data[startSample + i] += tone * envelope * gain;
  }
};

for (let beat = 0; beat < 24; beat++) {
  addBell(beat * 0.5, notes[beat % notes.length], 1.35, 0.12);
  if (beat % 4 === 0) addBell(beat * 0.5, notes[(beat / 4) % notes.length] / 2, 1.8, 0.075);
}

let seed = 734;
const random = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
for (let drop = 0; drop < 44; drop++) addBell(random() * duration, 1000 + random() * 1500, 0.12 + random() * 0.1, 0.012);

const bytesPerSample = 2;
const buffer = Buffer.alloc(44 + samples * bytesPerSample);
buffer.write('RIFF', 0);
buffer.writeUInt32LE(36 + samples * bytesPerSample, 4);
buffer.write('WAVEfmt ', 8);
buffer.writeUInt32LE(16, 16);
buffer.writeUInt16LE(1, 20);
buffer.writeUInt16LE(1, 22);
buffer.writeUInt32LE(sampleRate, 24);
buffer.writeUInt32LE(sampleRate * bytesPerSample, 28);
buffer.writeUInt16LE(bytesPerSample, 32);
buffer.writeUInt16LE(16, 34);
buffer.write('data', 36);
buffer.writeUInt32LE(samples * bytesPerSample, 40);
for (let i = 0; i < samples; i++) {
  const fade = Math.min(1, i / (sampleRate * 0.35), (samples - i) / (sampleRate * 0.8));
  buffer.writeInt16LE(Math.max(-1, Math.min(1, data[i] * fade)) * 32767, 44 + i * 2);
}
writeFileSync(new URL('../public/audio/little-today-music.wav', import.meta.url), buffer);
