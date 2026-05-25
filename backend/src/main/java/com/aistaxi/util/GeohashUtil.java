package com.aistaxi.util;

/**
 * Pure-Java geohash encoder/decoder.
 * Precision 6 gives ~1.2km x 0.6km cells — suitable for taxi demand heatmap.
 */
public class GeohashUtil {

    private static final String BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
    private static final int DEFAULT_PRECISION = 6;

    /**
     * Encode lat/lon to a geohash string at default precision (6).
     */
    public static String encode(double lat, double lon) {
        return encode(lat, lon, DEFAULT_PRECISION);
    }

    /**
     * Encode lat/lon to a geohash string at specified precision.
     */
    public static String encode(double lat, double lon, int precision) {
        double latMin = -90.0, latMax = 90.0;
        double lonMin = -180.0, lonMax = 180.0;
        boolean isLon = true;
        int bit = 0;
        int charIndex = 0;
        StringBuilder geohash = new StringBuilder();

        while (geohash.length() < precision) {
            if (isLon) {
                double mid = (lonMin + lonMax) / 2;
                if (lon >= mid) {
                    charIndex |= (1 << (4 - bit));
                    lonMin = mid;
                } else {
                    lonMax = mid;
                }
            } else {
                double mid = (latMin + latMax) / 2;
                if (lat >= mid) {
                    charIndex |= (1 << (4 - bit));
                    latMin = mid;
                } else {
                    latMax = mid;
                }
            }

            isLon = !isLon;
            bit++;

            if (bit == 5) {
                geohash.append(BASE32.charAt(charIndex));
                bit = 0;
                charIndex = 0;
            }
        }

        return geohash.toString();
    }

    /**
     * Decode a geohash to its center lat/lon.
     * Returns double[2] = {lat, lon}.
     */
    public static double[] decode(String geohash) {
        double latMin = -90.0, latMax = 90.0;
        double lonMin = -180.0, lonMax = 180.0;
        boolean isLon = true;

        for (int i = 0; i < geohash.length(); i++) {
            int charIndex = BASE32.indexOf(geohash.charAt(i));
            for (int bit = 4; bit >= 0; bit--) {
                if (isLon) {
                    double mid = (lonMin + lonMax) / 2;
                    if (((charIndex >> bit) & 1) == 1) {
                        lonMin = mid;
                    } else {
                        lonMax = mid;
                    }
                } else {
                    double mid = (latMin + latMax) / 2;
                    if (((charIndex >> bit) & 1) == 1) {
                        latMin = mid;
                    } else {
                        latMax = mid;
                    }
                }
                isLon = !isLon;
            }
        }

        return new double[] { (latMin + latMax) / 2, (lonMin + lonMax) / 2 };
    }
}
