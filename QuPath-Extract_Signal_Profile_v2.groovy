/*
Intensity line profile with direction and multiple thicknesses

This script extracts intensity profiles along a 'Pole to Pole' arrow annotation,
measuring intensity averaged across two different thicknesse line annotations ("Small metaphase width" and "Big metaphase width").
It also includes background signal values per channel, and outputs results in CSV format
with pixel spacing and image resolution for context.

Exports include:
- Distance (in µm) from the origin (intersection of width lines)
- Channel intensities averaged across the thickness
- Background values per channel
- Thickness, pixel spacing, and image resolution

Author: Nicolas Liaudet (Bioimaging Core Facility, University of Geneva)
License: CC BY-NC 4.0
Tested in: QuPath 0.5.2
Version: v2.2 - 03-Jun-2025
*/

// === Imports ===
import qupath.lib.roi.LineROI // For manipulating and extracting coordinates from line annotations
import qupath.lib.regions.RegionRequest // For defining regions to read from the image
import java.awt.image.BufferedImage // For raw image access
import java.util.Locale // For locale-aware formatting
import java.nio.file.Paths // For output path
import java.nio.file.Files // For writing to disk
import java.nio.charset.StandardCharsets // For character encoding

// === Parameters ===
double pixelSpacingMicrons = 0.05  // spacing of profile sampling in µm
String delimiter = ";"             // CSV delimiter. Change to "\t" or "," if needed

def imageData = getCurrentImageData()
def server = imageData.getServer()
def channels = server.getMetadata().getChannels().collect { it.getName() }
def pxSize = server.getPixelCalibration().getAveragedPixelSizeMicrons()

print "============================================"
print "Processing "+server.getMetadata().getName()
// === Project directory for output ===
def basePath = buildFilePath(PROJECT_BASE_DIR, 'measurements')
Files.createDirectories(Paths.get(basePath))

// === Annotations ===
def arrowAnno = getAnnotationObjects().find { it.getPathClass() == getPathClass("Pole to Pole") }
if (arrowAnno == null) {
    print "⚠ No 'Pole to Pole' arrow annotation found. Aborting."
    return
}

def thicknessLines = getAnnotationObjects().findAll {
    it.getPathClass() == getPathClass("Big metaphase width") ||
    it.getPathClass() == getPathClass("Small metaphase width")
}

def backgroundAnno = getAnnotationObjects().find { it.getPathClass() == getPathClass("Background") }

def arrow = arrowAnno.getROI() as LineROI
def ax1 = arrow.getX1(), ay1 = arrow.getY1(), ax2 = arrow.getX2(), ay2 = arrow.getY2()
def adx = ax2 - ax1, ady = ay2 - ay1
def arrowLength = Math.hypot(adx, ady)
def nx = adx / arrowLength, ny = ady / arrowLength
def perpX = -ny, perpY = nx

// Solves for the intersection point using parametric line equations
// Returns [x, y] or null if lines are parallel (denom == 0)
def findIntersection = { LineROI l ->
    def x1 = l.getX1(), y1 = l.getY1(), x2 = l.getX2(), y2 = l.getY2()
    def dx1 = ax2 - ax1, dy1 = ay2 - ay1
    def dx2 = x2 - x1, dy2 = y2 - y1
    def denom = dx1 * dy2 - dy1 * dx2
    if (denom == 0) return null //lines are parallel
    // ua: distance along the arrow where the intersection occurs
    def ua = ((x2 - ax1) * dy2 - (y2 - ay1) * dx2) / denom
    return [ax1 + ua * dx1, ay1 + ua * dy1]
}

def intersections
if (thicknessLines) {
    intersections= thicknessLines.take(2).collect { findIntersection(it.getROI() as LineROI) }
    if (intersections.any { it == null }) {
        print "⚠ Could not determine intersection(s). Using arrow start point as origin."
        intersections = [[ax1, ay1]]
    }
} else {
    print "⚠ No thickness lines provided. Using arrow start point as origin."
    intersections = [[ax1, ay1],[ax1, ay1]] 
}

def originX = intersections.collect { it[0] }.sum() / intersections.size()
def originY = intersections.collect { it[1] }.sum() / intersections.size()
def origin = [originX, originY]

def thicknessesMicrons = thicknessLines.collect {
    def roi = it.getROI() as LineROI
    Math.hypot(roi.getX2() - roi.getX1(), roi.getY2() - roi.getY1()) * pxSize
}
if (thicknessesMicrons.size() < 2) {
    if (thicknessesMicrons.size() == 1)
        thicknessesMicrons.add(thicknessesMicrons[0])
    else
        thicknessesMicrons = [0, 1.0]
}

// === Extract background ===
def backgroundMeans = channels.collect { c -> 0.0 }
if (backgroundAnno != null) {
    def req = RegionRequest.createInstance(server.getPath(), 1, backgroundAnno.getROI())
    def img = server.readBufferedImage(req)
    def raster = img.getRaster()
    def w = raster.getWidth(), h = raster.getHeight()
    def count = w * h
    for (int c = 0; c < channels.size(); c++) {
        double sum = 0
        for (int x = 0; x < w; x++) for (int y = 0; y < h; y++) sum += raster.getSample(x, y, c)
        backgroundMeans[c] = sum / count
    }
} else {
    backgroundMeans = channels.collect { 0.0 }
    print "⚠ No background annotation found. Defaulting to 0."
}

/*
 * Extracts a line profile along the arrow annotation, sampling intensity values at regular intervals
 * and averaging across a given thickness perpendicular to the arrow direction.
 *
 * For each point:
 * - Computes the physical distance from the defined origin along the arrow.
 * - Samples intensity values across the thickness using bilinear interpolation.
 * - Averages values for each channel.
 * - Writes results as CSV with distance, per-channel intensity, background, thickness, spacing, and resolution.
 *
 * @param thicknessMicrons  Thickness (in µm) across which intensities are averaged
 * @param suffix            Used to name the output CSV
 */
def getProfile = { double thicknessMicrons, String suffix ->
    int thicknessPx = Math.max(1, Math.round(thicknessMicrons / pxSize))
    int spacingPx = Math.max(1, Math.round(pixelSpacingMicrons / pxSize))

    int pad = thicknessPx / 2 + 2
    int minX = (int)Math.floor(Math.min(ax1, ax2) - pad)
    int minY = (int)Math.floor(Math.min(ay1, ay2) - pad)
    int maxX = (int)Math.ceil(Math.max(ax1, ax2) + pad)
    int maxY = (int)Math.ceil(Math.max(ay1, ay2) + pad)

    def region = RegionRequest.createInstance(server.getPath(), 1, minX, minY, maxX - minX, maxY - minY)
    BufferedImage img = server.readBufferedImage(region)
    def raster = img.getRaster()

    /*
     * Performs bilinear interpolation to estimate pixel intensity at sub-pixel position (x, y)
     * for channel c. This is done by computing a weighted sum of the four surrounding pixel
     * values based on their proximity to (x, y).
    */
    def getSample = { double x, double y, int c ->
        x -= minX; y -= minY
        int x0 = (int)Math.floor(x), y0 = (int)Math.floor(y)
        int x1 = x0 + 1, y1 = y0 + 1
        if (x0 < 0 || y0 < 0 || x1 >= raster.getWidth() || y1 >= raster.getHeight()) return 0
        double dx = x - x0, dy = y - y0
        return (1 - dx) * (1 - dy) * raster.getSample(x0, y0, c) +
               dx * (1 - dy) * raster.getSample(x1, y0, c) +
               (1 - dx) * dy * raster.getSample(x0, y1, c) +
               dx * dy * raster.getSample(x1, y1, c)
    }

    def csv = new StringBuilder()
    def bgHeaders = channels.collect { "Background ${it}" }
    csv.append("Distance (µm)").append(delimiter)
    csv.append(channels.join(";")).append(delimiter)
    csv.append(bgHeaders.join(";")).append(delimiter)
    csv.append("Thickness (µm)").append(delimiter)
    csv.append("Pixel spacing (µm)").append(delimiter)   
    csv.append("Image resolution (µm)").append("\n")

    int steps = (int)(arrowLength / spacingPx)
    for (int i = 0; i <= steps; i++) {
        double t = i * spacingPx
        double cx = ax1 + nx * t
        double cy = ay1 + ny * t
        double dist = ((cx - origin[0]) * nx + (cy - origin[1]) * ny) * pxSize

        def vals = new double[channels.size()]
        int count = 0
        for (int j = -thicknessPx / 2; j <= thicknessPx / 2; j++) {
            double px = cx + j * perpX
            double py = cy + j * perpY
            for (int c = 0; c < channels.size(); c++)
                vals[c] += getSample(px, py, c)
            count++
        }
        for (int c = 0; c < channels.size(); c++)
            vals[c] /= count

        csv.append(String.format(Locale.US, "%.2f", dist)).append(delimiter)
        csv.append(vals.collect { String.format(Locale.US, "%.2f", it) }.join(delimiter)).append(delimiter)
        csv.append(backgroundMeans.collect { String.format(Locale.US, "%.2f", it) }.join(delimiter)).append(delimiter)
        csv.append(String.format(Locale.US, "%.2f"+delimiter+"%.3f"+delimiter+"%.3f", thicknessMicrons, pixelSpacingMicrons, pxSize)).append("\n")
        
    }

    def fileName = server.getMetadata().getName().replaceFirst('(?i)\\.tif(f)?$', '') + "_${suffix}.csv"
    def outFile = Paths.get(basePath, fileName)
    Files.write(outFile, csv.toString().getBytes(StandardCharsets.UTF_8))
    print "✅ Exported: ${outFile}"
}

getProfile(thicknessesMicrons[0], "small")
getProfile(thicknessesMicrons[1], "big")
