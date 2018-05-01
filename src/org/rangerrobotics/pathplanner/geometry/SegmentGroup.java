package org.rangerrobotics.pathplanner.geometry;

import java.util.ArrayList;

public class SegmentGroup {
    public ArrayList<Segment> s = new ArrayList<>();

    @Override
    public String toString(){
        String str = "";
        for(int i = 0; i < s.size(); i++){
            Segment a = s.get(i);
            str += a.pos + "," + a.vel + "," + a.acc + "\n";
        }
        return str;
    }

    public void add(Segment seg){
        s.add(seg);
    }
}
