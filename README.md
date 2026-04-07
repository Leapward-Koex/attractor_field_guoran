
# Attractor Field

Attractor Field is a Flutter reimplementation of the BLE control app used by a family of glow-tube desk clocks sold under different listings and names. It targets the same clock family as the old Guoran / DCloud controller app: devices that typically advertise as `XGGF` or expose the `FFB0` / `FFF0` scan services and the `FFE0`, `FFE5`, and `FFC0` GATT services.

Example hardware:

- https://www.aliexpress.com/item/1005003380622087.html
- https://www.aliexpress.com/item/1005002651515235.html
- https://web.archive.org/web/20220520005628/https://www.aliexpress.com/item/1005003380622087.html

## What It Replaces

This project exists because the original control options are no longer good enough:

- The Android APK linked in the paper manual is gone: http://www.diym.vip/guoran.apk
- The mirrored APK on MediaFire is no longer usable on modern Android: https://www.mediafire.com/file/8c614bb9l78i0a2/guoran.apk/file
- The WeChat mini program still works for some devices, but it is unreliable and awkward on slower or pickier clocks

Attractor Field is a practical replacement rather than a pixel-perfect clone. The goal is to speak the same BLE protocol with a cleaner workflow, a modern UI, and better visibility into what the device is doing.

## How It Works

When you connect to a supported clock, the app follows the same general BLE flow as the original controller:

1. Scan for nearby devices that match the same clock family.
2. Connect and discover the required services and characteristics.
3. Enable notifications for the read and safety-key characteristics.
4. Send the safety key and cache the accepted key for future connections.
5. Request the device snapshot with `OSC`.
6. Parse the returned snapshot into app state: RGB color, six light switches, time-sync mode, alarms, scheduled power, and the `SA`-`SF` option flags.

The current implementation expects this BLE layout:

- Read service / characteristic: `FFE0` / `FFE4`
- Write service / characteristic: `FFE5` / `FFE9`
- Safety-key service / characteristics: `FFC0` / `FFC1` / `FFC2`

If a clock is slow to answer the snapshot request, the app automatically retries `OSC`, keeps a rolling debug log, and exposes a full GATT service dump for troubleshooting.

## Supported Behavior

Implemented behavior currently includes:

- Device discovery for clocks named `XGGF` or advertising `FFB0` / `FFF0`
- BLE connect, service discovery, safety-key handshake, and snapshot sync
- Device Time Sync
- Color Console
- Operating Buttons
- Alarm 1
- Alarm 2
- Scheduled Power
- Other Settings
- Debug report with service dump and recent BLE log

These features map to the clock protocol like this:

- Device Time Sync: current-time sync or manual time send
- Color Console: one `Rxxx-Gxxx-Bxxx` color command, six `S11`-`S61` light-channel toggles, and the `K01`-`K03` actions
- Operating Buttons: `K04`-`K09`
- Other Settings: `SA`-`SF` toggles for LUX Auto, 12-hour format, ambient light induction, on-time alarm, English mode, and inductive switch
- Alarm and Scheduled Power: snapshot-backed time settings for alarm 1, alarm 2, boot time, and off time

## Important Behavior Change

The main fix in this reimplementation is that it does not block every settings page behind the snapshot read.

As soon as the safety-key handshake is complete, the app enables any feature that only needs write access, even if the `OSC` snapshot is still loading in the background.

Available immediately after handshake:

- Device Time Sync
- Color Console
- Operating Buttons
- Other Settings

Still waits for the snapshot:

- Alarm 1
- Alarm 2
- Scheduled Power

This makes the app much more responsive on devices that are slow to return snapshot data and avoids the original workflow problem where controls that did not depend on snapshot data stayed locked unnecessarily.

## How to Use the App

1. Turn on Bluetooth on the device running the app.
2. Open Attractor Field. On Android, grant Bluetooth scan/connect permission when prompted.
3. Let the app scan automatically, or tap Scan.
4. Pick your clock from the discovered device list and connect.
5. Wait for the handshake to complete.
6. Use the available pages:
	- Device Time Sync to send the phone time or a manually selected time
	- Color Console to choose RGB color, toggle the six light channels, or send `K01`-`K03`
	- Operating Buttons to send `K04`-`K09`
	- Other Settings to toggle the `SA`-`SF` options
7. Wait for the snapshot to finish before editing Alarm 1, Alarm 2, or Scheduled Power.
8. If the snapshot does not arrive quickly, use Retry snapshot. The immediate-write pages remain usable while the snapshot is pending.
9. If the device does not behave like the expected clock family, open Debug and copy the report.

## Project Goal

The goal of this repository is to keep these clocks usable after the original Android app disappeared, while documenting the BLE behavior well enough that the protocol is no longer trapped inside abandoned mobile software.