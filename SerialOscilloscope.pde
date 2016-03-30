/*
 * Serial Oscilloscope
 * Gives a visual rendering of serial input in realtime.
 * 
 * (c) 2016 Yu-Lun Tsai (stormysun513@gmail.com)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */ 
 
import java.util.Random;
import processing.serial.*;

Serial serial = null;      // Create object from Serial class
int val;                   // Data received from the serial port
int lastUpdate;
int[] values;              // Store subsequential values
int index;
int size;

PrintWriter output;
PFont f;
Random random;

float zoom;              // Scale the window
int vOffset;

float[] lowpass;         // Array for storing temporary output of lowPassFilter()
int[] tempIndex;         // Candidates of peaks index

int filterWinSize;       // Size of data used for lowpass and peak detection
int countLoop; 
int countSample; 
int last;
 
void setup() {
  // Set the dimension of display screen
  size(800, 600);
  
  // Initialize variables
  val = -1;
  lastUpdate = -100;
  index = 0;
  size = width;
  filterWinSize = 256;
  //vOffset = Short.MAX_VALUE;
  vOffset = 0x7F;
  zoom = 1.0f;
  
  values = new int[size];
  lowpass = new float[filterWinSize]; 
  tempIndex = new int[50];
  
  // Open the port that the board is connected to and use the same speed (115200 bps)
  String[] ports = Serial.list();
  
  for(String p : ports){
    if(p.contains("tty.usbmodem")){
      serial = new Serial(this, p, 115200);
      if(serial != null)
        break;
    }
  }
  //if(serial == null)
  //  return;
  
  countLoop = 0;
  countSample = 0;
  last = 0;
  
  smooth();
  long unixTime = System.currentTimeMillis()/1000L;
  output = createWriter(String.valueOf(unixTime).concat(".txt"));
  //output = createWriter("output.txt");
  random = new Random();
  f = createFont("Arial", 16, true); // Arial, 16 point, anti-aliasing on
  textFont(f, 36);
  fill(255);
}
 
int getY(float val) {
  return (int)(height - (float)(val+vOffset)/(vOffset*2)*height);
}
 
int getValue() {
  //short value = (short)random.nextInt(40);
  short value = -1;
  while (serial.available() >= 4) {
    if (serial.read() == 0xff) {
      if (serial.read() == 0x7f){
          short myShort1 = (short)serial.read();
          short myShort2 = (short)serial.read(); 
          value =  (short)((myShort1 << 8) | myShort2);
          countSample++;
      }
    }
  }
  return (int)value;
}
 
void pushValue(int value) {
  index++;
  index %= size;
  values[index] = value;
}
 
void drawLines() {
  stroke(255);
  int displaySize = (int) (width / zoom);
  
  int k = (index + size - displaySize) % size;
  
  int x0 = 0;
  int y0 = getY(values[k]);
  for (int i = 1; i < displaySize; i++) {
    k++;
    k %= size;
    int x1 = (int) (i * (width-1) / (displaySize-1));
    int y1 = getY(values[k]);
    line(x0, y0, x1, y1);
    x0 = x1;
    y0 = y1;
  }
}
 
void drawGrid() {
  stroke(200, 0, 0);
  line(0, height/2, width, height/2);
  text("RSSI:" + String.valueOf(lastUpdate), 10, 30);
}
 
void keyReleased() {
  switch (key) {
    case '+':
      zoom *= 2.0f;
      println(zoom);
      if ( (int) (size / zoom) <= 1 )
        zoom /= 2.0f;
      break;
    case '-':
      zoom /= 2.0f;
      println(zoom);
      if (zoom < 1.0f)
        zoom *= 2.0f;
      break;
  }
}
 
void draw()
{
  countLoop++;
  background(0);
  drawGrid();
  val = getValue();
  if (val != -1) {
   lastUpdate = val;
   output.println(lastUpdate);
   output.flush();
  }
  else{
   val = lastUpdate;
  }
  pushValue(val);
  drawLines();
  
  //if(countLoop == 256) {
  //  if(last == 0){
  //    countLoop = 0;
  //    countSample = 0;
  //    last = millis();
  //  }
  //  else{
  //    int delta = millis()-last;
  //    float fs = ((float)countSample/delta)*1000;
    
  //    // Low Pass Filter
  //    float average = lowPassFilter(values, 5); 
  //    int interval = peakDetection(lowpass, average, fs);
      
  //    println("Average: "+ average);
  //    println("Sampling rate: " + fs);
  //    println("Heart Beat Rate: " + 1/((float)interval/fs));
    
  //    last = millis();
  //    countSample = 0;
  //    countLoop = 0;
  //  }
  //}
}

// Apply low pass filter to data which its size is specified 
// Return the average value of data in that size
float lowPassFilter(int data[], int window)
{
  float average = 0;
  for(int i = 0; i < filterWinSize; i++){
    int cnt = 0;
    float temp = 0;
    for(int j = i-window; j < i+window; j++){
      if( j < 0 || j >= filterWinSize)continue;
      temp += data[j];
      cnt++;
    }
    lowpass[i] = (float)temp/cnt; 
    average += data[i];
  }
  return average/filterWinSize;
}


// Return number of n that between two peeks
// If not detected return -1;
int peakDetection(float data[], float average, float fs)
{
  int cnt = 0;
  float diff = 5000.0;
  for(int i = 0; i < filterWinSize; i++){
    if(abs(data[i]-average) > diff){
      if(cnt >= 50)break;
      tempIndex[cnt] = i;
      cnt++;
    }
  }
  
  int accOfCandidate = 0;
  int times = 0;
  for(int i = 0; i < cnt; i++){
    for(int j = i+1; j < cnt-1; j++){
      if(tempIndex[j]-tempIndex[i] == 1 && data[tempIndex[j]] > data[tempIndex[i]])
        break;
        
      // Restrict search range to 50 ~ 180 beat/min
      if(tempIndex[j]-tempIndex[i] < (180/60/fs) && tempIndex[j]-tempIndex[i] > (50/60/fs)){
        if(data[tempIndex[j]]>data[tempIndex[j+1]] && data[tempIndex[j]]>data[tempIndex[j-1]]){
          accOfCandidate += tempIndex[j]-tempIndex[i];
          times++;
          break;
        }
      }
    }
  }
  if(times == 0)
    return -1;
  return accOfCandidate/times;
}