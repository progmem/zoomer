# Zoomer - Taito ZSG-2 Sample Extractor

This program provides a means for extracting audio samples from a sound ROM intended for use by the Taito ZOOM (ZSG-2) sound processor. Samples are extracted in a raw form with zero post-processing, requiring the user of this software to make adjustments as necessary in order to make these samples useful.

## Usage

A recent version of Crystal (at this time, 0.36.1) is required. Simply run `shards build` to build the program, then run `bin/zoomer [file]`. The file should be the Taito ZSG-2 sound ROM that you wish to extract from; check the MAME documentation for more information on which file correlates to the sound ROM.

At this time, this has only been tested with G-Darius (e39-04.27), as that was the game of interest. Other games that use the ZSG-2 should also work, assuming the MAME implementation of sample playback works for those games as well.
