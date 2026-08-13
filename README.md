# Peripheral Battery

Battery levels for wireless mouse, keyboard, headset & controllers, right in your
Omarchy bar. Per-device chips, low-battery notifications, click for a full list.

![bar](screenshots/bar.png)

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-peripheral-battery
```

Then add the **Peripheral Battery** widget from the bar widget picker (Hardware).

## Remove

```bash
omarchy plugin remove <you>.peripheral-battery   # TODO: confirm exact remove command
```

## Requirements

- `upower` (ships with Omarchy)
- The device must report battery to UPower. Most USB-dongle and Bluetooth
  peripherals do; some BT headsets need the experimental BlueZ battery plugin.

## Settings

| Key                 | Type        | Default | What it does                     |
|---------------------|-------------|---------|----------------------------------|
| `lowThreshold`      | integer     | 20      | % at/below which a device is "low" |
| `showLabels`        | boolean     | true    | Show the `%` text next to icons  |
| `hideLaptopBattery` | boolean     | true    | Hide the laptop's own battery    |
| `notifyOnLow`       | boolean     | true    | Desktop notification on low      |
| `deviceTypes`       | multiselect | mouse, keyboard, headset, gamepad | Which types to show |

## License

MIT — see [LICENSE](LICENSE).
