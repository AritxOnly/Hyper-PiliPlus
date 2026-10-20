package com.aritxonly.hyperpiliplus;

/** Coordinates for a cropped Flutter Surface behind a centered glass consumer. */
final class FlutterBackdropGeometry {
    private FlutterBackdropGeometry() {}

    /** Both origins must be in window pixels, including the SurfaceView's window offset. */
    static int alignmentOffset(int cropOrigin, int cropExtent, int barOrigin, int barExtent) {
        return Math.round((cropOrigin - barOrigin) + (cropExtent - barExtent) / 2f);
    }
}
