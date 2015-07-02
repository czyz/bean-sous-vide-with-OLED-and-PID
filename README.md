# DIY Sous-Vide with Bean, OLED display, and PID

This is a branch of [mplewis's excellent "DIY Sous-Vide with Bean"](http://beantalk.punchthrough.com/t/sous-vide-with-bean-and-a-slow-cooker/483). I've added the following features to that project:

* OLED display (show's heating status, current temp, target temp, elapsed time). I'm using the display Mike Rankin [sold for a short while on Tindie](https://www.tindie.com/products/miker/066-oled-display-for-the-lightblue-bean/). I've incorporated [his code for the display](https://github.com/mike-rankin/PunchThrough_Bean_i2c_Oled/tree/master/Code). You may need to switch it out for other OLED displays, though according to [his post here](http://beantalk.punchthrough.com/t/tiny-0-66-oled-display-on-the-bean/505/6) it's not very different from the Microview graphics library.  
* Changed heating control from simple on-off thermostat to use [Brett Beauregard's PID controller library](http://playground.arduino.cc/Code/PIDLibrary), along with [his PIDAutotuneLibrary](http://playground.arduino.cc/Code/PIDAutotuneLibrary).
* Added a stepper control to the iOS app –the slider was a bit coarse for fine temperature control.
* iOS app and Arduino communicate temperature as float value rather than int. Unnecessary precision perhaps, but it was an interesting problem to try to solve. Ended up storing those variables on the Arduino as a union so as to access them as either floating point values or binary data, and then having to reverse their endianness before sending to iOS. For the iOS to Arduino direction I'm using Serial.parseFloat, though I think it would likely be faster to just send the bytes. Communication between the apps is a bit complex.


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


