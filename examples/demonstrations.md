# Document demonstrating wide tables in markdown-ts-mode

An example document for `markdown-table-view-mode`, modelled on a real
one: a list of lecture demonstrations, with links to a catalogue and to
index cards. The table is wider than `fill-column`, its cells hold
several links each, and one cell uses `<br>` to start a new line.

The linked files are not included, so the links do not open anything.
They are not needed to show the problem: with the file names in the
links, the raw rows of the table cannot be read, and this package draws
them as a table that can.

## Lecture 1, Introduction

| Demonstration | Catalogue | Index card |
|---|---|---|
| Additive colour mixing | [Additive colour mixing with three projectors](catalogue/catalogue.md#additive-colour-mixing-with-three-projectors) (p. 144); [Additive colour mixing](catalogue/catalogue.md#additive-colour-mixing) (p. 147) | [OP 14.11 Additive colour mixing](cards/optics.md#op-1411-additive-colour-mixing) (p. 192) |
| Pixels of a monitor | [Pixels of a monitor](catalogue/catalogue.md#pixels-of-a-monitor) (p. 144) | — |
| Subtractive colour mixing | [Subtractive colour mixing](catalogue/catalogue.md#subtractive-colour-mixing) (p. 146) | [OP 14.14 Subtractive colour mixing](cards/optics.md#op-1414-subtractive-colour-mixing) (p. 195) |
| Three polarising filters | [Brightening with a third polarising filter](catalogue/catalogue.md#brightening-with-a-third-polarising-filter) (p. 170) [Video](https://example.org/demonstrations/optics/polarisers/) | [OP 09.16 Polarisation apparatus, brightening with a third filter](cards/optics.md#op-0916-polarisation-apparatus-brightening-with-a-third-filter) (p. 140) |
| Water cell: scattering of polarised light | [Polarisation and scattering](catalogue/catalogue.md#polarisation-and-scattering) (p. 172) [Video](https://example.org/demonstrations/optics/plane-of-polarisation/) | [OP 09.17 Polarisation and scattering](cards/optics.md#op-0917-polarisation-and-scattering) (p. 141) |
| Decimetre-wave transmitter <br>*The dipole radiation set-up (433.92 MHz, light bulb in the receiver) is the newer one. Card WA 05.04 shows the same demonstration with an older 1 GHz oscillator, where the receiving dipole and the meter have to be watched at the same time.* | [Dipole radiation](catalogue/catalogue.md#dipole-radiation) (p. 77) | [WA 05.04 Radiation pattern of a dipole](cards/waves.md#wa-0504-radiation-pattern-of-a-dipole) (p. 160) |
| Double slit with a laser | [Interference at a double slit](catalogue/catalogue.md#interference-at-a-double-slit) (p. 164) [Video](https://example.org/demonstrations/optics/double-slit/) | [OP 06.02 Double slit with a line sensor](cards/optics.md#op-0602-double-slit-with-a-line-sensor) (p. 91) |
| Spectra of a mercury lamp and a halogen lamp | [Spectra of a mercury lamp and an arc lamp](catalogue/catalogue.md#spectra-of-a-mercury-lamp-and-an-arc-lamp) (p. 160) [Video](https://example.org/demonstrations/optics/prism-spectrograph/) | [OP 13.03 Spectral lines in the visible and the UV](cards/optics.md#op-1303-spectral-lines-in-the-visible-and-the-uv) (p. 177) |
| Single photons with a photomultiplier | [Single photons with a photomultiplier](catalogue/catalogue.md#single-photons-with-a-photomultiplier) (p. 175) [Video](https://example.org/demonstrations/optics/single-photons/); [Single photons](catalogue/catalogue.md#single-photons) (p. 175) [Video](https://example.org/demonstrations/optics/single-photons/) | — |

