/*
 * $Id: JSONObject.java,v 1.1 2006/04/15 14:10:48 platform Exp $
 * Created on 2006-4-10
 */
package org.json.simple;

import java.io.IOException;
import java.io.StringWriter;
import java.io.Writer;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class JSONObject extends HashMap implements Map, JSONAware, JSONStreamAware {

  private static final long serialVersionUID = -503443796854799292L;

  public JSONObject() {
    super();
  }

  public JSONObject(Map map) {
    super(map);
  }

  public static void writeJSONString(Map map, Writer out) throws IOException {
    if (map == null) {
      out.write("null");
      return;
    }

    boolean first = true;
    Iterator iter = map.entrySet().iterator();

    out.write('{');
    while (iter.hasNext()) {
      if (first) first = false;
      else out.write(',');
      Map.Entry entry = (Map.Entry) iter.next();
      out.write('\"');
      out.write(escape(String.valueOf(entry.getKey())));
      out.write('\"');
      out.write(':');
      JSONValue.writeJSONString(entry.getValue(), out);
    }
    out.write('}');
  }

  public void writeJSONString(Writer out) throws IOException {
    writeJSONString(this, out);
  }

  public static String toJSONString(Map map) {
    final StringWriter writer = new StringWriter();

    try {
      writeJSONString(map, writer);
      return writer.toString();
    } catch (IOException e) {
      // This should never happen with a StringWriter
      throw new RuntimeException(e);
    }
  }

  public String toJSONString() {
    return toJSONString(this);
  }

  public String toString() {
    return toJSONString();
  }

  public static String toString(String key, Object value) {
    StringBuffer sb = new StringBuffer();
    sb.append('\"');
    if (key == null) sb.append("null");
    else JSONValue.escape(key, sb);
    sb.append('\"').append(':');

    sb.append(JSONValue.toJSONString(value));

    return sb.toString();
  }

  public static String escape(String s) {
    return JSONValue.escape(s);
  }
}
