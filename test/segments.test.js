const {Segment, SegmentGroup} = require('../js/segments.js');

test('Format Segment', () => {
    let sg = new SegmentGroup();

    var s = new Segment();
    s.x = 0;
    s.y = 1;
    s.pos = 2;
    s.vel = 3;
    s.acc = 4;
    s.heading = 5;
    s.relativeHeading = 6;
    s.time = 7;
    s.relativeWinding = 8;
    s.winding = 9;
    sg.add(s);

    expect(sg.formatSegment(0, false, 'x,y,p,v,a,h,H,t,S,s,W,w', 0.01))
        .toBe('0,1,2,3,4,5,6,7,0.01,10,8,9');
});