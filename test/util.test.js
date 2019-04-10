const {Vector2, Util} = require('../js/util.js');

let a = new Vector2(10, 5);
let b = new Vector2(2, 2);
let c = new Vector2(3, 4);
let d = new Vector2(0, 0);

test('Vector2 Addition', () => {
    expect(Vector2.add(a, b)).toEqual(new Vector2(12, 7));
});

test('Vector2 Subtraction', () => {
    expect(Vector2.subtract(a, b)).toEqual(new Vector2(8, 3));
});

test('Vector2 Multiplication', () => {
    expect(Vector2.multiply(a, 2)).toEqual(new Vector2(20, 10));
});

test('Vector2 Division', () => {
    expect(Vector2.divide(a, 2)).toEqual(new Vector2(5, 2.5));
});

test('Vector2 Normalized', () => {
    expect(c.normalized()).toEqual(new Vector2(0.6, 0.8));
});

test('Lerp', () => {
    expect(Util.lerp(a, b, 0.5)).toEqual(new Vector2(6, 3.5));
});

test('Quadratic Curve', () => {
    expect(Util.quadraticCurve(a, b, c, 0.5)).toEqual(new Vector2(4.25, 3.25));
});

test('Cubic Curve', () => {
    expect(Util.cubicCurve(a, b, c, d, 0.5)).toEqual(new Vector2(3.125, 2.875));
});

test('Slope', () => {
    expect(Util.slope(a, b)).toBe(0.375);
});

test('Closest Point on Line', () => {
    let start = new Vector2(0, 0);
    let end = new Vector2(10, 10);
    let p = new Vector2(5, 6);
    expect(Util.closestPointOnLine(start, end, p)).toEqual(new Vector2(5.5, 5.5));
});