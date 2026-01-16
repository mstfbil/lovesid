# lovesid

> Warning: This library is by no means close to complete, it may include bugs and inaccuracies when compared to the original hardware

*lovesid* is a MOS Technology 6581/8580 SID (Sound Interface Device) emulator written in Lua for use with LÖVE Framework. It may be used to play .sid files or in Commodore 64 emulators (or rather any computer using the chip) to generate sound.

## Usage

Clone the repo or copy the raw file `lovesid.lua` into your project and require it. To generate sound, all you have to do is modify the registers and call update. The library handles producing and playing the sound via `love.audio`.

### Example

```lua
-- main.lua

-- this file will play a simple triangle wave on channel 1

local sid = require("lovesid")

-- initialize the registers
sid[1] = 0x00 -- ch1 freq lo
sid[2] = 0x40 -- ch1 freq hi
sid[5] = 0x11 -- ch1 triangle wave, gate open
sid[6] = 0xa0 -- ch1 attack and decay
sid[7] = 0xf0 -- ch1 sustain and release

sid[25] = 0x0f -- global volume high, no filter

function love.update()
    sid:update()
end
```

In the Commodore 64, the SID chip's registers start at address `$d400`, but in lovesid it starts from 1. This necessitates offsetting the address for use when emulating machines.

`sid[realAddress - 0xd3ff] = value`

## Development

- ADSR and filters work but don't sound exactly the same with SID
- It is possible that there are some bugs
