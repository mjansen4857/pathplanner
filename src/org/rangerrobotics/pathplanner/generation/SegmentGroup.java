package org.rangerrobotics.pathplanner.generation;

import org.rangerrobotics.pathplanner.gui.PathEditor;

import java.util.ArrayList;

public class SegmentGroup {
    public ArrayList<Segment> segments = new ArrayList<>();

    public String formatCSV(boolean reverse, PathEditor editor){
        String str = "";
        for(int i = 0; i < segments.size(); i++){
            str += formatSegment(i, reverse, editor);
            if(i < segments.size() - 1) {
                str += "\n";
            }
        }
        return str;
    }

    public String formatJavaArray(String arrayName, boolean reverse, PathEditor editor){
        if(editor.pathPreferences.outputValue2.equals("None") && editor.pathPreferences.outputValue3.equals("None")){
            String str = "public static double[] " + arrayName + " = new double[] {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        " + formatSegment(i, reverse, editor)  + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }else{
            String str = "public static double[][] " + arrayName + " = new double[][] {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        {" + formatSegment(i, reverse, editor) + "}" + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }
    }

    public String formatCppArray(String arrayName, boolean reverse, PathEditor editor){
        if(editor.pathPreferences.outputValue2.equals("None") && editor.pathPreferences.outputValue3.equals("None")){
            String str = "double " + arrayName + "[] = {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        " + formatSegment(i, reverse, editor)  + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }else{
            String str = "double " + arrayName + "[][] = {\n";
            for(int i = 0; i < segments.size(); i++){
                str += "        {" + formatSegment(i, reverse, editor) + "}" + ((i < segments.size() - 1) ? ",\n" : "\n");
            }
            str += "    }";
            return str;
        }
    }

    public String formatPythonArray(String arrayName, boolean reverse, PathEditor editor){
        if(editor.pathPreferences.outputValue2.equals("None") && editor.pathPreferences.outputValue3.equals("None")){
            String str = arrayName + " = [";
            for(int i = 0; i < segments.size(); i++){
                str += formatSegment(i, reverse, editor) + ((i < segments.size() - 1) ? ",\n    " : "]");
            }
            return str;
        }else{
            String str = arrayName + " = [";
            for(int i = 0; i < segments.size(); i++){
                str += "[" + formatSegment(i, reverse,  editor) + ((i < segments.size() - 1) ? "],\n    " : "]]");
            }
            return str;
        }
    }

    public String formatSegment(int index, boolean reverse, PathEditor editor){
        String str = "";
        Segment s = segments.get(index);
        //Value 1
        if(editor.pathPreferences.outputValue1.equals("Position")){
            str += ((reverse) ? -s.pos: s.pos);
        }else if(editor.pathPreferences.outputValue1.equals("Velocity")){
            str += ((reverse) ? -s.vel: s.vel);
        }else if(editor.pathPreferences.outputValue1.equals("Acceleration")){
            str += ((reverse) ? -s.acc: s.acc);
        }else if(editor.pathPreferences.outputValue1.equals("Time")){
            str += s.time;
        }
        //Value 2
        if(editor.pathPreferences.outputValue2.equals("Position")){
            str += "," + ((reverse) ? -s.pos: s.pos);
        }else if(editor.pathPreferences.outputValue2.equals("Velocity")){
            str += "," + ((reverse) ? -s.vel: s.vel);
        }else if(editor.pathPreferences.outputValue2.equals("Acceleration")){
            str += "," +((reverse) ? -s.acc: s.acc);
        }else if(editor.pathPreferences.outputValue2.equals("Time")){
            str += "," + s.time;
        }
        //Value 3
        if(editor.pathPreferences.outputValue3.equals("Position")){
            str += "," + ((reverse) ? -s.pos: s.pos);
        }else if(editor.pathPreferences.outputValue3.equals("Velocity")){
            str += "," + ((reverse) ? -s.vel: s.vel);
        }else if(editor.pathPreferences.outputValue3.equals("Acceleration")){
            str += "," + ((reverse) ? -s.acc: s.acc);
        }else if(editor.pathPreferences.outputValue3.equals("Time")){
            str += "," + s.time;
        }

        return str;
    }

    public void add(Segment seg){
        segments.add(seg);
    }
}
