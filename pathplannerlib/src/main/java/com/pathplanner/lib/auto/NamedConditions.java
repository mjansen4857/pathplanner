package com.pathplanner.lib.auto;

import edu.wpi.first.math.Pair;
import edu.wpi.first.wpilibj.DriverStation;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BooleanSupplier;

/** Utility class for managing named conditions */
public class NamedConditions {
    private static final HashMap<String, BooleanSupplier> namedConditions = new HashMap<>();

    /**
     * Registers a condition with the given name.
     *
     * @param name      the name of the condition
     * @param condition the condition to register
     */
    public static void registerCondition(String name, BooleanSupplier condition) {
        namedConditions.put(name, condition);
    }

    /**
     * Registers a list of conditions with their associated names.
     *
     * @param conditions the list of conditions to register
     */
    public static void registerConditions(List<Pair<String, BooleanSupplier>> conditions) {
        for (var pair : conditions) {
            registerCondition(pair.getFirst(), pair.getSecond());
        }
    }

    /**
     * Registers a map of conditions with their associated names.
     *
     * @param conditions the map of conditions to register
     */
    public static void registerConditions(Map<String, BooleanSupplier> conditions) {
        namedConditions.putAll(conditions);
    }

    /**
     * Returns whether a condition with the given name has been registered.
     *
     * @param name the name of the condition to check
     * @return true if a condition with the given name has been registered, false
     *         otherwise
     */
    public static boolean hasCondition(String name) {
        return namedConditions.containsKey(name);
    }

    /**
     * Returns the condition with the given name.
     *
     * @param name the name of the condition to get
     * @return the condition with the given name, or false if it has not been
     *         registered
     */
    public static BooleanSupplier getCondition(String name) {
        if (hasCondition(name)) {
            return namedConditions.get(name);
        } else {
            DriverStation.reportWarning(
                    "PathPlanner attempted to create a condition '"
                            + name
                            + "' that has not been registered with NamedConditions.registerCondition",
                    false);
            return () -> false;
        }
    }
}