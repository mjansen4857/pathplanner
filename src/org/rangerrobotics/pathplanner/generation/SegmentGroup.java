package org.rangerrobotics.pathplanner.generation;

import org.rangerrobotics.pathplanner.Preferences;

import java.util.ArrayList;

public class SegmentGroup {
    public ArrayList<Segment> segments = new ArrayList<>();

    public String format(boolean negate){
        String str = "";
        for(int i = 0; i < segments.size(); i++){
            Segment s = segments.get(i);
            //Value 1
            if(Preferences.outputValue1.equals("Position")){
                str += ((negate) ? -s.pos: s.pos);
            }else if(Preferences.outputValue1.equals("Velocity")){
                str += ((negate) ? -s.vel: s.vel);
            }else if(Preferences.outputValue1.equals("Acceleration")){
                str += ((negate) ? -s.acc: s.acc);
            }else if(Preferences.outputValue1.equals("Time")){
                str += s.time;
            }
            //Value 2
            if(Preferences.outputValue2.equals("Position")){
                str += "," + ((negate) ? -s.pos: s.pos);
            }else if(Preferences.outputValue2.equals("Velocity")){
                str += "," + ((negate) ? -s.vel: s.vel);
            }else if(Preferences.outputValue2.equals("Acceleration")){
                str += "," +((negate) ? -s.acc: s.acc);
            }else if(Preferences.outputValue2.equals("Time")){
                str += "," + s.time;
            }
            //Value 3
            if(Preferences.outputValue3.equals("Position")){
                str += "," + ((negate) ? -s.pos: s.pos);
            }else if(Preferences.outputValue3.equals("Velocity")){
                str += "," + ((negate) ? -s.vel: s.vel);
            }else if(Preferences.outputValue3.equals("Acceleration")){
                str += "," + ((negate) ? -s.acc: s.acc);
            }else if(Preferences.outputValue3.equals("Time")){
                str += "," + s.time;
            }
            if(i < segments.size() - 1) {
                str += "\n";
            }
        }
        return str;
    }

    public void add(Segment seg){
        segments.add(seg);
    }
}
