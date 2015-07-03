# DIY Sous-Vide with Bean, OLED display, and PID


[![Sous-vide components, all together](http://zachfine.com/dropzone/im/sous-vide.jpg)](http://zachfine.com/dropzone/im/sous-vide.jpg)

*Above: The unfinished sous-vide machine with OLED display, cooking a steak while awaiting the next round of revisions*


This is a branch of [mplewis's excellent "DIY Sous-Vide with Bean"](http://beantalk.punchthrough.com/t/sous-vide-with-bean-and-a-slow-cooker/483). It's basically a mashup of that project and [Bill Earl's Sous Vide powered by Arduino project at Adafruit](https://learn.adafruit.com/sous-vide-powered-by-arduino-the-sous-viduino/the-whole-enchilada).  

This branch adds the following features:

* OLED display (show's heating status, current temp, target temp, elapsed time). I'm using the display Mike Rankin [sold for a short while on Tindie](https://www.tindie.com/products/miker/066-oled-display-for-the-lightblue-bean/). I've incorporated [his code for the display](https://github.com/mike-rankin/PunchThrough_Bean_i2c_Oled/tree/master/Code). You may need to switch it out for other OLED displays, though according to [his post here](http://beantalk.punchthrough.com/t/tiny-0-66-oled-display-on-the-bean/505/6) it's not very different from the Microview graphics library.  
* Changed heating control from simple on-off thermostat to use [Brett Beauregard's PID controller library](http://playground.arduino.cc/Code/PIDLibrary), along with [his PIDAutotuneLibrary](http://playground.arduino.cc/Code/PIDAutotuneLibrary). 
* Added a stepper control to the iOS app –the slider was a bit coarse for fine temperature control.
* iOS app and Arduino communicate temperature as float value rather than int. Unnecessary precision perhaps, but it was an interesting problem to try to solve. Ended up storing those variables on the Arduino as a union so as to access them as either floating point values or binary data, and then having to reverse their endianness before sending to iOS. For the iOS to Arduino direction I'm using Serial.parseFloat, though I think it would likely be faster to just send the bytes. Communication between the apps is a bit complex.

[![The OLED display](http://zachfine.com/dropzone/im/OLED_display.jpg)](http://zachfine.com/dropzone/im/OLED_display.jpg)

*Above: The OLED display*


I've posted [a video of the hardware side of things in action](https://vimeo.com/132490556). 

Apart from the changes to the Arduino and iOS app code and the addition of the OLED, I've implemented a few hardware bits differently:

* The bean is running off a 3.3V/5V power supply I got for a couple bucks that looks a lot like [this one](http://www.amazon.com/Breadboard-Power-Supply-Module-Solderless/dp/B00BXWV2F6).
* Rather than the PowerSwitch Tail, I'm using a very inexpensive [5V relay board](http://www.dx.com/p/arduino-5v-relay-module-blue-black-121354#.VZXQlWBU7Qc) made for arduino. I verified before use that my crock pot's power needs were under 10 amps. I've since purchased a heftier 30A relay module, but I don't think it's necessary for this particular cooker.
* The bean doesn't produce enough power to saturate the relay's coils (actually, it will work for a few minutes, but then crash if not die - that's a wall I ran into headlong). So I'd recommend having the Bean's digital pin control a transistor (I had an s9014 handy) to switch the power-supply's 5V line to the relay's signal pin. The relay board already has a diode connected between legs of the relay, so I didn't have to worry about EMF. A 220ohm resistor between the Bean's digital pin and the s9014 resistor’s base ensured that the draw on the bean wouldn’t exceed 20ma or so.
* I'm using [this high temperature submersible pump](http://www.amazon.com/gp/product/B007XHZ25G/ref=pd_lpo_sbs_dp_ss_1?pf_rd_p=1944687682&pf_rd_s=lpo-top-stripe-1&pf_rd_t=201&pf_rd_i=B004HHW0FU&pf_rd_m=ATVPDKIKX0DER&pf_rd_r=1T61Q2965DPH1W5KFHPN) to circulate water inside the cooker.

[![A screenshot of the revised app](http://zachfine.com/dropzone/im/sous-vide-screenshot.jpg)](http://zachfine.com/dropzone/im/sous-vide-screenshot.jpg)

*Above: A screenshot of the revised app*

## iOS app known bugs:

* If you happen to make setting changes via the app while the Bean is sending its status info, its setting will override your changes. Example: enable heating and sometimes the switch will toggle back to off as if by an unseen hand. Workaround: toggle the switch again. Solution: The app needs to recognize when incoming status messages will conflict with new settings and ignore them.
* Trying to use the input fields for PID will crash the app.
* The text fields only scroll out of the way of the keyboard when 'Kp' is edited, and they scroll further than necessary. Work in progress.
* A large central portion of the information display (heating status icon, text, and current temperature) are in a uiscrollview and can be swiped left and right. The plan is to add a Page Control below this view, and be able to view a temperature graph as well as a page of additional statistics. Work in progress.
* I haven't tested the app on anything but an iPhone 5S.

## Arduino app known bugs:

* Autotune hasn't been tested.
* Saving of PID values to EEPROM hasn't been tested.

## Xcode compilation difficulty || Git issue involving a missing “AppMessages.h”

I executed a few oddball steps in order to fix this issue so I could get the thing to compile. 

* In the terminal, I cd’d into the project’s “bean-sous-vide-with-OLED-and-PID” base directory.
* $ git rm Bean-iOS-OSX-SDK/ -r”
* then removed the Bean-iOS-OSX-SDK directory (used the Finder, but you could do a “rm -Rf Bean-iOS-OSX-SDK”.
* $ git submodule add https://github.com/PunchThrough/Bean-iOS-OSX-SDK.git
* $ git submodule update --init --recursive

That got the iOS API in a state in which it’d compile, which is the next step. At that point, follow the steps listed at:
http://beantalk.punchthrough.com/t/getting-started-with-the-ios-api/372

After that, you should be able to compile a version of the Sous Vide app for your iOS device or for the simulator using Xcode.

## Much more information is available at the page for [the original project](http://beantalk.punchthrough.com/t/sous-vide-with-bean-and-a-slow-cooker/483)


