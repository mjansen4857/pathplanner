const {PlannedPath} = require('../js/planned_path.js');
const {Vector2} = require('../js/util.js');

let p = new PlannedPath();

test('Initial Path', () => {
    expect(p.numPoints()).toBe(4);
    expect(p.numSplines()).toBe(1);
});

test('Points in Spline', () => {
    expect(p.getPointsInSpline(0)).toEqual(p.points);
});

test('Add Spline', () => {
    p.addSpline(new Vector2(10, 10));
    expect(p.numPoints()).toBe(7);
    expect(p.numSplines()).toBe(2);
});

test('Move Point', () => {
    var lastControl = p.get(p.numPoints() - 2);
    p.movePoint(p.numPoints() - 1, new Vector2(5, 5));
    expect(p.numPoints()).toBe(7);
    expect(p.numSplines()).toBe(2);
    expect(p.get(p.numPoints() - 1)).toEqual(new Vector2(5, 5));
    expect(p.get(p.numPoints() - 2)).toEqual(Vector2.subtract(lastControl, new Vector2(5, 5)));
});

test('Delete Spline', () => {
    p.deleteSpline(p.numPoints() - 1);
    expect(p.numPoints()).toBe(4);
    expect(p.numSplines()).toBe(1);
});

test('Update/Get Velocity', () => {
    p.updateVelocity(3, 10);
    expect(p.getVelocity(3)).toBe(10);
});

test('Anchor Index to Velocity', () => {
    expect(p.anchorIndexToVelocity(3)).toBe(1);
});