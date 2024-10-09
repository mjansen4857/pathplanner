package com.pathplanner.lib.util;

public class FileVersionException extends RuntimeException {
  public FileVersionException(String fileVersion, String expectedVersion, String fileName) {
    super(
        "Incompatible file version for '"
            + fileName
            + "'. Actual: '"
            + fileVersion
            + "' Expected: '"
            + expectedVersion
            + "'");
  }
}
