class MathUtil {
  static num inputModulus(num input, num minimumInput, num maximumInput) {
    num modulus = maximumInput - minimumInput;

    // Wrap input if it's above the maximum input
    int numMax = (input - minimumInput) ~/ modulus;
    input -= numMax * modulus;

    // Wrap input if it's below the minimum input
    int numMin = (input - maximumInput) ~/ modulus;
    input -= numMin * modulus;

    return input;
  }
}
