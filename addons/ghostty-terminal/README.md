# Ghostty Terminal for Godot

A libghostty (https://github.com/ghostty-org/ghostty) based Terminal panel for the Godot editor.

Has support for multiple tabs, terminal bells, customisable font family and size and a hotkey to open it (defaults to VSCode's Ctrl+`).

The add-on requires Godot 4.5 or newer.

## Install

Download the latest release from https://github.com/HamishWHC/godot-ghostty-terminal/releases and extract it into the root of a Godot project.

## Build

Pre-requisites:

- Rust 1.97 or newer (older may work - untested)
- Zig 0.16.0 on `PATH`
- uv

Build:

```sh
cargo build
./package.py
```

This both packages a copy of the addon and installs the plugin in a minimal Godot project in `./demo`

## Build a release library

Build on the target operating system with Cargo:

```sh
cargo build --locked --release
```

## Contributing

PRs are welcome. I may respond to/fix issues but who knows when :)