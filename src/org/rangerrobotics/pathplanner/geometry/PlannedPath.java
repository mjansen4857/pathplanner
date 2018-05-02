package org.rangerrobotics.pathplanner.geometry;

import javafx.collections.FXCollections;
import javafx.collections.ObservableList;

public class PlannedPath {
    public ObservableList<Vector2> points;

    public PlannedPath(){
        this.points = FXCollections.observableArrayList();
        points.add(new Vector2(20, 20));
        points.add(new Vector2(170, 20));
        points.add(new Vector2(50, 200));
        points.add(new Vector2(200, 200));
    }

    public Vector2 get(int i){
        return points.get(i);
    }

    public int numPoints(){
        return points.size();
    }

    public int numSplines(){
        return ((points.size() - 4) / 3) + 1;
    }

    public Vector2[] getPointsInSpline(int i){
        return new Vector2[]{points.get(i * 3), points.get(i * 3 + 1), points.get(i * 3 + 2), points.get(i * 3 + 3)};
    }

    public void addSpline(Vector2 anchorPos){
        points.add(Vector2.subtract(Vector2.multiply(points.get(points.size() - 1), 2), points.get(points.size() - 2)));
        points.add(Vector2.multiply(Vector2.add(points.get(points.size() - 1), new Vector2(anchorPos.getX(), anchorPos.getY())), 0.5));
        points.add(new Vector2(anchorPos.getX(), anchorPos.getY()));
    }

    public void movePoint(int i, Vector2 newPos){
        Vector2 deltaMove = Vector2.subtract(newPos, points.get(i));
        points.set(i, newPos);

        if(i % 3 == 0){
            if(i + 1 < points.size()) {
                points.set(i + 1, Vector2.add(points.get(i + 1), deltaMove));
            }
            if(i - 1 >= 0) {
                points.set(i - 1, Vector2.add(points.get(i - 1), deltaMove));
            }
        }else{
            boolean nextIsAnchor = (i + 1) % 3 == 0;
            int correspondingControlIndex = (nextIsAnchor) ? i + 2 : i - 2;
            int anchorIndex = (nextIsAnchor) ? i + 1 : i - 1;

            if(correspondingControlIndex >= 0 && correspondingControlIndex < points.size()) {
                //Maintain distances from anchor
                double dst = Vector2.subtract(points.get(anchorIndex), points.get(correspondingControlIndex)).getMagnitude();
                Vector2 dir = Vector2.subtract(points.get(anchorIndex), newPos).normalized();

                points.set(correspondingControlIndex, Vector2.add(points.get(anchorIndex), Vector2.multiply(dir, dst)));

                //Same distances from anchor
//                Vector2 d = Vector2.subtract(newPos, points.get(anchorIndex));
//                points.set(correspondingControlIndex, Vector2.subtract(points.get(anchorIndex), d));
            }
        }
    }

    public void deleteSpline(int anchorIndex){
        if(anchorIndex % 3 == 0 && numSplines() > 1){
            if(anchorIndex == 0){
                points.remove(0, 3);

            }else if(anchorIndex == points.size() - 1){
                points.remove(anchorIndex - 2, anchorIndex + 1);
            }else{
                points.remove(anchorIndex - 1, anchorIndex + 2);
            }
        }
    }

    public SegmentGroup join(double step){
        System.out.println("Joining splines...");
        long start = System.currentTimeMillis();
        SegmentGroup s = new SegmentGroup();
        for(int i = 0; i < numSplines(); i++){
            Vector2[] points = getPointsInSpline(i);
            for(double d = 0; d <= 1.0; d += step){
                Vector2 p = Util.cubicCurve(points[0], points[1], points[2], points[3], d);
                Segment seg = new Segment();
                seg.x = p.getX();
                seg.y = p.getY();
                s.add(seg);
            }
        }
        System.out.println("    Num segments per spline: " + s.s.size() / numSplines());
        System.out.println("    Total Segments: " + s.s.size());
        System.out.println("DONE IN: " + (System.currentTimeMillis() - start) + "ms");
        return s;
    }
}
