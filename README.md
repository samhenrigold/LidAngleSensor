# Lid Angle Sensor

Hi, I’m Sam Gold. Did you know that you have ~rights~ a lid angle sensor in your MacBook? [The ~Constitution~ human interface device utility says you do.](https://youtu.be/wqnHtGgVAUE?t=21)

This is a little utility that shows the angle from the sensor and, optionally, plays a wooden door creaking sound if you adjust it reeaaaaaal slowly.

## FAQ

**What is a lid angle sensor?**

Despite what the name would have you believe, it is a sensor that detects the angle of the lid.

**Which devices have a lid angle sensor?**

It was introduced with the 2019 16-inch MacBook Pro. If your laptop is newer, you probably have it.

**Can I use this on my iMac?**

Not yet tested. Feel free to slam your computer into your desk and make a PR with your results.

**Why?**

A lot of free time. I'm open to full-time work in NYC or remote. I'm a designer/design-engineer. https://samhenri.gold

**No I mean like why does my laptop need to know the exact angle of its lid?**

Oh. I don't know.

**Can I contribute?**

I guess.

**How come the audio feels kind of...weird?**

I'm bad at audio.

**Where did the sound effect come from?**

LEGO Batman 3: Beyond Gotham. But you knew that already.

**Why mac says its monitoring the keyboard?**

<img width="500"  alt="keyboard access screenshot" src="https://github.com/user-attachments/assets/f38978b5-147e-4818-a097-3c025a3de980" />

IOHIDManagerOpen, which I use to monitor the lid angle sensor, is more commonly used by people to monitor input devices (i.e. a keyboard). It’s so low level that Apple just assumes someone is using it to drink from that event monitoring firehose ([ref](https://x.com/theapache64/status/1964449242170479097))

