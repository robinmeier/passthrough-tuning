# passthrough-tuning

passthrough-tuning is a mod of the passthrough mod. the original passthrough offers midi routing between connected ports on norns. it is similar to _midi thru_ on hardware devices although it comes with some extra functionality. The -tuning mod here allows you to load various tunings from [Scala](https://www.huygens-fokker.org/scala/) files and play microtonal scales on your mididevices (and norns engines) as long as they either understand pitchbend or use musicutil. 

![animated image of passthrough mod interface](img/mod_menu.gif)

## introduction

passthrough extends norns to act as a midi routing hub. each incoming data to a port can be assigned to either a specific port for output, or all ports. it allows the user to send midi while simultaneously running a norns script.

passthrough is built as a mod and also as a library that can be added to individual scripts. they are functionally the same, but the mod version runs at all times, during scripts or when no script is loaded. If the mod is installed and turned on in the mods menu, passthrough will be running.

## use cases

- send notes through norns from a usb midi controller to a midi-compatible synthesizer. 

- scale quantization of incoming midi note data from controllers

- routing an external clock source through norns between devices

- by leveraging callbacks at a script level, incoming midi events can be shared between norns scripts and external hardware

- converting MIDI note data to cv/gate, and CC data to cv by sending to crow

- **microtuning** incoming midi using Scala `.scl` files — retune any connected synth or norns engine to just intonation, historical temperaments, or any custom scale

## requirements

norns + midi devices

if your midi hardware does not offer midi via usb, a midi interface such as an iConnectivity mio helps to connect with 5-pin midi ports.

## installation

run the following command in the maiden repl
`;install https://github.com/robinmeier/passthrough-tuning`

## getting started

passthrough assigns some midi routing settings for each connected midi device in the norns system menu found at `SYSTEM > DEVICES > MIDI` :
- `Active` turns on or off passthrough for this port
- `Target` may be all connected devices, or individual ones. this is the destination of incoming midi data 
- `Input channel` selects which midi channel is listened to for incoming midi data
- `Output channel` changes outgoing midi data to a specific midi channel, or leaves unchanged
- `Clock out` allows/prevents clock messages being output
- `Quantize midi` wraps note data to scales (quantization is set per connected midi device, so different scales can be used if desired)
- `Root` sets the root note of the current scale
- `Scale` sets the scale type (Major, Minor.. )
- `CC limit` sets the limit of midi CC messages to be sent for every channel per `25ms` timeframe. if more messages than this limit are received, then the last messages (per channel) will be sent automatically on next timeframe. this is useful when a midi controller is generating too many messages too fast (eg. moving all the faders at once on a novation launchcontrol xl). the `Pass all` option allows all CC messages to passthrough, without any kind of limiting. the `Pass none` option doesn't allow any midi CC messages to passthrough, effectively removing all of them
- `Crow note output` allows note and gate data to be sent to Monome Crow output pairs `1+2` or `3+4`.
- `Crow cc output` allows two streams of control change data to be sent to Monome Crow output pairs 1+2 or 3+4
- `Crow cc out a` sets the MIDI control change number to assign to the first of the assigned pair of `Crow cc output`
- `Crow cc out b` sets the MIDI control change number to assign to the second of the assigned pair of `Crow cc output`
- `Tuning` selects the microtuning mode: `off`, `musicutil`, or `midi pb` (see [microtuning](#microtuning) below)
- `Tuning file` selects a `.scl` file from `~/dust/data/passthrough/tunings/`
- `Tuning root` sets the root MIDI note (0–127, shown as note name e.g. C4). This is the key that plays scale degree 0. Consecutive keys play consecutive scale degrees, so the scale period (octave) repeats every N keys for an N-note scale.
- `PB voices` sets how many simultaneous voices are available in `midi pb` mode: `1`, `4`, `8`, or `16`
- `PB base ch` sets the first MIDI channel used for the pitch-bend voice pool in `midi pb` mode
- `PB range (st)` sets the pitch bend range in semitones: `1`, `2`, `4`, `12`, or `24` — must match the pitch bend range configured on your target synth

additionally, `Midi panic` is a toggle to stop all active notes if some notes are hanging.

there are two example scripts, showing how to interact with passthrough either as a mod or a library. they detail how to include it in scripts so that users can define callbacks on incoming midi data. 
### mod

navigate to the mod menu at `SYSTEM > MODS`, scroll to `PASSTHROUGH` and turn encoder 3 until a `+` symbol appears. restart norns and passthrough is running. when norns is shutdown, the current state of passthrough is saved. When norns is next powered on, this state will be recalled.

navigate back to the mod menu and this time there will be a `>` symbol to the right of PASSTHROUGH. press `key 3` and the screen should display the passthrough mod menu

#### mod menu controls
- `key 2` returns to `SYSTEM > MODS`
- `key 3` changes which midi device is being edited
- `enc 2` scrolls the menu to access parameters for the current midi device
- `enc 3` changes the value of the selected parameter

### library

passthrough can be used with the example scripts or by attaching it to external scripts, by adding the following code at the head of the script file:

```
if util.file_exists(_path.code.."passthrough") then
  local passthrough = include 'passthrough/lib/passthrough'
  passthrough.init()
end
```

the installation has been successful if `PASSTHROUGH` appears in the script's params menu.

### user event handling 

scripts can listen for midi events handled in passthrough and define their callbacks.

```
  -- script-level callbacks for midi event
  -- id is the midi device id, data is your midi data
  function user_midi_event(id, data)
      local msg = midi.to_msg(data)
      -- to find the port number, there is a helper function provided
      -- port = passthrough.get_port_from_id(id)
  end

  passthrough.user_event = user_midi_event
```

## microtuning

passthrough can retune incoming MIDI notes using [Scala](https://www.huygens-fokker.org/scala/) `.scl` files. place your `.scl` files in:

```
~/dust/data/passthrough/tunings/
```

the folder is created automatically on first run. the `Tuning file` parameter lists all `.scl` files found there. many free scale libraries are available online — the [Scala scale archive](https://www.huygens-fokker.org/scala/downloads.html) contains thousands of historical and microtonal tunings.

**key mapping:** each MIDI key plays one scale degree in order. Key `root` = degree 0, key `root+1` = degree 1, and so on. After N keys the scale period repeats one octave higher, where N is the number of degrees in the `.scl` file. A 5-note pentatonic scale therefore repeats every 5 keys; a 30-note scale spans 30 consecutive keys per octave.

there are two tuning modes:

### musicutil (for norns engines)

patches `MusicUtil.note_num_to_freq` globally so that any norns engine which uses musicutil for pitch calculation (most do) will automatically play in the selected tuning. no additional configuration of the engine is needed.

the first port with `Tuning` set to `musicutil` determines the active tuning for the whole system.

### midi pb (for external hardware and software)

applies microtuning via MIDI pitch bend messages. each simultaneous voice is assigned its own MIDI channel, with a pitch bend applied before the note-on to shift the pitch to the correct tuned frequency.

**setup steps:**

1. set `Tuning` to `midi pb`
2. choose a `Tuning file` and `Tuning root`
3. set `PB voices` to the number of simultaneous notes you need
4. set `PB base ch` to the first channel of the voice pool (e.g. `1` for channels 1–4 with 4 voices)
5. set `PB range (st)` to match the pitch bend range configured on your target synth (the default is `2` semitones, which is the most common synth default)

**pitch bend range:** tuning uses coarse + fine decomposition. the MIDI note sent to the synth is the nearest 12-TET semitone to the target pitch, and the pitch bend covers only the residual deviation (always ≤ ±50 cents). this means a PB range of `1` or `2` semitones is always sufficient for any scale, including large ones like 30-note or 31-tone equal temperament.

**note:** the voice pool channels must be free — passthrough will use them exclusively for tuned voices. if your synth does not respond to pitch bend per channel, use `musicutil` mode instead or configure your synth for polyphonic pitch bend on the relevant channels.

## issues

raise any issues experienced with passthrough either in the v2 thread on [lines](https://llllllll.co/t/passthrough-v2/49397) or by logging a new issue on the [github repo](https://www.github.com/nattog/passthrough/issues).

## contributing

wishing to contribute a new feature or change? github pull requests are welcome.

## version history

for older versions, check the [releases](https://github.com/nattog/passthrough/releases) in the repo. releases older than v2.3.0 are legacy, and no longer supported for development

