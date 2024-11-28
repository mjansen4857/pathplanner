from pathplannerlib.util import *

def test_floatLerp():
    assert floatLerp(1.0, 2.0, 0.5) == 1.5
    assert floatLerp(-1.0, 2.0, 0.5) == 0.5
    assert floatLerp(-3.0, -1.0, 0.5) == -2.0
