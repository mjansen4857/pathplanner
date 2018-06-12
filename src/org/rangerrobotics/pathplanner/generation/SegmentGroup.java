package org.rangerrobotics.pathplanner.generation;

import org.rangerrobotics.pathplanner.Preferences;

import java.util.ArrayList;

public class SegmentGroup {
    public ArrayList<Segment> segments = new ArrayList<>();

    public String formatCSV(boolean reverse){
        String str = "";
        for(int i = 0; i < segments.size(); i++){
            str += formatSegment(i, reverse);
            if(i < segments.size() - 1) {
                str += "\n";
            }
        }
        return str;
    }

    public String formatJavaArray(String arrayName, boolean reverse){
        //TODO: Add configuration for tab sizes, bracket placement, keywords, etc
        if(Preferences.outputValue2.equals("None") && Preferences.outputValue3.equals("None")){
            String str = "public static double[] " + arrayName + " = new double[] {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        " + formatSegment(i, reverse)  + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }else{
            String str = "public static double[][] " + arrayName + " = new double[][] {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        {" + formatSegment(i, reverse) + "}" + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }
    }

    public String formatCppArray(String arrayName, boolean reverse){
        //TODO: Add configuration for tab sizes, bracket placement, keywords, etc
        if(Preferences.outputValue2.equals("None") && Preferences.outputValue3.equals("None")){
            String str = "double " + arrayName + "[] = {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        " + formatSegment(i, reverse)  + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }else{
            String str = "double " + arrayName + "[][] = {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        {" + formatSegment(i, reverse) + "}" + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }
    }

    public String formatSegment(int index, boolean reverse){
        String str = "";
        Segment s = segments.get(index);
        //Value 1
        if(Preferences.outputValue1.equals("Position")){
            str += ((reverse) ? -s.pos: s.pos);
        }else if(Preferences.outputValue1.equals("Velocity")){
            str += ((reverse) ? -s.vel: s.vel);
        }else if(Preferences.outputValue1.equals("Acceleration")){
            str += ((reverse) ? -s.acc: s.acc);
        }else if(Preferences.outputValue1.equals("Time")){
            str += s.time;
        }
        //Value 2
        if(Preferences.outputValue2.equals("Position")){
            str += "," + ((reverse) ? -s.pos: s.pos);
        }else if(Preferences.outputValue2.equals("Velocity")){
            str += "," + ((reverse) ? -s.vel: s.vel);
        }else if(Preferences.outputValue2.equals("Acceleration")){
            str += "," +((reverse) ? -s.acc: s.acc);
        }else if(Preferences.outputValue2.equals("Time")){
            str += "," + s.time;
        }
        //Value 3
        if(Preferences.outputValue3.equals("Position")){
            str += "," + ((reverse) ? -s.pos: s.pos);
        }else if(Preferences.outputValue3.equals("Velocity")){
            str += "," + ((reverse) ? -s.vel: s.vel);
        }else if(Preferences.outputValue3.equals("Acceleration")){
            str += "," + ((reverse) ? -s.acc: s.acc);
        }else if(Preferences.outputValue3.equals("Time")){
            str += "," + s.time;
        }

        return str;
    }

    public void add(Segment seg){
        segments.add(seg);
    }
}
