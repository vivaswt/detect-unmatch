# detect-unmatch

A small Haskell command-line tool for detecting mismatches between MP3 filenames and their ID3 metadata.

## Purpose

This tool is intended for checking collections of MP3 files whose filenames encode their song position.

For example:

```text
01-03.mp3
```

means:

```text
Album: 1
Track: 3
```

The tool extracts the expected position from the filename and compares it with the position stored in the MP3 metadata.

When a mismatch is found, it reports both positions.

Example:

```text
fileName(Album:1, Track:3)-tag(Album:1, Track:4)
```

## How it works

The processing pipeline is roughly:

```text
Medley directories
      ↓
MP3 files
      ↓
MP3 metadata
      ↓
┌───────────────────────┐
│                       │
│ Filename              │ MP3 tag
│ "01-03.mp3"           │ Album / Track
│                       │
└───────────┬───────────┘
            ↓
      SongPosition
            ↓
       Compare them
            ↓
    Find first mismatch
```

The current program expects the music directory to contain directories named:

```text
メドレー01
メドレー02
...
メドレー14
```

The root directory is currently configured in `musicDir` in `Main.hs`.

## Requirements

* GHC
* Stack
* Haskell Language Server (recommended for VS Code)

The project currently uses packages including:

* `flow`
* `monatone`
* `regex-tdfa`
* `raw-strings-qq`
* `text`
* `directory`
* `filepath` / `os-path` related packages

The exact dependency versions are managed by Stack.

## Build

From the project directory:

```bash
stack build
```

## Run

```bash
stack run
```

The program scans the configured medley directories and looks for the first mismatch between filename information and MP3 tag information.

If no mismatch is found:

```text
No unmatched found.
```

## Filename format

The current filename parser expects filenames ending in:

```text
NN-NN.mp3
```

where the first number is the album/medley number and the second number is the track number.

For example:

```text
01-01.mp3
01-02.mp3
02-01.mp3
14-12.mp3
```

The parser extracts the two two-digit numbers using a regular expression.

## MP3 metadata

The program uses [`monatone`](https://hackage.haskell.org/package/monatone) to read MP3 metadata.

The following metadata fields are currently used:

* `album`
* `artist`
* `title`
* `trackNumber`

The album number is currently extracted from the last two characters of the album tag, while the track number comes from the MP3 track-number metadata.

## Project status

This is a small personal utility and is currently a work in progress.

The current implementation focuses on:

* discovering MP3 files
* reading MP3 metadata
* extracting song positions
* detecting the first mismatch

Possible future improvements include:

* reporting all mismatches instead of only the first one
* reporting which file caused the mismatch
* better error handling for malformed filenames
* better error handling for invalid or missing metadata
* making the music directory configurable
* removing assumptions about the number and names of medley directories

## Development

The project is written in Haskell and uses `OsPath` for filesystem paths.

The code intentionally keeps filesystem and MP3 metadata operations in `IO` while keeping the actual comparison logic pure where practical.

For example, a song position is represented by:

```haskell
data SongPosition = SongPosition
  { songPositionAlbumNumber :: Int
  , songPositionTrackNumber :: Int
  }
  deriving (Eq)
```

This allows filename-derived and metadata-derived positions to be compared directly with `(==)` / `(/=)`.

## License

Personal project. No license has been specified yet.
