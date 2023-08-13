package com.pathplanner.lib.path;

import com.pathplanner.lib.auto.AutoBuilderException;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

public class PathGroup implements Iterable<PathPlannerPath> {
  private final List<PathPlannerPath> paths;

  /**
   * Create a new path group from an auto file
   *
   * @param autoName Name of the auto to get path group from
   */
  public PathGroup(String autoName) {
    try (BufferedReader br =
        new BufferedReader(
            new FileReader(
                new File(
                    Filesystem.getDeployDirectory(), "pathplanner/autos/" + autoName + ".auto")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);
      this.paths = pathsFromCommandJson((JSONObject) json.get("command"));
    } catch (AutoBuilderException e) {
      throw e;
    } catch (Exception e) {
      throw new RuntimeException(e.getMessage());
    }
  }

  private static List<PathPlannerPath> pathsFromCommandJson(JSONObject commandJson) {
    List<PathPlannerPath> paths = new ArrayList<>();

    String type = (String) commandJson.get("type");
    JSONObject data = (JSONObject) commandJson.get("data");

    if (type.equals("path")) {
      String pathName = (String) data.get("pathName");
      paths.add(PathPlannerPath.fromPathFile(pathName));
    } else if (type.equals("sequential")
        || type.equals("parallel")
        || type.equals("race")
        || type.equals("deadline")) {
      for (var cmdJson : (JSONArray) data.get("commands")) {
        paths.addAll(pathsFromCommandJson((JSONObject) cmdJson));
      }
    }

    return paths;
  }

  /**
   * Get the paths in this group
   *
   * @return List of paths
   */
  public List<PathPlannerPath> getPaths() {
    return paths;
  }

  /**
   * Get the path at the given index
   *
   * @param index Index of the path
   * @return Path at the given index
   */
  public PathPlannerPath getPath(int index) {
    return paths.get(index);
  }

  /**
   * Get the number of paths in this group
   *
   * @return Number of paths in the group
   */
  public int numPaths() {
    return paths.size();
  }

  @Override
  public Iterator<PathPlannerPath> iterator() {
    return paths.iterator();
  }
}
