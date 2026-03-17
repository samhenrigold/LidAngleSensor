# Lid Angle Sensor

Hi, I’m Sam Gold. Did you know that you have ~rights~ a lid angle sensor in your MacBook? [The ~Constitution~ human interface device utility says you do.](https://youtu.be/wqnHtGgVAUE?t=21)

This is a little utility that shows the angle from the sensor and, optionally, plays a wooden door creaking sound if you adjust it reeaaaaaal slowly.

## FAQ

**What is a lid angle sensor?**

Despite what the name would have you believe, it is a sensor that detects the angle of the lid.

**Which devices have a lid angle sensor?**

It was introduced with the 2019 16-inch MacBook Pro. If your laptop is newer, you probably have it. [People have reported](https://github.com/samhenrigold/LidAngleSensor/issues/13) that it **does not work on M1 devices**, I have not yet figured out a fix.

**My laptop should have it, why doesn't it show up?**

I've only tested this on my M4 MacBook Pro and have hard-coded it to look for a specific sensor. If that doesn't work, try running [this script](https://gist.github.com/samhenrigold/42b5a92d1ee8aaf2b840be34bff28591) and report the output in [an issue](https://github.com/samhenrigold/LidAngleSensor/issues/new/choose).

Known problematic models:

- M1 MacBook Air
- M1 MacBook Pro

**Can I use this on my iMac?**

~~Not yet tested. Feel free to slam your computer into your desk and make a PR with your results.~~

[It totally works](https://github.com/samhenrigold/LidAngleSensor/issues/33). If it doesn't work for you, try slamming your computer harder?

**Why?**

A lot of free time. I'm open to full-time work in NYC or remote. I'm a designer/design-engineer. https://samhenri.gold

**No I mean like why does my laptop need to know the exact angle of its lid?**

Oh. I don't know.

**Can I contribute?**

I guess.

**Why does it say it's by Lisa?**

I signed up for my developer account when I was a kid, used my mom's name, and now it's stuck that way forever and I can't change it. That's life.

**How come the audio feels kind of...weird?**

I'm bad at audio.

**Where did the sound effect come from?**

LEGO Batman 3: Beyond Gotham. But you knew that already.

**Can I turn off the sound?**

Yes, never click "Start Audio". But this energy isn't encouraged.

## Building

According to [this issue](https://github.com/samhenrigold/LidAngleSensor/issues/12), building requires having Xcode installed. I've only tested this on Xcode 26. YMMV.

## Using VS Code

You can use VS Code as your editor and task runner, but you still need the full `Xcode.app` toolchain installed for `xcodebuild`.

1. Install Xcode from the App Store.
2. Point the active developer directory to Xcode:

```shell
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

3. Open this folder in VS Code.
4. Run `Terminal > Run Task` and use one of the bundled tasks:
   - `Xcode: Check Toolchain`
   - `Xcode: Build Debug`
   - `Xcode: Run App`
   - `Xcode: Clean`

Build artifacts are written to `build/`, which is ignored by git.

## Installation

Via Homebrew:

```shell
brew install lidanglesensor
```

## Related projects

- [Python library that taps into this sensor](https://github.com/tcsenpai/pybooklid)
