package com.aritxonly.hyperpiliplus;

public final class FlutterBackdropGeometryTest {
    public static void main(String[] args) {
        int cropOrigin = Integer.parseInt(args[0]);
        int cropExtent = Integer.parseInt(args[1]);
        int barOrigin = Integer.parseInt(args[2]);
        int barExtent = Integer.parseInt(args[3]);
        int expected = Integer.parseInt(args[4]);
        int offset = FlutterBackdropGeometry.alignmentOffset(
                cropOrigin, cropExtent, barOrigin, barExtent);
        if (offset != expected) throw new AssertionError("Expected " + expected + ", got " + offset);

        // Simulate the centered Compose source, then check several sampled pixels
        // land at their original window positions (within integer pixel rounding).
        float drawnOrigin = barOrigin + (barExtent - cropExtent) / 2f + offset;
        for (int sample : new int[]{0, cropExtent / 4, cropExtent - 1}) {
            float error = Math.abs((drawnOrigin + sample) - (cropOrigin + sample));
            if (error > 0.5f) throw new AssertionError("Sample shifted by " + error + " px");
        }
    }
}
