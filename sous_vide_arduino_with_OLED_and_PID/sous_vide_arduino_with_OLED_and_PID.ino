//debugging
//#include <MemoryFree.h>


//sousvide stuff
#include <OneWire.h>
#include <DallasTemperature.h>

//oled stuff
#include <Wire.h>
//---------------FONT + GRAPHIC-----------------------------//
#include "Bean_i2c_OLED_data.h"
//==========================================================//

// So we can save and retrieve settings
#include <EEPROM.h>


 // PID Library
#include <PID_v1.h>
#include <PID_AutoTune_v0.h>




// OLED I2C bus address
#define OLED_address  0x3c

//sous vide stuff
// Thermometer is connected to pin 2
#define ONE_WIRE_BUS 2

// Relay signal is connected to pin 3
#define HEATER_PIN 3

// Wait 5 seconds between checking temperature
#define CONTROL_INTERVAL 10000

// Default to starting at 127 F -- lowest FDA safe temp (given long cooking time)
#define DEFAULT_TARGET_TEMP 127


// State variables
bool enabled = false;
bool heating = false;
bool autotuning = false;


typedef union {
 float floatingPoint;
 byte binary[4];
} binaryFloat;

binaryFloat currentTempF;
binaryFloat currentTempF_endianswapped;

binaryFloat targetTempF;



char heater_status[] = "--------";

// Setup a oneWire instance to communicate with OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to the Dallas Temperature library
DallasTemperature sensors(&oneWire);
DeviceAddress thermometer;

//OLED stuff
const int PWR_ON = 0;  //Using Pin 0 tp power the oleds VCC


//PID constants and EEPROM storage addresses from Bill Earl's writeup at Adafruit
//https://learn.adafruit.com/sous-vide-powered-by-arduino-the-sous-viduino/the-whole-enchilada

// ************************************************
// PID Variables and constants
// ************************************************
  
//Define Variables we'll be connecting to
double Setpoint;
double Input;
double Output;
 
volatile long onTime = 0;
 
// pid tuning parameters
binaryFloat Kp;
binaryFloat Ki;
binaryFloat Kd;
 
// EEPROM addresses for persisted data
const int SpAddress = 0;
const int KpAddress = 8;
const int KiAddress = 16;
const int KdAddress = 24;


//Specify the links and initial tuning parameters
PID myPID(&Input, &Output, &Setpoint, Kp.floatingPoint, Ki.floatingPoint, Kd.floatingPoint, DIRECT);
 
// 10 second Time Proportional Output window
int WindowSize = 10000; 
unsigned long windowStartTime;

//double onPercentage;
 
// ************************************************
// Auto Tune Variables and constants
// ************************************************
byte ATuneModeRemember=2;
 
double aTuneStep=500;
double aTuneNoise=1;
unsigned int aTuneLookBack=20;
 
 
PID_ATune aTune(&Input, &Output);

const int logInterval = 10000; // log every 10 seconds
long lastLogTime = 0;



void setup()
{
//Sousvide

    pinMode(HEATER_PIN, OUTPUT);
    digitalWrite(HEATER_PIN, 0);
    
//OLED
    pinMode(PWR_ON, OUTPUT); 
    digitalWrite(PWR_ON, HIGH); 
    delay(1000);  //Needed!
   
    // Initialize I2C and OLED Display
    Wire.begin();
    init_OLED();
    delay(1500);
    reset_display();           // Clear logo and load saved mode
    
    displayOn();

//other setup

targetTempF.floatingPoint = DEFAULT_TARGET_TEMP;
Setpoint = targetTempF.floatingPoint;


strlcpy (heater_status, "strt ser", sizeof(heater_status));
        sendStrXY(heater_status,2,4); //

    Serial.begin(57600);
    
    currentTempF.floatingPoint = 0;
    currentTempF_endianswapped.floatingPoint = 0;
        
    sensors.begin();
    
   //The following lines come from Bill Earl's Adafruit sous-vide project, with error output written to the OLED rather than LCD
   if (!sensors.getAddress(thermometer, 0)) 
   {
    strlcpy (heater_status, "NoSensor", sizeof(heater_status));
   }
   sensors.setResolution(thermometer, 12);
   sensors.setWaitForConversion(false);
 
   
strlcpy (heater_status, "load par", sizeof(heater_status));
        sendStrXY(heater_status,2,4); //
        
   // Initialize the PID and related variables
   LoadParameters();
   myPID.SetTunings(Kp.floatingPoint,Ki.floatingPoint,Kd.floatingPoint);
 
   myPID.SetSampleTime(1000);
   myPID.SetOutputLimits(0, WindowSize);
 
  // Run timer2 interrupt every 15 ms 
  TCCR2A = 0;
  TCCR2B = 1<<CS22 | 1<<CS21 | 1<<CS20;
 
  //Timer2 Overflow Interrupt Enable
  TIMSK2 |= 1<<TOIE2;
  
  //commented Off() in the loop, and just set it here.
  Off();
  heating = 0;
}

// ************************************************
// Timer Interrupt Handler
// ************************************************
SIGNAL(TIMER2_OVF_vect) 
{
     // sendStrXY(heater_status,2,4); //we don't really need to update the display status every 15ms, but might as well have it displayed once rather than scattered all over.

  if (!enabled)
  {
    digitalWrite(HEATER_PIN, LOW);  // make sure relay is off
  }
  else
  {
    DriveOutput();
  }
}

void loop()
{   
  
  //initial state, and state if heating disabled
  if (!enabled) {
    Bean.setLed(125, 125, 125);
    
    //Off();
  }
  
  
   // Prepare to transition to the RUN state
     strlcpy (heater_status, "reading ", sizeof(heater_status));
   // sendStrXY(heater_status,2,4); //debug, remove me
      
    // Blink red while grabbing temperature
    Bean.setLed(255, 0, 0);
   sensors.requestTemperatures(); // Start an asynchronous temperature reading
           
    
    currentTempF.floatingPoint = (float) sensors.getTempFByIndex(0);
    Input = currentTempF.floatingPoint;

    
    
    //OLED stuff
    
      char sz[]= "****";
      char ab[]= "****";
      uint16_t batteryV = 0;
      char tmp[5];
       
    
        //clear_display();
        sendStrXY("Cur Temp:",0,4);
        float displayTemp = currentTempF.floatingPoint; //use the thermocouple temp rather than the Bean temp

        dtostrf(displayTemp,4,3,sz);

        sendStrXY(sz,1,4);
        
        float displayTargetTemp = targetTempF.floatingPoint;
        dtostrf(displayTargetTemp,4,3,ab);
        sendStrXY(ab,5,4);
        
//        dtostrf(freeMemory(),7,0,ab);
//        dtostrf((onTime/WindowSize),4,3,ab);
//          dtostrf(windowStartTime,7,0,ab);
//          sendStrXY(ab,4,4);
        
          unsigned long t = millis()/1000; 
          int h = t/3600; //(hours)
          t = t % 3600; 
          int m = t / 60;
          int s = t % 60;
          sprintf(ab,"%02d:%02d:%02d", h, m, s);
          sendStrXY(ab,2,4);

        
        sendStrXY("Target:",4,4);
        
        //digitalWrite(PWR_ON, LOW); //Display EN Off
        //Bean.sleep(2);
    //END OLED STUFF
    
    

    // Process control loop if there are no incoming commands
    if (!Serial.available()) {
       DoControl(); 
    } else {

        // Process incoming commands from iOS app                                      and blink blue
        Bean.setLed(0, 0, 255);
        
        if (!enabled) {
        strlcpy (heater_status, ".-.-.-.-", sizeof(heater_status));
        } else {
        strlcpy (heater_status, "enabled ", sizeof(heater_status));
        }
        sendStrXY(heater_status,2,4); //


        //method to send serialized numbers borrowed from http://www.gammon.com.au/serial
        const char startOfNumberDelimiter = '<';
        const char endOfNumberDelimiter   = '>';


        byte cmd = Serial.read();
        
        static char outstr[15];

        

        if (cmd == 0x00) {
            // 0: Get status
            // Return 0x00, current temp, target temp, enabled, heating, kp, ki, kd, 0xFF
       
            Serial.write(0x00);
            
            swap_endianness(&currentTempF.binary[0], sizeof(currentTempF.binary));
            Serial.write(currentTempF.binary,sizeof(currentTempF.binary)); 
            swap_endianness(&currentTempF.binary[0], sizeof(currentTempF.binary));

            swap_endianness(&targetTempF.binary[0], sizeof(targetTempF.binary));
            Serial.write(targetTempF.binary,sizeof(targetTempF.binary));
            swap_endianness(&targetTempF.binary[0], sizeof(targetTempF.binary));

            Serial.write(enabled ? 0x01 : 0x00);
            Serial.write(heating ? 0x01 : 0x00);

            swap_endianness(&Kp.binary[0], sizeof(Kp.binary));
            Serial.write(Kp.binary,sizeof(Kp.binary));  
            swap_endianness(&Kp.binary[0], sizeof(Kp.binary));

            swap_endianness(&Ki.binary[0], sizeof(Ki.binary));
            Serial.write(Ki.binary,sizeof(Ki.binary));  
            swap_endianness(&Ki.binary[0], sizeof(Ki.binary));

            swap_endianness(&Kd.binary[0], sizeof(Kd.binary));
            Serial.write(Kd.binary,sizeof(Kd.binary));  
            swap_endianness(&Kd.binary[0], sizeof(Kd.binary));

            Serial.write(0xFF);

        } else if (cmd == 0x01) {
            // 1: Enable heater
            enabled = true;
            
            //turn the PID on
            myPID.SetMode(AUTOMATIC);  
            
            strlcpy (heater_status, "enabled ", sizeof(heater_status));
            sendStrXY(heater_status,2,4); //
//            delay(500);
            
            // Return 0x01, 0xFF
            Serial.write(0x01);
            Serial.write(0xFF);

        } else if (cmd == 0x02) {
            // 2: Disable heater
            enabled = false;

            // Return 0x02, 0xFF
            Serial.write(0x02);
            Serial.write(0xFF);

        } else if (cmd == 0x03) {
            // 3: Set target temperature
            while (!Serial.available());

            targetTempF.floatingPoint = Serial.parseFloat(); //This should stop at the first non-numeric char
            Setpoint = targetTempF.floatingPoint;


            // Return 0x03, target temp, 0xFF
            Serial.write(0x03);
            
            swap_endianness(&targetTempF.binary[0], sizeof(targetTempF.binary));
            Serial.write(targetTempF.binary,sizeof(targetTempF.binary));  
            swap_endianness(&targetTempF.binary[0], sizeof(targetTempF.binary));
            
            Serial.write(0xFF);

        } else if (cmd == 0x06) {
            //commence autotuning
            autotuning = true;
            //respond
            Serial.write(0x06);
            Serial.write(0xFF);              
           //set kp, ki, kd from ios app
          
        } else if (cmd == 0x08) {
            while (!Serial.available());

            Kp.floatingPoint = Serial.parseFloat(); //This should stop at the first non-numeric char
  
              dtostrf(Kp.floatingPoint,7, 3, outstr);
              strlcpy (heater_status, outstr, sizeof(heater_status));
              sendStrXY(heater_status,2,4); //
                         
             // Re-tune the PID
             myPID.SetTunings(Kp.floatingPoint,Ki.floatingPoint,Kd.floatingPoint);
   
             // Persist any changed parameters to EEPROM
             SaveParameters();
            
            Serial.write(0x08);
            Serial.write(0xFF);
           
        } else if (cmd == 0x09) {
            while (!Serial.available());
            
              while (!Serial.available());

            Ki.floatingPoint = Serial.parseFloat(); //This should stop at the first non-numeric char
  
            
              dtostrf(Ki.floatingPoint,7, 3, outstr);
              strlcpy (heater_status, outstr, sizeof(heater_status));
              sendStrXY(heater_status,2,4); //
                        
             // Re-tune the PID
             myPID.SetTunings(Kp.floatingPoint,Ki.floatingPoint,Kd.floatingPoint);
   
             // Persist any changed parameters to EEPROM
             SaveParameters();
             
 
            Serial.write(0x09);
            Serial.write(0xFF);
  
        } else if (cmd == 0x0A) {
            while (!Serial.available());
            
              Kd.floatingPoint = Serial.parseFloat(); //This should stop at the first non-numeric char
             
              dtostrf(Kd.floatingPoint,7, 3, outstr);
              strlcpy (heater_status, outstr, sizeof(heater_status));
              sendStrXY(heater_status,2,4); //

             // Re-tune the PID
             myPID.SetTunings(Kp.floatingPoint,Ki.floatingPoint,Kd.floatingPoint);
   
             // Persist any changed parameters to EEPROM
             SaveParameters();
            
             
            Serial.write(0x0A);
            Serial.write(0xFF);                                

        } else {
            // Flush incoming buffer
            while (Serial.available()) {
                Serial.read();
            }
        }

    }

//    Bean.setLed(0, 0, 0);


}


// ************************************************
// Initial State
// ************************************************
void Off()
{
   myPID.SetMode(MANUAL);
   heating = 0;

          // Blink dim red
        Bean.setLed(125, 0, 0);
   
   strlcpy (heater_status, "OFF     ", sizeof(heater_status));
   sendStrXY(heater_status,2,4); //

   digitalWrite(HEATER_PIN, LOW);  // make sure it is off
   windowStartTime = millis();

  
}

// ************************************************
// Execute the control loop
// ************************************************
void DoControl()
{
 
        
        // If heater is disabled, turn off heating no matter what
        if (!enabled) {
            heating = 0;
        } else {

          // Blink green
        Bean.setLed(0, 255, 0);

          heating = 1; 
        }

                  
        // Turn off LED and sleep until the next sample period
        Bean.setLed(0, 0, 0);
        
  
  if (autotuning) // run the auto-tuner
  {
     Bean.setLed(207, 255, 4); //yellow
     if (aTune.Runtime()) // returns 'true' when done
     {
        FinishAutoTune();
     }
  }
  else // Execute control algorithm
  {
     myPID.Compute();
  }
  
  // Time Proportional relay state is updated regularly via timer interrupt.
  onTime = Output;
  
  //onPercentage = Output/WindowSize; 
}


// ************************************************
// Called by ISR every 15ms to drive the output
// ************************************************
void DriveOutput()
{    
  long now = millis();

  // Set the output
  // "on time" is proportional to the PID output
  if(now - windowStartTime>WindowSize)
  { //time to shift the Relay Window
     windowStartTime += WindowSize;
  }
    
  if((onTime > 100) && (onTime > (now - windowStartTime)))
  {
    Bean.setLed(15, 15, 15);      
    digitalWrite(HEATER_PIN,heating); //changed from HIGH to use "heating" variable so enable/disable switch still can disable
  }
  else
  {
    Bean.setLed(255, 0, 255);
    digitalWrite(HEATER_PIN,LOW);
  }
}




// ************************************************
// Set OLEDStatusMessage based on the state of control
// ************************************************
void setOledMsg()
{
   if (autotuning)
   {     
        strlcpy (heater_status, "autotune", sizeof(heater_status));

//      lcd.setOledMsg(VIOLET); // Tuning Mode
   }
   else if (abs(Input - Setpoint) > 1.0)  
   {
             strlcpy (heater_status, "TOO HIGH", sizeof(heater_status));

     // lcd.setOledMsg(RED);  // High Alarm - off by more than 1 degree
   }
   else if (abs(Input - Setpoint) > 0.2)  
   {
               strlcpy (heater_status, "TOO LOW ", sizeof(heater_status));

   //   lcd.setOledMsg(YELLOW);  // Low Alarm - off by more than 0.2 degrees
   }
   else
   {
        strlcpy (heater_status, "ONTARGET", sizeof(heater_status));

      //lcd.setOledMsg(WHITE);  // We're on target!
   }
}

// ************************************************
// Start the Auto-Tuning cycle
// ************************************************

void StartAutoTune()
{
   // REmember the mode we were in
   ATuneModeRemember = myPID.GetMode();
   
   strlcpy (heater_status, "autotune", sizeof(heater_status));


   // set up the auto-tune parameters
   aTune.SetNoiseBand(aTuneNoise);
   aTune.SetOutputStep(aTuneStep);
   aTune.SetLookbackSec((int)aTuneLookBack);
   autotuning = true;
}

// ************************************************
// Return to normal control
// ************************************************
void FinishAutoTune()
{
   autotuning = false;

   // Extract the auto-tune calculated parameters
   Kp.floatingPoint = aTune.GetKp();
   Ki.floatingPoint = aTune.GetKi();
   Kd.floatingPoint = aTune.GetKd();

   // Re-tune the PID and revert to normal control mode
   myPID.SetTunings(Kp.floatingPoint,Ki.floatingPoint,Kd.floatingPoint);
   myPID.SetMode(ATuneModeRemember);
   
   // Persist any changed parameters to EEPROM
   SaveParameters();
   
            Serial.write(0x07);
            Serial.write(0xFF);  
   
}


//OLED FUNCTIONS

//==========================================================//
// Resets display depending on the actual mode.
static void reset_display(void)
{
  displayOff();
  clear_display();
  displayOn();
}

//==========================================================//
// Turns display on.
void displayOn(void)
{
    sendcommand(0xaf);        //display on
}

//==========================================================//
// Turns display off.
void displayOff(void)
{
  sendcommand(0xae);		//display off
}

//==========================================================//
// Clears the display by sendind 0 to all the screen map.
static void clear_display(void)
{
  unsigned char i,k;
  for(k=0;k<8;k++)  //8
  {	
    setXY(k,0);    
    {
      for(i=0;i<128;i++)     //was 128
      {
        SendChar(0);         //clear all COL
        //delay(10);
      }
    }
  }
}






//==========================================================//
static void printBigTime(char *string)
{

  int Y;
  int lon = strlen(string);
  if(lon == 3) {
    Y = 0;
  } else if (lon == 2) {
    Y = 3;
  } else if (lon == 1) {
    Y = 6;
  }
  
  int X = 2;
  while(*string)
  {
    printBigNumber(*string, X, Y);
    
    Y+=3;
    X=2;
    setXY(X,Y);
    *string++;
  }
}


//==========================================================//
// Prints a display big number (96 bytes) in coordinates X Y,
// being multiples of 8. This means we have 16 COLS (0-15) 
// and 8 ROWS (0-7).
static void printBigNumber(char string, int X, int Y)
{    
  setXY(X,Y);
  int salto=0;
  for(int i=0;i<96;i++)
  {
    if(string == ' ') {
      SendChar(0);
    } else 
      SendChar(pgm_read_byte(bigNumbers[string-0x30]+i));
   
    if(salto == 23) {
      salto = 0;
      X++;
      setXY(X,Y);
    } else {
      salto++;
    }
  }
}

//==========================================================//
// Actually this sends a byte, not a char to draw in the display. 
// Display's chars uses 8 byte font the small ones and 96 bytes
// for the big number font.
static void SendChar(unsigned char data) 
{ 
  Wire.beginTransmission(OLED_address); // begin transmitting
  Wire.write(0x40);//data mode
  Wire.write(data);
  Wire.endTransmission();    // stop transmitting
}

//==========================================================//
// Prints a display char (not just a byte) in coordinates X Y,
// being multiples of 8. This means we have 16 COLS (0-15) 
// and 8 ROWS (0-7).
static void sendCharXY(unsigned char data, int X, int Y)
{
  setXY(X, Y);
  Wire.beginTransmission(OLED_address); // begin transmitting
  Wire.write(0x40);//data mode
  
  for(int i=0;i<8;i++)  //8
    Wire.write(pgm_read_byte(myFont[data-0x20]+i));
    
  Wire.endTransmission();    // stop transmitting
}

//==========================================================//
// Used to send commands to the display.
static void sendcommand(unsigned char com)
{
  Wire.beginTransmission(OLED_address);     //begin transmitting
  Wire.write(0x80);                          //command mode
  Wire.write(com);
  Wire.endTransmission();                    // stop transmitting
 
}

//==========================================================//
// Set the cursor position in a 16 COL * 8 ROW map.
static void setXY(unsigned char row,unsigned char col)
{
  sendcommand(0xb0+row);                //set page address
  sendcommand(0x00+(8*col&0x0f));       //set low col address  //8
  sendcommand(0x10+((8*col>>4)&0x0f));  //set high col address  //8
  
  //Possible NEW!!
  //sendcommand((0x10|(col>>4))+0x02);
  //sendcommand((0x0f&col));
  
}


//==========================================================//
// Prints a string regardless the cursor position.
static void sendStr(unsigned char *string)
{
  unsigned char i=0;
  while(*string)
  {
    for(i=0;i<8;i++)  
    {
      SendChar(pgm_read_byte(myFont[*string-0x20]+i));
    }
    *string++;
  }
}

//==========================================================//
// Prints a string in coordinates X Y, being multiples of 8.
// This means we have 16 COLS (0-15) and 8 ROWS (0-7).
static void sendStrXY( char *string, int X, int Y)
{
  setXY(X,Y);
  unsigned char i=0;
  while(*string)
  {
    for(i=0;i<8;i++)  
    {
      SendChar(pgm_read_byte(myFont[*string-0x20]+i));  //0x20Hex=32Dec  128x64 or 64x48 48/2=24
      //SendChar(pgm_read_byte(myFont[*string-0x20]+i));
    }
    *string++;
  }
}


//==========================================================//
// Inits oled and draws logo at startup
static void init_OLED(void)
{
  sendcommand(0xae);		//display off
  sendcommand(0xa6);            //Set Normal Display (default) 
    // Adafruit Init sequence for 128x64 OLED module
    sendcommand(0xAE);             //DISPLAYOFF
    sendcommand(0xD5);            //SETDISPLAYCLOCKDIV
    sendcommand(0x80);            // the suggested ratio 0x80
    sendcommand(0xA8);            //SSD1306_SETMULTIPLEX
    sendcommand(0x2F); //--1/48 duty    //NEW!!!
    sendcommand(0xD3);            //SETDISPLAYOFFSET
    sendcommand(0x0);             //no offset
    sendcommand(0x40 | 0x0);      //SETSTARTLINE
    sendcommand(0x8D);            //CHARGEPUMP
    sendcommand(0x14);
    sendcommand(0x20);             //MEMORYMODE
    sendcommand(0x00);             //0x0 act like ks0108
    
    sendcommand(0xA0 | 0x1);      //SEGREMAP   //Rotate screen 180 deg
    //sendcommand(0xA0);
    
    sendcommand(0xC8);            //COMSCANDEC  Rotate screen 180 Deg
    //sendcommand(0xC0);
    
    sendcommand(0xDA);            //0xDA
    sendcommand(0x12);           //COMSCANDEC
    sendcommand(0x81);           //SETCONTRAS
    sendcommand(0xCF);           //
    sendcommand(0xd9);          //SETPRECHARGE 
    sendcommand(0xF1); 
    sendcommand(0xDB);        //SETVCOMDETECT                
    sendcommand(0x40);
    sendcommand(0xA4);        //DISPLAYALLON_RESUME        
    sendcommand(0xA6);        //NORMALDISPLAY             

  clear_display();
  sendcommand(0x2e);            // stop scroll
  //----------------------------REVERSE comments----------------------------//
  //  sendcommand(0xa0);		//seg re-map 0->127(default)
  //  sendcommand(0xa1);		//seg re-map 127->0
  //  sendcommand(0xc8);
  //  delay(1000);
  //----------------------------REVERSE comments----------------------------//
  sendcommand(0xa7);  //Set Inverse Display  
  // sendcommand(0xae);		//display off
  sendcommand(0x20);            //Set Memory Addressing Mode
  sendcommand(0x00);            //Set Memory Addressing Mode ab Horizontal addressing mode
  //  sendcommand(0x02);         // Set Memory Addressing Mode ab Page addressing mode(RESET)  
  
   setXY(0,0);
  
  for(int i=0;i<128*8;i++)     // show 128* 64 Logo
  {
    SendChar(pgm_read_byte(logo+i));
  }
  
  sendcommand(0xaf);		//display on
}


//Zach added this to write values to Scratch

void write_string_to_scratch(const String& inputString, const uint8_t scratchNumber) {
  int stringLength = inputString.length();

  if (stringLength>0){
    char buffer[stringLength+1];
    // Convert the string to a uint8_t array
    for ( int i=0; i<stringLength; i++ )
      {
        buffer[i] = inputString.charAt(i);
      }
  
    Bean.setScratchData( (uint8_t) scratchNumber, (const uint8_t*)buffer, stringLength);
  }

}


//Zach added this for swapping endianness before sending floats to iOS over serial

byte swap_endianness(byte *input_bytes, size_t n) {
  
    byte *bytes = input_bytes;
    size_t lo, hi;
  
    for(lo=0, hi=n-1; hi>lo; lo++, hi--)
    {
        byte tmp=bytes[lo];
        bytes[lo] = bytes[hi];
        bytes[hi] = tmp;
    }

    
//    byte converted_byte_array[sizeof(input_bytes)];
    
//    for(int i=0; i < sizeof(input_bytes); i++){
//     converted_byte_array[sizeof(input_bytes) - i - 1]=input_bytes[i]; //reverse the byte order here.
//   }
 
// return converted_byte_array;  
   
}

//And some EEPROM helper functions from Bill Earl at:
// https://learn.adafruit.com/sous-vide-powered-by-arduino-the-sous-viduino/persistent-data

//His explanation: 
//SInce EEPROM can only be written a finite number of times (typically 100,000), 
//we compare the contents before writing and only write if something has changed. 

// ************************************************
// Save any parameter changes to EEPROM
// ************************************************
void SaveParameters()
{
   if (Setpoint != EEPROM_readDouble(SpAddress))
   {
      EEPROM_writeDouble(SpAddress, Setpoint);
   }
   if (Kp.floatingPoint != EEPROM_readDouble(KpAddress))
   {
      EEPROM_writeDouble(KpAddress, Kp.floatingPoint);
   }
   if (Ki.floatingPoint != EEPROM_readDouble(KiAddress))
   {
      EEPROM_writeDouble(KiAddress, Ki.floatingPoint);
   }
   if (Kd.floatingPoint != EEPROM_readDouble(KdAddress))
   {
      EEPROM_writeDouble(KdAddress, Kd.floatingPoint);
   }
}

// ************************************************
// Load parameters from EEPROM
// ************************************************
void LoadParameters()
{
   strlcpy (heater_status, "LoadParm", sizeof(heater_status));
  // Load from EEPROM
   Setpoint = EEPROM_readDouble(SpAddress);
   Kp.floatingPoint = EEPROM_readDouble(KpAddress);
   Ki.floatingPoint = EEPROM_readDouble(KiAddress);
   Kd.floatingPoint = EEPROM_readDouble(KdAddress);
   
   // Use defaults if EEPROM values are invalid
   if (isnan(Setpoint))
   {
     Setpoint = 60;
   }
   if (isnan(Kp.floatingPoint))
   {
     Kp.floatingPoint = 500;
   }
   if (isnan(Ki.floatingPoint))
   {
     Ki.floatingPoint = 0.5;
   }
   if (isnan(Kd.floatingPoint))
   {
     Kd.floatingPoint = 0.1;
   }  
}


// ************************************************
// Write floating point values to EEPROM
// ************************************************
void EEPROM_writeDouble(int address, double value)
{
   byte* p = (byte*)(void*)&value;
   for (int i = 0; i < sizeof(value); i++)
   {
      EEPROM.write(address++, *p++);
   }
}

// ************************************************
// Read floating point values from EEPROM
// ************************************************
double EEPROM_readDouble(int address)
{
   double value = 0.0;
   byte* p = (byte*)(void*)&value;
   for (int i = 0; i < sizeof(value); i++)
   {
      *p++ = EEPROM.read(address++);
   }
   return value;
}

// report remaining free ram. From:
// https://learn.adafruit.com/memories-of-an-arduino/measuring-free-memory
//
//int freeRam () 
//{
//  extern int __heap_start, *__brkval; 
//  int v; 
//  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 
//}

