package com.pathplanner.lib.util;

import edu.wpi.first.math.geometry.Translation2d;
import org.json.simple.JSONObject;

/** Utility class for creating different objects from JSON */
public class JSONUtil {
  /**
   * Create a Translation2d from a json object containing x and y fields
   *
   * @param translationJson The json object representing a translation
   * @return Translation2d from the given json
   */
  public static Translation2d translation2dFromJson(JSONObject translationJson) {
    double x = ((Number) translationJson.get("x")).doubleValue();
    double y = ((Number) translationJson.get("y")).doubleValue();

    return new Translation2d(x, y);
  }
}
