2025-10-15 20:25
Status:
Tags:
## Attempting virtual monitor on Hyprland for Sunshine

Downloaded edid firmware for TV from https://git.linuxtv.org/v4l-utils.git/tree/utils/edid-decode/data. EDID is appparently used for colour profiles(?)

put the firmware file in `/usr/lib/firmware/edid/` and edited the `/etc/mkinitcpio.conf`. Also had to run kernelcmd command to load an existing unconnected output with the firmware specifications.
Omarchy uses limine for boot configs(?).  Ran the kernelcmd in `/boot/limine.conf`. This part here was failing as I remade mkinicpio. The conf file was being overwritten.

So I gave up. For now.

References
https://www.azdanov.dev/articles/2025/how-to-create-a-virtual-display-for-sunshine-on-arch-linux