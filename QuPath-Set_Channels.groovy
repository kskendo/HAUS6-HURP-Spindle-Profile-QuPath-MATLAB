/*
 * Set channel names and display ranges for HAUS6/HURP/DAPI images
 *
 * Run this script once per QuPath project to configure channel names
 * and display ranges before drawing annotations or extracting profiles.
 *
 * Channel order:
 *   Channel 1: HAUS6
 *   Channel 2: HURP
 *   Channel 3: DAPI
 *
 * Author: Nicolas Liaudet
 * Bioimaging Core Facility, University of Geneva
 * https://www.unige.ch/medecine/bioimaging/en/bioimaging-core-facility/
 *
 * License: CC BY-NC 4.0
 * Tested in: QuPath 0.5.2
 *
 * Used in: Skendo et al., 2026 (in preparation)
 * Repository: https://github.com/kskendo/HAUS6-HURP-Spindle-Profile-QuPath-MATLAB
 */

setChannelNames("HAUS6","HURP","DAPI")
setChannelDisplayRange(0,7000,30000)
setChannelDisplayRange(1,9000,17000)
setChannelDisplayRange(2,8000,200000)
