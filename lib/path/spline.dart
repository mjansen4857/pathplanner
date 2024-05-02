import 'dart:math';

class Spline{
  num x0, x1, x2, x3, x4, x5;
  num y0, y1, y2, y3, y4, y5;


  Spline({
      required x1,
      required x2,
      required dx1,
      required dx2,
      required y1,
      required y2,
      required dy1,
      required dy2,
  }):
    x0 = x1,
    x1 = dx1,
    x2 = 0.5*0.0, 
    x3 = -10*x1-6*dx1-4*dx2+10*x2  -1.5*0.0+0.5*0.0,
    x4 = 15*x1+8*dx1+7*dx2-15*x2   +1.5*0.0-0.0,
    x5 = -6*x1-3*dx1-3*dx2+6*x2   -0.5*0.0+0.5*0.0,
    y0 = y1,
    y1 = dy1,
    y2 = 0.5*0.0, 
    y3 = -10*y1-6*dy1-4*dy2+10*y2  -1.5*0.0+0.5*0.0,
    y4 = 15*y1+8*dy1+7*dy2-15*y2   +1.5*0.0-0.0,
    y5 = -6*y1-3*dy1-3*dy2+6*y2   -0.5*0.0+0.5*0.0
  ;

  Point getPoint(num t){
   return Point(getX(t), getY(t));
  }

  num getX(num t){
    return x0 + x1 * t + x2 * t*t + x3 * t*t*t + x4 * t*t*t*t + x5 * t*t*t*t*t; 
  }

  num getY(num t){
    return y0 + y1 * t + y2 * t*t + y3 * t*t*t + y4 * t*t*t*t + y5 * t*t*t*t*t; 
  }
}