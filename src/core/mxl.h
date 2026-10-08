/* mxl.h
 * Read the score out of a compressed MusicXML (.mxl) file.
 *
 * A .mxl file is a ZIP archive. META-INF/container.xml names the root
 * MusicXML file inside the archive. This needs only GLib/GIO (no libzip).
 */
#ifndef DENEMO_MXL_H
#define DENEMO_MXL_H

#include <glib.h>

/* TRUE if the file starts with a ZIP local-file-header signature ("PK\3\4") */
gboolean mxl_file_is_zip (const gchar * filename);

/**
 * Extract the root MusicXML document from a .mxl archive.
 *
 * @param filename  path of the .mxl file
 * @param length    (out) size in bytes of the returned data
 * @param error     (out, optional) set on failure
 * @return newly allocated buffer (free with g_free) holding the uncompressed
 *         MusicXML, or NULL on failure. Pass to xmlReadMemory().
 */
gchar *mxl_extract_score (const gchar * filename, gsize * length, GError ** error);

#endif
