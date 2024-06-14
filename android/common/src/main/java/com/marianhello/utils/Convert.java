/*
 * Kindly taken from
 * http://stackoverflow.com/questions/1590831/safely-casting-long-to-int-in-java
 */

package com.marianhello.utils;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

import android.os.Bundle;

public class Convert {

    public static int safeLongToInt(long l) {
        if (l < Integer.MIN_VALUE || l > Integer.MAX_VALUE) {
            throw new IllegalArgumentException(l + " cannot be cast to int without changing its value.");
        }
        return (int) l;
    }

    public static Map<String, Object> toMap(JSONObject jsonobj) throws JSONException {
        Map<String, Object> map = new HashMap<String, Object>();
        Iterator<String> keys = jsonobj.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = jsonobj.get(key);
            if (value instanceof JSONArray) {
                value = toList((JSONArray) value);
            } else if (value instanceof JSONObject) {
                value = toMap((JSONObject) value);
            }
            map.put(key, value);
        }
        return map;
    }

    public static List<Object> toList(JSONArray array) throws JSONException {
        List<Object> list = new ArrayList<Object>();
        for (int i = 0; i < array.length(); i++) {
            Object value = array.get(i);
            if (value instanceof JSONArray) {
                value = toList((JSONArray) value);
            } else if (value instanceof JSONObject) {
                value = toMap((JSONObject) value);
            }
            list.add(value);
        }
        return list;
    }

    /**
     * Convert location.extras bundle to json object:
     * https://stackoverflow.com/a/69392840
     * 
     * @param bundle extras Bundle to convert
     *               Returns location.extras Bundle as JSON object.
     * @throws JSONException
     */
    public static JSONObject convertBundleToJson(Bundle bundle) {
        JSONObject json = new JSONObject();
        if (bundle != null && bundle) {
            Set<String> keys = bundle.keySet();

            for (String key : keys) {
                try {
                    if (bundle.get(key) != null && bundle.get(key).getClass().getName().equals("android.os.Bundle")) {
                        Bundle nestedBundle = (Bundle) bundle.get(key);
                        json.put(key, convertBundleToJson(nestedBundle));
                    } else {
                        json.put(key, JSONObject.wrap(bundle.get(key)));
                    }
                } catch (JSONException e) {
                    System.out.println(e.toString());
                }
            }    
        }

        return json;
    }

}
