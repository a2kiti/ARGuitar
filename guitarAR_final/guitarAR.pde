import processing.video.*; // using video for camera
import jp.nyatla.nyar4psg.*; // using nyar4psg for AR
import themidibus.*; //using midi 
MidiBus myBus;

Capture cam;
MultiMarker mm;

PImage img, noteImg;

//for calibration
float ajstX = 0, ajstY = 0, ajstZ = 0;
float ajstRX = 0, ajstRY = 0, ajstRZ = 0;
float ajstZoom = 1;
PrintWriter guitarSetting; //to save csv

NoteImg noteImgCl;
FletImg fletImgCl;
ScoreImg scoreImgCl;

PMatrix3D viewport;

void setup() {
  //camera settings
  size(1280, 960, P3D); // setting window size with P3D mode
  
  String[] cameras = Capture.list(); // getting available camera devices
  printArray(cameras); 
  cam = new Capture(this, cameras[0]);  // Select by camera list.
  //cam = new Capture(this, "name=USBカメラ,size=1280x960,fps=30");
  cam.start(); // starting capture
  // NyARToolkit settings
  mm = new MultiMarker(this,
             width,
             height,
             "camera_para.dat",
             NyAR4PsgConfig.CONFIG_PSG);
  mm.addNyIdMarker(0, 80);// settiing use NyId marker

  //test
  img = createLight(random(0.5, 0.8), random(0.5, 0.8), random(0.5, 0.8));
  noteImg = createNoteImg("noteImg2.jpg", random(0.5, 0.8), random(0.5, 0.8), random(0.5, 0.8));
  
  //Animations
  fletImgCl = new FletImg();
  scoreImgCl = new ScoreImg();
  noteImgCl = new NoteImg();
  
  viewport = ((PGraphics3D)g).projection;
  
  //loading guitar calibration data
  String[] datalines = loadStrings("guitarSetting.csv");
  if(datalines != null) {
    if(datalines[0].length() != 0) {
      String[] values = datalines[0].split("," , -1);
      ajstX = float(values[0]);
      ajstY = float(values[1]);
      ajstZ = float(values[2]);
      ajstRX = float(values[3]);
      ajstRY = float(values[4]);
      ajstRZ = float(values[5]);
      ajstZoom = float(values[6]);
      
      println(ajstX);
      println(ajstY);
      println(ajstZ);
      println(ajstRX);
      println(ajstRY);
      println(ajstRZ);
      println(ajstZoom);
    }
  }
  
  MidiBus.list();//getting list of midi devices
  myBus = new MidiBus(this, 2,-1);// selecting midi divice
}

void draw() {
  
  // camera capture
  if(cam.available() == false) {
    return;                             
  }
  cam.read();// capturing image
  
  // Start of AR process
  mm.detect(cam);// detecting marker
  mm.drawBackground(cam);// drawing captured image on background
  
  //drawing image
  blendMode(BLEND);
  imageMode(CENTER);
  scoreImgCl.draw();
  
  blendMode(ADD);
  noteImgCl.draw();
  
  blendMode(BLEND);
  imageMode(CORNER);
  blendMode(BLEND);
  
  // if marker[0] is not exist within the image
  if(mm.isExist(0) == false) { 
    return;                     
  }
  
  // starting coordinate projection based on marker[0]
  mm.beginTransform(0);                  
    
    blendMode(ADD);
    imageMode(CENTER);
    hint(DISABLE_DEPTH_TEST);
    
    scale(-0.8*ajstZoom,-0.8*ajstZoom);
    rotateX(ajstRX);
    rotateY(ajstRY);
    rotateZ(ajstRZ);
    translate(300+ajstX, 100+ajstY, 20+ajstZ);
    fletImgCl.drawFlet();
    fletImgCl.drawCircles();
    fletImgCl.drawPickups();
    
    viewport = (PMatrix3D)getMatrix();
    
    translate(-(300+ajstX), -(100+ajstY), -(20+ajstZ));
    rotateZ(ajstRZ);
    rotateY(ajstRY);
    rotateX(ajstRX);
    scale(-1.25/ajstZoom,-1.25/ajstZoom);
    
    hint(ENABLE_DEPTH_TEST);
    imageMode(CORNER);
    blendMode(BLEND);
    
  mm.endTransform(); 
  // End of AR process
}

PImage createLight(float rPower, float gPower, float bPower) {
  int side = 200;
  float center = side / 2.0;
  PImage img = createImage(side, side, RGB);
  
  for (int y = 0; y < side; y++) {
    for (int x = 0; x < side; x++) {
      //float distance = sqrt(sq(center - x) + sq(center - y));
      float distance = (sq(center - x) + sq(center - y)) / 50.0;
      int r = int( (255 * rPower) / distance );
      int g = int( (255 * gPower) / distance );
      int b = int( (255 * bPower) / distance );
      img.pixels[x + y * side] = color(r, g, b);
    }
  }
  return img;
}

void mousePressed() {
  noteImgCl.newNote(0,0);
}

PImage createNoteImg(String path, float rPower, float gPower, float bPower) {
  
  PImage noteImg = loadImage(path);
  for (int y = 0; y < noteImg.height; y++) {
    for (int x = 0; x < noteImg.width; x++) {
      color c = noteImg.pixels[x + y * noteImg.width];
      if(red(c) < 20){
        noteImg.pixels[x + y * noteImg.width] = color(255*rPower,255*gPower,255*bPower);
      }else{
        noteImg.pixels[x + y * noteImg.width] = color(0, 0, 0);
      }
    }   
  }
  noteImg.filter(BLUR, 8);
  
  return noteImg;
}

class ScoreImg {
  PImage scoreImg;
  PImage backImg;
  PImage numberImg0;
  int numberInd[] = new int[6];
  PImage numberImg[] = new PImage[120];
  int ix[] = new int[120];
  int iy[] = new int[120];
  int flag[] = new int[120];
  int backSizeX = 650;
  int backSizeY = 130;
  
  int baseSizeX = 600;
  int baseSizeY = 100;
  int offsetX = width/2 + baseSizeX/2;
  int offsetY = baseSizeY/2 + 100;
  float vx = -4;
  int fcSpeed = 100;
  ScoreImg() {
    init();
    newNumber(4,4);
  }
  void draw() {
    blendMode(ADD);
    imageMode(CENTER);
    image(backImg, offsetX, offsetY);
    
    blendMode(BLEND);
    imageMode(CENTER);
    image(scoreImg, offsetX, offsetY);
    
    for (int i = 0; i < 120; i++) {
      if(flag[i] == 1){
        ix[i] += vx;
        if(ix[i] < width/2+30)flag[i]=0;
        image(numberImg[i], ix[i], iy[i]);
      }
    }
    
  }
  void init(){
    scoreImg = createBase(0.1,0.1,1.0,0.7);
    backImg = createBack();
  }
  
  PImage createBack() {
    int sizeX = backSizeX;
    int sizeY = backSizeY;
    
    PImage img = createImage(sizeX, sizeY, ARGB);
    
    for (int y = 0; y < sizeY; y++) {
      for (int x = 0; x < sizeX; x++) {
        img.pixels[x + y * sizeX] = color(255,255,255,120);
      }
    }
    return img;
  }
  PImage createBase(float rPower, float gPower, float bPower, float aPower) {
    int sizeX = baseSizeX;
    int sizeY = baseSizeY;
    
    PImage img = createImage(sizeX, sizeY, ARGB);
    
    for (int y = 0; y < sizeY; y++) {
      for (int x = 0; x < sizeX; x++) {
        if(y % int(sizeY/6) == int(sizeY/12)){
          img.pixels[x + (y-1) * sizeX] = color(255*rPower,255*gPower,255*bPower, 255*aPower);
          img.pixels[x + y * sizeX] = color(255*rPower,255*gPower,255*bPower, 255*aPower);
          //img.pixels[x + (y+1) * sizeX] = color(255*rPower,255*gPower,255*bPower, 255*aPower);
        }
      }
    }
    
    PGraphics pg = createGraphics( sizeX, sizeY );
  
    pg.beginDraw(); 
    pg.image( img, 0, 0 );
    pg.noFill();               
    pg.fill(255*rPower,255*gPower,255*bPower, 255*aPower);
    pg.textSize(36);        
    pg.textAlign(CENTER);
    pg.text("T", 20, sizeY/2 + 13 - 27);
    pg.text("A", 20, sizeY/2 + 13 + 0);
    pg.text("B", 20, sizeY/2 + 13 + 27);
    pg.endDraw(); 
  
    img.pixels = pg.pixels;
     
    return img;
  }
  
  PImage createNumberImg(int n, float rPower, float gPower, float bPower, float aPower) {
    int sizeX = 100;
    int sizeY = 100;
    
    PImage img = createImage(sizeX, sizeY, ARGB);
    
    PGraphics pg = createGraphics( sizeX, sizeY );
  
    pg.beginDraw();
    pg.image( img, 0, 0 );
    pg.noFill();               
    pg.fill(255*rPower,255*gPower,255*bPower, 255*aPower);
    pg.textSize(20);
    pg.textAlign(CENTER);
    pg.text(str(n), sizeX/2, sizeY/2-10);
    pg.endDraw();
    
    img.pixels = pg.pixels;
     
    return img;
  }
  
  void newNumber(int string, int flet){
    
    int interval = 30;
    int j = numberInd[string-1] + 20*(string-1);
    int diff = offsetX + baseSizeX/2 - ix[j];
    if(diff < interval){
      for (int jj = 0; jj < 120; jj++) {
        ix[jj] -= interval - diff;
      }
    }
    
    numberInd[string-1] += 1;
    if(numberInd[string-1] >= 20)numberInd[string-1]=0;
    int i = numberInd[string-1] + 20*(string-1);
    
    numberImg[i] = createNumberImg(flet, 0.4,0.4,1.0,0.9);
    ix[i] = offsetX + baseSizeX/2;
    iy[i] = offsetY + int((string-2.5)*baseSizeY/6);
    flag[i] = 1;
  }
}


class NoteImg {
  int numberInd = 0;
  PImage noteImg[] = new PImage[100];
  int vx[] = new int[100];
  int vy[] = new int[100];
  int ix[] = new int[100];
  int iy[] = new int[100];
  int flag[] = new int[100];
  
  int scorePosX = width/2 + 600;
  int scorePosY = 150;
  
  NoteImg() {
    init();
  }
  void draw() {
    for (int i = 0; i < 100; i++) {
      if(flag[i] == 1){
        ix[i] += vx[i];
        iy[i] += vy[i];
        if(ix[i] > scorePosX-30)flag[i]=0;
        image(noteImg[i], ix[i], iy[i]);
      }
    }
  }
  void init(){
    for (int i = 0; i < 100; i++) {
      String path;
      if(random(0.0, 1.0) < 0.5){
        path = "noteImg.jpg";  
      }else{
        path = "noteImg2.jpg"; 
      }
      float rPower = random(0.2, 0.8);
      float gPower = random(0.2, 0.8);
      float bPower = random(0.2, 0.8);
      noteImg[i] = createNoteImg(path, rPower, gPower, bPower);
      noteImg[i].resize(noteImg[i].width/4, noteImg[i].height/4);
      flag[i] = 0;
    }
    
  }
  
  void newNote(int inx, int iny){
    numberInd += 1;
    if(numberInd >= 100)numberInd=0;
    
    ix[numberInd] = inx;
    iy[numberInd] = iny;
    vx[numberInd] = (scorePosX-inx)/20 ;
    vy[numberInd] = (scorePosY-iny)/20 ;
    
    flag[numberInd] = 1;
  }
  
  PImage createNoteImg(String path, float rPower, float gPower, float bPower) {
    
    PImage noteImg = loadImage(path);
    
    for (int y = 0; y < noteImg.height; y++) {
      for (int x = 0; x < noteImg.width; x++) {
        color c = noteImg.pixels[x + y * noteImg.width];
        if(red(c) < 20){
          noteImg.pixels[x + y * noteImg.width] = color(255*rPower,255*gPower,255*bPower);
        }else{
          noteImg.pixels[x + y * noteImg.width] = color(0, 0, 0);
        }
      }   
    }
    noteImg.filter(BLUR, 8);
    
    return noteImg;
  }
}

class FletImg {
  PImage fletImg;
  PImage circleImg[] = new PImage[6];
  PImage PickupImg[] = new PImage[24];
  int sizeX = 1200;
  int sizeY = 120;
  int nf, nfys, nfye;
  float nfya = 0.15;
  int fletLengthX = 1050, fletLengthY = 100;
  int ix[] = new int[6];
  int iy[] = new int[6];
  int ix_p[] = new int[24];
  int iy_p[] = new int[24];
  int pickupFlag = 0;
  
  FletImg() {
    createFlet(0.0,0.0,1.0);
    createCircles(0.2,1.0,0.2);
    createPickups(0.2,1.0,0.2);
  }
  void drawFlet() {
    image(fletImg, 0, 0);
  }
  void drawCircles() {
    for (int i = 0; i < 6; i++) {
      image(circleImg[i], ix[i], iy[i]);
    }
  }
  void drawPickups() {
    if(pickupFlag == 0){
      return;
    }
    for (int i = 0; i < 24; i++) {
      image(PickupImg[i], ix_p[i], iy_p[i]);
    }
  }
  void changePosition(int string, float flet) {
    ix[string-1] = getPositionX(flet);
    iy[string-1] = getPositionY(string, flet);
  }
  void createCircles(float rPower, float gPower, float bPower){
    for (int i = 0; i < 6; i++) {
      circleImg[i] = createCircleImg(rPower, gPower, bPower);
      ix[i] = 10000;
      iy[i] = 10000;
    }
  }
 
  void createPickups(float rPower, float gPower, float bPower){
    for (int i = 0; i < 6; i++) {
      PickupImg[i] = createCircleImg(rPower, gPower, bPower);
      ix_p[i] = getPositionX(24.5);
      iy_p[i] = getPositionY(i+1, 24.5);
    }
    for (int i = 6; i < 12; i++) {
      PickupImg[i] = createCircleImg(rPower, gPower, bPower);
      ix_p[i] = getPositionX(31);
      iy_p[i] = getPositionY(i-5, 31);
    }
    for (int i = 12; i < 18; i++) {
      PickupImg[i] = createCircleImg(rPower, gPower, bPower);
      ix_p[i] = getPositionX(42);
      iy_p[i] = getPositionY(i-11, 42);
    }
    for (int i = 18; i < 24; i++) {
      PickupImg[i] = createCircleImg(rPower, gPower, bPower);
      ix_p[i] = getPositionX(50);
      iy_p[i] = getPositionY(i-17, 50);
    }
  }
  PImage createCircleImg(float rPower, float gPower, float bPower){
    int side = 200;
    float center = side / 2.0;
    
    PImage img = createImage(side, side, RGB);
    
    for (int y = 0; y < side; y++) {
      for (int x = 0; x < side; x++) {
        float distance = (sq(center - x) + sq(center - y)) / 50.0;
        int r = int( (255 * rPower) / distance );
        int g = int( (255 * gPower) / distance );
        int b = int( (255 * bPower) / distance );
        img.pixels[x + y * side] = color(r, g, b);
      }
    }
    return img;
  }
  
  void createFlet(float rPower, float gPower, float bPower){
    fletImg = createImage(sizeX, sizeY, RGB);
    
    for (int f = 0; f < 22; f++) {
      nf = int(pow(2,(12-float(f))/12)*fletLengthX/2);
      nfys = 20 + int(fletLengthY * (float(nf)/float(fletLengthX)*nfya));
      nfye = 20 + int(fletLengthY * (1 - float(nf)/float(fletLengthX)*nfya));
      for (int y = nfys; y < nfye; y++) {
        fletImg.pixels[nf + y * sizeX] = color(255*rPower,255*gPower,255*bPower);
        for (int i = 0; i < 5; i++) {
          fletImg.pixels[nf+i + y * sizeX] = color(255*rPower,255*gPower,255*bPower);
          fletImg.pixels[nf-i + y * sizeX] = color(255*rPower,255*gPower,255*bPower);
        }
      }
    }
    
    fletImg.filter(BLUR, 3);
    
    for (int f = 0; f <= 22; f++) {
      nf = int(pow(2,(12-float(f))/12)*fletLengthX/2);
      nfys = 20 + int(fletLengthY * (float(nf)/float(fletLengthX)*nfya));
      nfye = 20 + int(fletLengthY * (1 - float(nf)/float(fletLengthX)*nfya));
      for (int y = nfys; y < nfye; y++) {
        fletImg.pixels[nf + y * sizeX] = color(255*rPower,255*gPower,255*bPower);
        for (int i = 0; i < 3; i++) {
          fletImg.pixels[nf+i + y * sizeX] = color(255*rPower,255*gPower,255*bPower);
          fletImg.pixels[nf-i + y * sizeX] = color(255*rPower,255*gPower,255*bPower);
        }
      }
    }
    
    for (int f = 0; f <= 22; f++) {
      nf = int(pow(2,(12-float(f))/12)*fletLengthX/2);
      nfys = 15 + int(fletLengthY * (float(nf)/float(fletLengthX)*nfya));
      drawText(fletImg,nf,nfys,str(f),17,int(255*rPower),int(255*gPower),int(255*bPower));
    }
  }
  
  void changeColor() {
    createFlet(random(0.2, 0.8), random(0.2, 0.8), random(0.2, 0.8));
  }
  
  int getPositionX(float flet) {
    int x;
    x = int(pow(2,(12-(flet-0.5))/12)*fletLengthX/2) - sizeX/2; 
    return x;
  }
  int getPositionY(int string, float flet) {
    int y;
    int nf = int(pow(2,(12-flet)/12)*fletLengthX/2);
    int nfy = 20 + int(fletLengthY * (float(nf)/float(fletLengthX)*nfya));
    int fletLengthYEach = int(fletLengthY * (1 - float(nf)/float(fletLengthX)*nfya*2));
    y = nfy + int((6.5-float(string))/6 * fletLengthYEach) - sizeY/2;
    return y;
  }
  
  void drawText(PImage img_out, int x, int y, String txt,int size,int r,int g,int b) {
  
    PGraphics pg = createGraphics( img_out.width, img_out.height );
  
    pg.beginDraw(); 
    pg.image( img_out, 0, 0 );
    pg.noFill();               
    pg.fill(r, g, b);      
    pg.textSize(size);        
    pg.textAlign(CENTER);
    pg.text(txt, x, y);     
    pg.endDraw();              
  
    img_out.pixels = pg.pixels;
  }

  
}





void keyPressed(){
  if( key == '1' ){
    ajstX -= 1;
    print(ajstX);
  }
  if( key == 'q' ){
    ajstX += 1;
    print(ajstX);
  }
  if( key == '2' ){
    ajstY -= 1;
    print(ajstY);
  }
  if( key == 'w' ){
    ajstY += 1;
    print(ajstY);
  }
  if( key == '3' ){
    ajstZ -= 1;
    print(ajstZ);
  }
  if( key == 'e' ){
    ajstZ += 1;
    print(ajstZ);
  }
  if( key == '4' ){
    ajstRX -= 0.001;
    print(ajstRX);
  }
  if( key == 'r' ){
    ajstRX += 0.001;
    print(ajstRX);
  }
  if( key == '5' ){
    ajstRY -= 0.001;
    print(ajstRY);
  }
  if( key == 't' ){
    ajstRY += 0.001;
    print(ajstRY);
  }
  if( key == '6' ){
    ajstRZ -= 0.001;
    print(ajstRZ);
  }
  if( key == 'y' ){
    ajstRZ += 0.001;
    print(ajstRZ);
  }
  if( key == '7' ){
    ajstZoom *= 0.999;
    print(ajstZoom);
  }
  if( key == 'u' ){
    ajstZoom /= 0.999;
    print(ajstZoom);
  }
  if( key == 's' ){
    guitarSetting = createWriter("guitarSetting.csv");
    guitarSetting.print(ajstX);
    guitarSetting.print(",");
    guitarSetting.print(ajstY);
    guitarSetting.print(",");
    guitarSetting.print(ajstZ);
    guitarSetting.print(",");
    guitarSetting.print(ajstRX);
    guitarSetting.print(",");
    guitarSetting.print(ajstRY);
    guitarSetting.print(",");
    guitarSetting.print(ajstRZ);
    guitarSetting.print(",");
    guitarSetting.print(ajstZoom);
    guitarSetting.print(",");
    guitarSetting.close();
    print("guitarSetting Save!");
  }
  if( key == 'p' ){
    fletImgCl.pickupFlag = fletImgCl.pickupFlag == 0 ? 1 : 0;
  }
  if( key == 'n' ){
    
    int string = int(round(random(1, 6)));
    float flet = (round(random(0, 22)));
    scoreImgCl.newNumber(string,int(flet));
    fletImgCl.changePosition(string,flet);
    
    float[] in = {float(fletImgCl.getPositionX(flet)), float(fletImgCl.getPositionY(string,flet)), 0.0f, 1.0f};
    float[] out = new float[4];
    viewport.mult(in, out);
    noteImgCl.newNote( int(out[0]) + width/2, int(out[1]) + height/2 );
  }
}


//this function woaks when noteon comes.
void noteOn(int channel, int pitch, int velocity) {
  println("Channel:"+channel+" Pitch:"+pitch+" Velocity:"+velocity);
  float flet = 0;
  int string = channel;
  if (string > 6)string = 6;
  if (string < 1)string = 1;
  
  switch (string){
    case 6:
      flet = pitch - 40;
      break;
    case 5:
      flet = pitch - 45;
      break;
    case 4:
      flet = pitch - 50;
      break;
    case 3:
      flet = pitch - 55;
      break;
    case 2:
      flet = pitch - 59;
      break;
    case 1:
      flet = pitch - 64;
      break;
  }
  
  if(velocity > 60){
    fletImgCl.changePosition(string,flet);
    scoreImgCl.newNumber(string,int(flet));
    
    float[] in = {float(fletImgCl.getPositionX(flet)), float(fletImgCl.getPositionY(string,flet)), 0.0f, 1.0f};
    float[] out = new float[4];
    viewport.mult(in, out);
    noteImgCl.newNote( int(out[0]) + width/2, int(out[1]) + height/2 );    
  }else{
    fletImgCl.changePosition(string,-100);
  }
  
  println("string:"+string+" flet:"+flet);
  
}
 
