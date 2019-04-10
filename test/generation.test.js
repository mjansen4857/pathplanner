const {RobotPath} = require('../js/generation.js');
const {Vector2} = require('../js/util.js');

test('Generation Succeeds', () => {
    var path = new RobotPath([new Vector2(0, 0), new Vector2(5, 0), new Vector2(5, 5), new Vector2(10, 5)], [-1, -1], {maxVel: 12, maxAcc: 8, wheelbaseWidth: 2, timeStep: 0.01}, false, true);

    for(var i = 0; i < path.timeSegments.segments.length; i++){
        expect(path.timeSegments.segments[i].vel <= 12).toBe(true);
        expect(path.timeSegments.segments[i].acc <= 8).toBe(true);
    }
});