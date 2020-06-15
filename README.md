# ProSeed for Farming Simulator 19
![For Farming Simulator 19](https://img.shields.io/badge/Farming%20Simulator-19-FF7C00.svg) [![Releases](https://img.shields.io/github/release/stijnwop/proSeed.svg)](https://github.com/stijnwop/proSeed/releases)

ProSeed adds a bundle of functionality to enhance sowing machines in the game.
With ProSeed you're able to create tramlines (with optional pre-emergence marking), halfside shutoff for creating the perfect tramlines, fertilizer shutoff and active feedback with sounds.

## Publishing
Only Wopster is allowed to publish any of this code as a mod to any mod site, or file sharing site. The code is open for your own use, but give credit where due. I will not accept support for any 'version' of the ProSeed that is obtained from a sketchy mod page. Versioning is controlled by me and not by any other page. This confuses people and really holds back the development which results in no fun for me!


## Special thanks to
Special thanks to gotchTOM and webalizer for allowing me to redo the mod for FS19!

## Warning!
Please be aware that this is a ***DEVELOPMENT VERSION***!
* The development version can break the game or your savegame!
* The development version can break the game or your savegame!
* The development version doesn´t support the full feature package yet!

#### Multiplayer
This version should also work in Multiplayer.

# Installation / Releases
Currently the development version is only available via GitHub. When a official release version is avaiable you can download the latest version from the [release section](https://github.com/stijnwop/proSeed/releases).

> _Please note: if there's no release version available it means there's no official release yet._

All official releases will be available at the offical Farming Simulator ModHub.

For installing the release:

Windows: Copy the `FS19_proSeed_rc_<version>.zip` into your `My Games\FarmingSimulator2019\mods` directory.

## Documentation

### Overview
When a sowing machine is attached the following HUD will be displayed.
![Image](docs/images/hud.png)

In the table below there's a description on what every bottom does.

| Number | Description |
| ------------- | ------------------ |
| 1 | Toggle pre-emergence marking |
| 2 | Toggle fertilizer usage |
| 3 | Change the tramline mode (manual, semi and auto) |
| 4 | Change the tramline distance (to fit your followup machines e.g. spreader and sprayers) |
| 5 | Minimize and maximize the HUD display |
| 6 | Change track number (only in semi mode) |
| 7 | Toggle halfside shutoff mode |
| 8 | Toggle interactive sounds |

> **NOTE: Some functions / buttons are only available for certain modes, they will be marked grey when disabled.**

Further there are some visuals that help you guide your seeding process. In the top bar the seed usage and hectare counters are displayed. In order to reset them you can click on the reset button.
In the middle of the HUD the working width of your seeder is displayed together with the marker state. The big orange bar on the bottom displays if the tramline is active or if a part of the seeder is shutoff.

You can position the HUD to any position you desire and the position will be saved.

### Usage

#### Modes
In the table below the possible modes are explained. You can toggle the modes by clicking on the arrows shown at number 3 of the HUD image from above.

| Mode | Description | Supports helper |
| ------------- | ------------------ | ------------------ |
| Manual | In `Manual` mode the player has full freedom whether to create the tramline or not by simply pressing the buttons `KEY_lctrl + KEY_r`. The option to configure distance or counting tracks are disabled. | no
| Semi | In `Semi` mode the player has to configure the tramline distance by clicking on the arrows (increment is based on the working width). The tracks are counted automatically when the sowing machine is lifted, you can manually correct this in the HUD. Tramlines are created automatically. | yes
| Auto | In `Auto` mode the player only has to configure the tramline distance by clicking on the arrows (increment is based on the working width). Correct the working width of GPS when needed and the tracks will be counted automatically by the GuidanceSteering mod. Tramlines are created automatically. | no

> **NOTE: In order to use the mode `Auto` the [GuidanceSteering](https://www.farming-simulator.com/mod.php?mod_id=140328&title=fs2019) mod is required!**

#### How to start
If the number of total amount of lanes is even, always start with a half track otherwise the distance to the edge of the field will not be valid. 
E.g. in the HUD above you have a total of 2 lanes `x / 2` so in this case you start with a half line.

Use the halfside shutoff function for creating the first track. 
When using GuidanceSteering, the first track of GS must be aligned at the edge of the field and set to zero (`ALT + HOME`). 
For the second track shift the GS track by half the working width towards the field edge.

A description of possible working widths and distances is given in this neat PDF file: [proSeed-eng.pdf](https://github.com/stijnwop/proSeed/raw/master/docs/ProSeed.pdf) (German: [proSeed-de.pdf](https://github.com/stijnwop/proSeed/raw/master/docs/ProSeed-de.pdf))
## Copyright
Copyright (c) 2020 [Wopster](https://github.com/stijnwop).
All rights reserved.
