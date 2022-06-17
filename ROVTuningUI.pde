import java.awt.Frame;
import java.awt.BorderLayout;
import javax.swing.JOptionPane;
import controlP5.*;
import processing.serial.*;

import java.util.Date;
import java.text.SimpleDateFormat;

// Datalogger
PrintWriter datalog;

// Screen dimensions
final int screenWidth = 1600;
final int screenHeight = 900;

// Color palette
final color foregroundColor = color(255, 255, 255);
final color gaugeColor = color(0, 200, 20);
final color backgroundColor = color(10, 20, 30);
final color controlBackgroundColor = color(20, 30, 40);

CColor redButtonColor = new CColor();
CColor greenButtonColor = new CColor();

// Image objects
PImage logo;
PImage sub;

// Fonts
PFont titleFont;
PFont sectionFont;
PFont itemFont;

ControlFont smallControlFont;
ControlFont largeControlFont;

// Telemetry values
float yaw;
float pitch;
float roll;
float depth;

int thrustFL = 1500;
int thrustFR = 1500;
int thrustML = 1500;
int thrustMR = 1500;
int thrustRL = 1500;
int thrustRR = 1500;

// ControlP5 objects
ControlP5 cp5;

Accordion gains;

Slider yawP;
Slider yawI;
Slider yawD;
Slider yawAntiwindup;
Toggle yawEnabled;

Slider pitchP;
Slider pitchI;
Slider pitchD;
Slider pitchAntiwindup;
Toggle pitchEnabled;

Slider rollP;
Slider rollI;
Slider rollD;
Slider rollAntiwindup;
Toggle rollEnabled;

Slider depthP;
Slider depthI;
Slider depthD;
Slider depthAntiwindup;
Toggle depthEnabled;

Slider2D pitchRollSetpoint;
Slider yawSetpoint;
Slider depthSetpoint;

Textarea conArea;

long lastSetpointUpdate = 0;
int setpointUpdateDelay = 1000 / 5; // 5Hz

// Storage objects
Textfield fieldYawP;
float storedYawP;
Textfield fieldYawI;
float storedYawI;
Textfield fieldYawD;
float storedYawD;
Textfield fieldYawA;
float storedYawA;

Textfield fieldPitchP;
float storedPitchP;
Textfield fieldPitchI;
float storedPitchI;
Textfield fieldPitchD;
float storedPitchD;
Textfield fieldPitchA;
float storedPitchA;

Textfield fieldRollP;
float storedRollP;
Textfield fieldRollI;
float storedRollI;
Textfield fieldRollD;
float storedRollD;
Textfield fieldRollA;
float storedRollA;

Textfield fieldDepthP;
float storedDepthP;
Textfield fieldDepthI;
float storedDepthI;
Textfield fieldDepthD;
float storedDepthD;
Textfield fieldDepthA;
float storedDepthA;

// Graph objects
float[] timeValues;

float[] yawValues;
Graph yawGraph;

float[] pitchValues;
Graph pitchGraph;

float[] rollValues;
Graph rollGraph;

float[] depthValues;
Graph depthGraph;

long lastGraphUpdate = 0;
int graphUpdateDelay = 1000 / 20; // 20Hz graph update

// State objects
boolean armed = false;

// Serial objects
String COMt = "N/A";
String COMx = "N/A";
Serial port;
boolean connected = false;

boolean notConnected()
{
  if(!connected) JOptionPane.showMessageDialog(null, "Not connected to a COM port");
  return !connected;
}

void serialSelect()
{
  COMt = COMx;
  if(port != null) port.stop();
  try {
    String[] prePorts = Serial.list();
    String[] finPorts = new String[] {};
    
    for(int i = 0; i < prePorts.length; i++)
    {
      if(match(prePorts[i], "/dev/ttyS") == null) // Don't include tty, might want to change this later
      {
        finPorts = append(finPorts, prePorts[i]);
      }
    }
    
    COMx = (String) JOptionPane.showInputDialog(null, 
    "Select COM port", 
    "Select port", 
    JOptionPane.QUESTION_MESSAGE, 
    null, 
    finPorts, 
    "Spoof");

    if (COMx == null || COMx.isEmpty()) COMx = COMt;
    
    // if(COMx != "N/A")
    // {
    //   port = new Serial(this, COMx, 115200); // change baud rate to your liking
    //   port.bufferUntil('\n'); // buffer until CR/LF appears, but not required..
    // }
    
    //nextUpdateMillis = millis();
  }
  catch (Exception e)
  {
    JOptionPane.showMessageDialog(null, "COM port " + COMx + " is not available (maybe in use by another program)");
    COMx = "N/A";
  }
}

void connect()
{
  if(connected) return;

  if(COMx != "N/A")
  {
    try
    {
      port = new Serial(this, COMx, 57600); // change baud rate to your liking
      port.clear();
      port.bufferUntil('\n'); // buffer until CR/LF appears, but not required..

      lastGraphUpdate = millis();

      String timestamp = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss").format(new Date());
      datalog = createWriter(COMx + "_" + timestamp + ".dat");
    }
    catch (Exception e)
    {
      JOptionPane.showMessageDialog(null, "COM port " + COMx + " is not available (maybe in use by another program)");
      COMx = "N/A";
    }
  }
  else
  {
    JOptionPane.showMessageDialog(null, "No COM port selected");
  }
}

void disconnect()
{
  if(notConnected()) return;
  
  port.stop();
  connected = false;

  try
  {
    datalog.flush();
    datalog.close();
  }
  catch (Exception e)
  {
    return;
  }

  println("Disconnected");
}

void setup()
{
  logo = loadImage("./img/logo.png");
  //sub = loadImage("./img/sub.png");
  sub = loadImage("./img/sub_real.png");
  
  titleFont = loadFont("./fonts/CascadiaCode60.vlw");
  sectionFont = loadFont("./fonts/CascadiaCode20.vlw");
  itemFont = loadFont("./fonts/CascadiaCode12.vlw");

  //smallControlFont = new ControlFont();
  largeControlFont = new ControlFont(itemFont);
  
  surface.setTitle("AUVCalStateLA Tuning GUI");
  surface.setResizable(false);
  surface.setLocation(50, 50);

  redButtonColor.setActive(color(255, 0, 0));
  redButtonColor.setForeground(color(224, 0, 0));
  redButtonColor.setBackground(color(164, 0, 0));

  greenButtonColor.setActive(color(0, 255, 0));
  greenButtonColor.setForeground(color(0, 224, 0));
  greenButtonColor.setBackground(color(0, 164, 0));

  timeValues = new float[(5 * 20) + 1];
  yawValues = new float[timeValues.length];
  pitchValues = new float[timeValues.length];
  rollValues = new float[timeValues.length];
  depthValues = new float[timeValues.length];
  for(int t = 0; t <= 5 * 20; t++)
  {
    timeValues[t] = (float)t / 20;

    yawValues[t] = 0;
    pitchValues[t] = 0;
    rollValues[t] = 0;
    depthValues[t] = 0;
  }
  
  gui();
}

void settings()
{
  smooth(2);
  size(screenWidth, screenHeight);
}

int yprPMin = 0;
int yprPMax = 20;
int yprIMin = 0;
int yprIMax = 10;
int yprDMin = 0;
int yprDMax = 3;

int dPMin = 0;
int dPMax = 300;
int dIMin = 0;
int dIMax = 100;
int dDMin = 0;
int dDMax = 300;

int antiwindMin = 0;
int antiwindMax = 50;

void gui()
{
  cp5 = new ControlP5(this);
              
  // Yaw controller
  Group yawGains = cp5.addGroup("yawGains")
                      .setBackgroundColor(controlBackgroundColor)
                      .setBackgroundHeight(160)
                      .setLabel("Yaw");
                      
  yawP = cp5.addSlider("yawP")
            .setBroadcast(false)
            .setPosition(10, 10)
            .setSize(170, 20)
            .setRange(yprPMin, yprPMax)
            .setValue(0)
            .setLabel("P")
            .moveTo(yawGains);
              
  yawI = cp5.addSlider("yawI")
            .setBroadcast(false)
            .setPosition(10, 30)
            .setSize(170, 20)
            .setRange(yprIMin, yprIMax)
            .setValue(0)
            .setLabel("I")
            .moveTo(yawGains);
              
  yawD = cp5.addSlider("yawD")
            .setBroadcast(false)
            .setPosition(10, 50)
            .setSize(170, 20)
            .setRange(yprDMin, yprDMax)
            .setValue(0)
            .setLabel("D")
            .moveTo(yawGains);

  yawAntiwindup = cp5.addSlider("yawAntiwindup")
                     .setBroadcast(false)
                     .setPosition(10, 70)
                     .setSize(125, 20)
                     .setRange(antiwindMin, antiwindMax)
                     .setValue(0)
                     .setLabel("Anti-Windup")
                     .moveTo(yawGains);

  yawEnabled = cp5.addToggle("yawEnabled")
                  .setBroadcast(false)
                  .setPosition(20, 110)
                  .setSize(160, 20)
                  .setState(false)
                  .setLabel("Enabled")
                  .moveTo(yawGains);
  yawEnabled.getCaptionLabel().align(CENTER, CENTER);
              
  cp5.addButton("yawSend")
     .setPosition(20, 130)
     .setSize(160, 20)
     .setLabel("Send")
     .moveTo(yawGains);
  
  // Pitch controller
  Group pitchGains = cp5.addGroup("pitchGains")
                        .setBackgroundColor(controlBackgroundColor)
                        .setBackgroundHeight(160)
                        .setLabel("Pitch");
                      
  pitchP = cp5.addSlider("pitchP")
              .setBroadcast(false)
              .setPosition(10, 10)
              .setSize(170, 20)
              .setRange(yprPMin, yprPMax)
              .setValue(0)
              .setLabel("P")
              .moveTo(pitchGains);
              
  pitchI = cp5.addSlider("pitchI")
              .setBroadcast(false)
              .setPosition(10, 30)
              .setSize(170, 20)
              .setRange(yprIMin, yprIMax)
              .setValue(0)
              .setLabel("I")
              .moveTo(pitchGains);
              
  pitchD = cp5.addSlider("pitchD")
              .setBroadcast(false)
              .setPosition(10, 50)
              .setSize(170, 20)
              .setRange(yprDMin, yprDMax)
              .setValue(0)
              .setLabel("D")
              .moveTo(pitchGains);

  pitchAntiwindup = cp5.addSlider("pitchAntiwindup")
                     .setBroadcast(false)
                     .setPosition(10, 70)
                     .setSize(125, 20)
                     .setRange(antiwindMin, antiwindMax)
                     .setValue(0)
                     .setLabel("Anti-Windup")
                     .moveTo(pitchGains);

  pitchEnabled = cp5.addToggle("pitchEnabled")
                    .setBroadcast(false)
                    .setPosition(20, 110)
                    .setSize(160, 20)
                    .setState(false)
                    .setLabel("Enabled")
                    .moveTo(pitchGains);
  pitchEnabled.getCaptionLabel().align(CENTER, CENTER);
              
  cp5.addButton("pitchSend")
     .setPosition(20, 130)
     .setSize(160, 20)
     .setLabel("Send")
     .moveTo(pitchGains);
     
  // Roll controller
  Group rollGains = cp5.addGroup("rollGains")
                       .setBackgroundColor(controlBackgroundColor)
                       .setBackgroundHeight(160)
                       .setLabel("Roll");
  
  rollP = cp5.addSlider("rollP")
             .setBroadcast(false)
             .setPosition(10, 10)
             .setSize(170, 20)
             .setRange(yprPMin, yprPMax)
             .setValue(0)
             .setLabel("P")
             .moveTo(rollGains);
  
  rollI = cp5.addSlider("rollI")
             .setBroadcast(false)
             .setPosition(10, 30)
             .setSize(170, 20)
             .setRange(yprIMin, yprIMax)
             .setValue(0)
             .setLabel("I")
             .moveTo(rollGains);
  
  rollD = cp5.addSlider("rollD")
             .setBroadcast(false)
             .setPosition(10, 50)
             .setSize(170, 20)
             .setRange(yprDMin, yprDMax)
             .setValue(0)
             .setLabel("D")
             .moveTo(rollGains);

  rollAntiwindup = cp5.addSlider("rollAntiwindup")
                     .setBroadcast(false)
                     .setPosition(10, 70)
                     .setSize(125, 20)
                     .setRange(antiwindMin, antiwindMax)
                     .setValue(0)
                     .setLabel("Anti-Windup")
                     .moveTo(rollGains);

  rollEnabled = cp5.addToggle("rollEnabled")
                   .setBroadcast(false)
                   .setPosition(20, 110)
                   .setSize(160, 20)
                   .setState(false)
                   .setLabel("Enabled")
                   .moveTo(rollGains);
  rollEnabled.getCaptionLabel().align(CENTER, CENTER);
  
  cp5.addButton("rollSend")
     .setPosition(20, 130)
     .setSize(160, 20)
     .setLabel("Send")
     .moveTo(rollGains);
     
  // Altitude controller
  Group depthGains = cp5.addGroup("depthGains")
                      .setBackgroundColor(controlBackgroundColor)
                      .setBackgroundHeight(160)
                      .setLabel("Depth");
  
  depthP = cp5.addSlider("depthP")
              .setBroadcast(false)
              .setPosition(10, 10)
              .setSize(170, 20)
              .setRange(dPMin, dPMax)
              .setValue(0)
              .setLabel("P")
              .moveTo(depthGains);
  
  depthI = cp5.addSlider("depthI")
              .setBroadcast(false)
              .setPosition(10, 30)
              .setSize(170, 20)
              .setRange(dIMin, dIMax)
              .setValue(0)
              .setLabel("I")
              .moveTo(depthGains);
  
  depthD = cp5.addSlider("depthD")
              .setBroadcast(false)
              .setPosition(10, 50)
              .setSize(170, 20)
              .setRange(dDMin, dDMax)
              .setValue(0)
              .setLabel("D")
              .moveTo(depthGains);

  depthAntiwindup = cp5.addSlider("depthAntiwindup")
                     .setBroadcast(false)
                     .setPosition(10, 70)
                     .setSize(125, 20)
                     .setRange(antiwindMin, antiwindMax)
                     .setValue(0)
                     .setLabel("Anti-Windup")
                     .moveTo(depthGains);

  depthEnabled = cp5.addToggle("depthEnabled")
                    .setBroadcast(false)
                    .setPosition(20, 110)
                    .setSize(160, 20)
                    .setState(false)
                    .setLabel("Enabled")
                    .moveTo(depthGains);
  depthEnabled.getCaptionLabel().align(CENTER, CENTER);
  
  cp5.addButton("depthSend")
     .setPosition(20, 130)
     .setSize(160, 20)
     .setLabel("Send")
     .moveTo(depthGains);
     
  // Gains accordion
  gains = cp5.addAccordion("gains")
             .setPosition(10, 160)
             .setWidth(200)
             .addItem(yawGains)
             .addItem(pitchGains)
             .addItem(rollGains)
             .addItem(depthGains);
             
  // All send button
  cp5.addButton("allSend")
     .setPosition(10, 380)
     .setSize(200, 20)
     .setLabel("Send All");

  // Stored gains fields
  cp5.addButton("saveGains")
      .setPosition(10, 450)
      .setSize(100, 20)
      .setLabel("Save Gains");

  cp5.addButton("loadGains")
      .setPosition(110, 450)
      .setSize(100, 20)
      .setLabel("Load Gains");
             
  gains.open(0);

  // Controller setpoints
  CallbackListener setpointSender = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      setpointSend();
    }
  };

  pitchRollSetpoint = cp5.addSlider2D("pitchRollSetpoint")
                         .setBroadcast(false)
                         .setPosition(230, 160)
                         .setSize(200, 200)
                         .setMinMax(-45, 45, 45, -45)
                         .setValue(0, 0)
                         .setLabel("Pitch/Roll");
  pitchRollSetpoint.onRelease(setpointSender);

  yawSetpoint = cp5.addSlider("yawSetpoint")
                   .setBroadcast(false)
                   .setPosition(230, 380)
                   .setSize(200, 20)
                   .setRange(-180, 180)
                   .setValue(0)
                   .setLabel("Yaw")
                   .setSliderMode(Slider.FLEXIBLE);
  yawSetpoint.onRelease(setpointSender);

  depthSetpoint = cp5.addSlider("depthSetpoint")
                     .setBroadcast(false)
                     .setPosition(450, 160)
                     .setSize(20, 200)
                     .setRange(5, 0)
                     .setValue(0)
                     .setLabel("Depth")
                     .setSliderMode(Slider.FLEXIBLE);
  depthSetpoint.onRelease(setpointSender);

  // Vehicle control buttons
  cp5.addButton("serialSelect")
     .setPosition(10, 800)
     .setSize(180, 90)
     .setLabel("Choose Serial Port")
     .getCaptionLabel().setFont(largeControlFont);

  cp5.addButton("connect")
      .setPosition(210, 800)
      .setSize(180, 90)
      .setLabel("Connect")
      .setColor(greenButtonColor)
      .getCaptionLabel().setFont(largeControlFont);

  cp5.addButton("disconnect")
      .setPosition(410, 800)
      .setSize(180, 90)
      .setLabel("Disconnect")
      .setColor(redButtonColor)
      .getCaptionLabel().setFont(largeControlFont);

  cp5.addButton("disarm")
      .setPosition(610, 800)
      .setSize(380, 90)
      .setLabel("Disarm")
      .setColor(redButtonColor)
     .getCaptionLabel().setFont(largeControlFont);

  cp5.addButton("arm")
      .setPosition(1010, 800)
      .setSize(180, 90)
      .setLabel("Arm")
      .setColor(greenButtonColor)
      .getCaptionLabel().setFont(largeControlFont);

  cp5.addButton("eepromSave")
     .setPosition(1210, 800)
     .setSize(180, 90)
     .setLabel("Save Gains to EEPROM")
     .getCaptionLabel().setFont(largeControlFont);

  cp5.addButton("eepromLoad")
      .setPosition(1410, 800)
      .setSize(180, 90)
      .setLabel("Load Gains from EEPROM")
     .getCaptionLabel().setFont(largeControlFont);

  conArea = cp5.addTextarea("conArea")
               .setPosition(230, 450)
               .setSize(240, 300)
               .setLineHeight(12)
               .setColorBackground(controlBackgroundColor)
               .setColorForeground(foregroundColor)
               .scroll(1)
               .hideScrollbar();
  cp5.addConsole(conArea);

  // Stored gains textboxes
  fieldYawP = cp5.addTextfield("storedYawP")
                 .setPosition(40, 500)
                 .setSize(60, 20)
                 .setLabel("");
  fieldYawI = cp5.addTextfield("storedYawI")
                 .setPosition(40, 520)
                 .setSize(60, 20)
                 .setLabel("");
  fieldYawD = cp5.addTextfield("storedYawD")
                 .setPosition(40, 540)
                 .setSize(60, 20)
                 .setLabel("");
  fieldYawA = cp5.addTextfield("storedYawA")
                 .setPosition(40, 560)
                 .setSize(60, 20)
                 .setLabel("");

  fieldPitchP = cp5.addTextfield("storedPitchP")
                 .setPosition(40, 630)
                 .setSize(60, 20)
                 .setLabel("");
  fieldPitchI = cp5.addTextfield("storedPitchI")
                 .setPosition(40, 650)
                 .setSize(60, 20)
                 .setLabel("");
  fieldPitchD = cp5.addTextfield("storedPitchD")
                 .setPosition(40, 670)
                 .setSize(60, 20)
                 .setLabel("");
  fieldPitchA = cp5.addTextfield("storedPitchA")
                 .setPosition(40, 690)
                 .setSize(60, 20)
                 .setLabel("");

  fieldRollP = cp5.addTextfield("storedRollP")
                 .setPosition(140, 500)
                 .setSize(60, 20)
                 .setLabel("");
  fieldRollI = cp5.addTextfield("storedRollI")
                 .setPosition(140, 520)
                 .setSize(60, 20)
                 .setLabel("");
  fieldRollD = cp5.addTextfield("storedRollD")
                 .setPosition(140, 540)
                 .setSize(60, 20)
                 .setLabel("");
  fieldRollA = cp5.addTextfield("storedRollA")
                 .setPosition(140, 560)
                 .setSize(60, 20)
                 .setLabel("");

  fieldDepthP = cp5.addTextfield("storedDepthP")
                 .setPosition(140, 630)
                 .setSize(60, 20)
                 .setLabel("");
  fieldDepthI = cp5.addTextfield("storedDepthI")
                 .setPosition(140, 650)
                 .setSize(60, 20)
                 .setLabel("");
  fieldDepthD = cp5.addTextfield("storedDepthD")
                 .setPosition(140, 670)
                 .setSize(60, 20)
                 .setLabel("");
  fieldDepthA = cp5.addTextfield("storedDepthA")
                 .setPosition(140, 690)
                 .setSize(60, 20)
                 .setLabel("");


  cp5.setAutoDraw(false);

  // Add graphs
  yawGraph = new Graph(1380, 40, 200, 120, color(255, 0, 0));
  yawGraph.Title = "";
  yawGraph.xLabel = "";
  yawGraph.yLabel = "";
  yawGraph.xMax = 0;
  yawGraph.xMin = -5;
  yawGraph.yMax = 180;
  yawGraph.yMin = -180;
  yawGraph.StrokeColor = foregroundColor;
  
  pitchGraph = new Graph(1380, 235, 200, 120, color(255, 0, 0));
  pitchGraph.Title = "";
  pitchGraph.xLabel = "";
  pitchGraph.yLabel = "";
  pitchGraph.xMax = 0;
  pitchGraph.xMin = -5;
  pitchGraph.yMax = 45;
  pitchGraph.yMin = -45;
  pitchGraph.StrokeColor = foregroundColor;

  rollGraph = new Graph(1380, 430, 200, 120, color(255, 0, 0));
  rollGraph.Title = "";
  rollGraph.xLabel = "";
  rollGraph.yLabel = "";
  rollGraph.xMax = 0;
  rollGraph.xMin = -5;
  rollGraph.yMax = 45;
  rollGraph.yMin = -45;
  rollGraph.StrokeColor = foregroundColor;

  depthGraph = new Graph(1380, 625, 200, 120, color(255, 0, 0));
  depthGraph.Title = "";
  depthGraph.xLabel = "";
  depthGraph.yLabel = "";
  depthGraph.xMax = 0;
  depthGraph.xMin = -5;
  depthGraph.yMax = 0;
  depthGraph.yMin = 2;
  depthGraph.StrokeColor = foregroundColor;
}

void update()
{
  long loopTime = millis();

  if(connected && loopTime > lastGraphUpdate + graphUpdateDelay)
  {
    // Update graphs
    for(int i = 1; i < timeValues.length; i++)
    {
      yawValues[i - 1] = yawValues[i];
      pitchValues[i - 1] = pitchValues[i];
      rollValues[i - 1] = rollValues[i];
      depthValues[i - 1] = depthValues[i];
    }

    yawValues[timeValues.length - 1] = yaw;
    pitchValues[timeValues.length - 1] = pitch;
    rollValues[timeValues.length - 1] = roll;
    depthValues[timeValues.length - 1] = depth;

    lastGraphUpdate += graphUpdateDelay;
  }
}

void serialEvent(Serial p)
{
  try
  {
    // Buffer has reached linefeed, process incoming data
    String s = p.readStringUntil('\n');
    if(s == null) return;
    s = s.trim();

    if(!connected && s.length() > 0)
    {
      if(s.charAt(0) == '/' && s.charAt(s.length() - 1) == '/')
      {
        if(s.length() > 1 && s.charAt(1) == 'I')
        {
          connected = true;
        }
      }
    }
    else if(connected && s.length() > 0)
    {
      datalog.println(s);

      if(s.charAt(0) == '/' && s.charAt(s.length() - 1) == '/')
      {
        // Incoming data, parse but do not display
        String[] t;
        switch(s.charAt(1))
        {
          case 'A':
            armed = true;
            println(s);
            break;
          case 'F':
            armed = false;
            println(s);
            break;
          case 'T':
            // String is telemetry, display
            t = split(s.substring(2, s.length() - 1), ',');
            
            yaw = float(t[0]);
            if(yaw > 180) yaw -= 360;
            pitch = float(t[1]);
            roll = float(t[2]);
            depth = float(t[3]);

            thrustFL = int(t[4]);
            thrustML = int(t[5]);
            thrustRL = int(t[6]);
            thrustFR = int(t[7]);
            thrustMR = int(t[8]);
            thrustRR = int(t[9]);
            break;
          case 'Y':
            println(s);

            if(s.charAt(2) == 'D')
            {
              yawP.setValue(0);
              yawI.setValue(0);
              yawD.setValue(0);
              yawAntiwindup.setValue(0);
              yawEnabled.setState(false);
            }
            else
            {
              t = split(s.substring(2, s.length() - 1), ',');

              yawP.setValue(float(t[0]) / 100);
              yawI.setValue(float(t[1]) / 100);
              yawD.setValue(float(t[2]) / 100);
              yawAntiwindup.setValue(float(t[3]) / 100);

              yawEnabled.setState(true);
            }

            break;
          case 'P':
            println(s);

            if(s.charAt(2) == 'D')
            {
              pitchP.setValue(0);
              pitchI.setValue(0);
              pitchD.setValue(0);
              pitchAntiwindup.setValue(0);
              pitchEnabled.setState(false);
            }
            else
            {
              t = split(s.substring(2, s.length() - 1), ',');

              pitchP.setValue(float(t[0]) / 100);
              pitchI.setValue(float(t[1]) / 100);
              pitchD.setValue(float(t[2]) / 100);
              pitchAntiwindup.setValue(float(t[3]) / 100);

              pitchEnabled.setState(true);
            }
            
            break;
          case 'R':
            println(s);

            if(s.charAt(2) == 'D')
            {
              rollP.setValue(0);
              rollI.setValue(0);
              rollD.setValue(0);
              rollAntiwindup.setValue(0);
              rollEnabled.setState(false);
            }
            else
            {
              t = split(s.substring(2, s.length() - 1), ',');

              rollP.setValue(float(t[0]) / 100);
              rollI.setValue(float(t[1]) / 100);
              rollD.setValue(float(t[2]) / 100);
              rollAntiwindup.setValue(float(t[3]) / 100);

              rollEnabled.setState(true);
            }
            
            break;
          case 'D':
            println(s);

            if(s.charAt(2) == 'D')
            {
              depthP.setValue(0);
              depthI.setValue(0);
              depthD.setValue(0);
              depthAntiwindup.setValue(0);
              depthEnabled.setState(false);
            }
            else
            {
              t = split(s.substring(2, s.length() - 1), ',');

              depthP.setValue(float(t[0]) / 100);
              depthI.setValue(float(t[1]) / 100);
              depthD.setValue(float(t[2]) / 100);
              depthAntiwindup.setValue(float(t[3]) / 100);
              
              depthEnabled.setState(true);
            }
            
            break;
        }
      }
      else if (s.charAt(0) == '/' || s.charAt(s.length() - 1) == '/')
      {
        println("Discarding partial telemetry string: " + s);
      }
      else
      {
        // Incoming message, display
        println(s);
      }
    }
  }
  catch (Exception e)
  {
    e.printStackTrace();
  }
}

void draw()
{
  update();
  
  background(backgroundColor);
  imageMode(CORNER);
  image(logo, 10, 0, 120, 120);
  
  fill(foregroundColor);
  noStroke();
  textFont(titleFont);
  textAlign(LEFT, CENTER);
  text("AUVCalStateLA", 140, 60);
  
  textFont(sectionFont);
  textAlign(CENTER, BOTTOM);
  text("Gains", 110, 150);
  text("Stored Gains", 110, 440);
  text("Setpoints", 350, 150);
  text("Console", 350, 440);

  {
    textFont(itemFont);
    textAlign(CENTER, BOTTOM);
    
    text("Yaw", 60, 490);
    text("Pitch", 60, 620);
    text("Roll", 160, 490);
    text("Depth", 160, 620);

    textAlign(RIGHT, CENTER);

    text("P:", 30, 510);
    text("I:", 30, 530);
    text("D:", 30, 550);
    text("A:", 30, 570);

    text("P:", 30, 640);
    text("I:", 30, 660);
    text("D:", 30, 680);
    text("A:", 30, 700);

    text("P:", 130, 510);
    text("I:", 130, 530);
    text("D:", 130, 550);
    text("A:", 130, 570);

    text("P:", 130, 640);
    text("I:", 130, 660);
    text("D:", 130, 680);
    text("A:", 130, 700);
  }

  cp5.draw();

  // Draw thruster graphic
  imageMode(CENTER);
  image(sub, 900, 460, 500, ((float)sub.height / sub.width) * 500);

  // Draw thruster bars
  fill(gaugeColor);
  noStroke();
  rect(550, 255, 50, (float)(thrustFL - 1500) / 500 * -75);
  rect(550, 460, 50, (float)(thrustML - 1500) / 500 * -75);
  rect(550, 665, 50, (float)(thrustRL - 1500) / 500 * -75);
  rect(1200, 255, 50, (float)(thrustFR - 1500) / 500 * -75);
  rect(1200, 460, 50, (float)(thrustMR - 1500) / 500 * -75);
  rect(1200, 665, 50, (float)(thrustRR - 1500) / 500 * -75);

  // Draw thruster boxes
  noFill();
  stroke(foregroundColor);
  strokeWeight(2);
  rect(550, 180, 50, 150);
  rect(550, 385, 50, 150);
  rect(550, 590, 50, 150);
  rect(1200, 180, 50, 150);
  rect(1200, 385, 50, 150);
  rect(1200, 590, 50, 150);

  strokeWeight(1);
  line(550, 255, 600, 255);
  line(550, 460, 600, 460);
  line(550, 665, 600, 665);
  line(1200, 255, 1250, 255);
  line(1200, 460, 1250, 460);
  line(1200, 665, 1250, 665);

  // Draw thruster values
  fill(foregroundColor);
  noStroke();
  textAlign(CENTER, TOP);
  textFont(itemFont);
  text(thrustFL, 575, 335);
  text(thrustML, 575, 540);
  text(thrustRL, 575, 745);
  text(thrustFR, 1225, 335);
  text(thrustMR, 1225, 540);
  text(thrustRR, 1225, 745);

  // Draw graph borders
  noStroke();
  fill(controlBackgroundColor);
  rect(1320, 0, 280, 780);
  stroke(foregroundColor);

  // Draw graph titles
  noStroke();
  fill(foregroundColor);
  textFont(sectionFont);
  textAlign(CENTER, BOTTOM);
  text("Yaw", 1460, 30);
  text("Pitch", 1460, 225);
  text("Roll", 1460, 420);
  text("Depth", 1460, 615);

  // Draw graphs
  yawGraph.DrawAxis();
  pitchGraph.DrawAxis();
  rollGraph.DrawAxis();
  depthGraph.DrawAxis();

  yawGraph.LineGraph(timeValues, yawValues);
  pitchGraph.LineGraph(timeValues, pitchValues);
  rollGraph.LineGraph(timeValues, rollValues);
  depthGraph.LineGraph(timeValues, depthValues);

  // Draw extra telemetry
  fill(foregroundColor);
  noStroke();
  textFont(titleFont);

  if(armed)
  {
    textAlign(CENTER, BOTTOM);
    text("ARMED", 900, 300);
  }
  else
  {
    textAlign(CENTER, TOP);
    text("SAFE", 900, 650);
  }

  // Draw serial port 
  fill(foregroundColor);
  noStroke();
  textFont(sectionFont);
  textAlign(CENTER, BOTTOM);
  text("Selected: " + COMx, 100, 790);

  if(connected)
  {
    text("Connected", 300, 790);
  }
}

void yawSend()
{
  if(notConnected()) return;

  if(yawEnabled.getState())
  {
    port.write("Y" + round(yawP.getValue() * 100) +
               "," + round(yawI.getValue() * 100) +
               "," + round(yawD.getValue() * 100) +
               "," + round(yawAntiwindup.getValue() * 100) +
               "\n");
  }
  else
  {
    port.write("Y0,0,0,0\n");
  }
}

void pitchSend()
{
  if(notConnected()) return;

  if(pitchEnabled.getState())
  {
    port.write("P" + round(pitchP.getValue() * 100) +
               "," + round(pitchI.getValue() * 100) +
               "," + round(pitchD.getValue() * 100) +
               "," + round(pitchAntiwindup.getValue() * 100) +
               "\n");
  }
  else
  {
    port.write("P0,0,0,0\n");
  }
}

void rollSend()
{
  if(notConnected()) return;

  if(rollEnabled.getState())
  {
    port.write("R" + round(rollP.getValue() * 100) +
               "," + round(rollI.getValue() * 100) +
               "," + round(rollD.getValue() * 100) +
               "," + round(rollAntiwindup.getValue() * 100) +
               "\n");
  }
  else
  {
    port.write("R0,0,0,0\n");
  }
}

void depthSend()
{
  if(notConnected()) return;

  if(depthEnabled.getState())
  {
    port.write("D" + round(depthP.getValue() * 100) +
               "," + round(depthI.getValue() * 100) +
               "," + round(depthD.getValue() * 100) +
               "," + round(depthAntiwindup.getValue() * 100) +
               "\n");
  }
  else
  {
    port.write("D0,0,0,0\n");
  }
}

void allSend()
{
  if(notConnected()) return;

  yawSend();
  pitchSend();
  rollSend();
  depthSend();
}

void setpointSend()
{
  if(notConnected()) return;

  float yawSetVal = yawSetpoint.getValue();
  if(yawSetVal < 0) yawSetVal += 360;

  // Make sure we have latest value
  port.write("E" + round(yawSetVal * 100) +
             "," + round(pitchRollSetpoint.getArrayValue()[1] * 100) +
             "," + round(pitchRollSetpoint.getArrayValue()[0] * 100) +
             "," + round(depthSetpoint.getValue() * 100) +
             "\n");
}

void saveGains()
{
  storedYawP = yawP.getValue();
  fieldYawP.setText(str(storedYawP));
  storedYawI = yawI.getValue();
  fieldYawI.setText(str(storedYawI));
  storedYawD = yawD.getValue();
  fieldYawD.setText(str(storedYawD));
  storedYawA = yawAntiwindup.getValue();
  fieldYawA.setText(str(storedYawA));

  storedPitchP = pitchP.getValue();
  fieldPitchP.setText(str(storedPitchP));
  storedPitchI = pitchI.getValue();
  fieldPitchI.setText(str(storedPitchI));
  storedPitchD = pitchD.getValue();
  fieldPitchD.setText(str(storedPitchD));
  storedPitchA = pitchAntiwindup.getValue();
  fieldPitchA.setText(str(storedPitchA));
  
  storedRollP = rollP.getValue();
  fieldRollP.setText(str(storedRollP));
  storedRollI = rollI.getValue();
  fieldRollI.setText(str(storedRollI));
  storedRollD = rollD.getValue();
  fieldRollD.setText(str(storedRollD));
  storedRollA = rollAntiwindup.getValue();
  fieldRollA.setText(str(storedRollA));
  
  storedDepthP = depthP.getValue();
  fieldDepthP.setText(str(storedDepthP));
  storedDepthI = depthI.getValue();
  fieldDepthI.setText(str(storedDepthI));
  storedDepthD = depthD.getValue();
  fieldDepthD.setText(str(storedDepthD));
  storedDepthA = depthAntiwindup.getValue();
  fieldDepthA.setText(str(storedDepthA));
}

void loadGains()
{
  try
  {
    storedYawP = float(fieldYawP.getText());
    storedYawI = float(fieldYawI.getText());
    storedYawD = float(fieldYawD.getText());
    storedYawA = float(fieldYawA.getText());

    storedPitchP = float(fieldPitchP.getText());
    storedPitchI = float(fieldPitchI.getText());
    storedPitchD = float(fieldPitchD.getText());
    storedPitchA = float(fieldPitchA.getText());

    storedRollP = float(fieldRollP.getText());
    storedRollI = float(fieldRollI.getText());
    storedRollD = float(fieldRollD.getText());
    storedRollA = float(fieldRollA.getText());

    storedDepthP = float(fieldDepthP.getText());
    storedDepthI = float(fieldDepthI.getText());
    storedDepthD = float(fieldDepthD.getText());
    storedDepthA = float(fieldDepthA.getText());

    if(Float.isNaN(storedYawP) || Float.isNaN(storedYawI) || Float.isNaN(storedYawD) || Float.isNaN(storedYawA)
    || Float.isNaN(storedPitchP) || Float.isNaN(storedPitchI) || Float.isNaN(storedPitchD) || Float.isNaN(storedPitchA)
    || Float.isNaN(storedRollP) || Float.isNaN(storedRollI) || Float.isNaN(storedRollD) || Float.isNaN(storedRollA)
    || Float.isNaN(storedDepthP) || Float.isNaN(storedDepthI) || Float.isNaN(storedDepthD) || Float.isNaN(storedDepthA))
    {
      throw new Exception();
    }

    yawP.setValue(storedYawP);
    yawI.setValue(storedYawI);
    yawD.setValue(storedYawD);
    yawAntiwindup.setValue(storedYawA);

    pitchP.setValue(storedPitchP);
    pitchI.setValue(storedPitchI);
    pitchD.setValue(storedPitchD);
    pitchAntiwindup.setValue(storedPitchA);
    
    rollP.setValue(storedRollP);
    rollI.setValue(storedRollI);
    rollD.setValue(storedRollD);
    rollAntiwindup.setValue(storedRollA);
    
    depthP.setValue(storedDepthP);
    depthI.setValue(storedDepthI);
    depthD.setValue(storedDepthD);
    depthAntiwindup.setValue(storedDepthA);
  }
  catch(Exception e)
  {
    println("Error loading gains");
    println("Invalid format perhaps?");
  }
}

void arm()
{
  if(notConnected()) return;

  port.write("A\n");
}

void disarm()
{
  if(notConnected()) return;

  port.write("F\n");
}

void eepromSave()
{
  if(notConnected()) return;

  port.write("S\n");
}

void eepromLoad()
{
  if(notConnected()) return;

  port.write("L\nG\n");
}

void stop()
{
  try
  {
    datalog.flush();
    datalog.close();
  }
  catch (Exception e)
  {
    return;
  }
}