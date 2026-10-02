/*
 * mxl.c
 *
 * Read the score from a compressed MusicXML (.mxl) file
 *
 * for Denemo, a gtk+ frontend to GNU Lilypond
 * (C)  2026 Jeremiah Benham
 *
 * License: this file may be used under the FSF GPL version 3 or later
 */

#include "mxl.h"
#include <string.h>
#include <gio/gio.h>
#include <glib/gstdio.h>

#define MXL_ERROR (g_quark_from_static_string ("denemo-mxl-error"))
#define MXL_MAX_UNCOMPRESSED (512 * 1024 * 1024)    /* guard against zip bombs */

#define SIG_LOCAL   0x04034b50
#define SIG_CENTRAL 0x02014b50
#define SIG_EOCD    0x06054b50

static guint16
rd16 (const guchar * p)
{
  return p[0] | (p[1] << 8);
}

static guint32
rd32 (const guchar * p)
{
  return p[0] | (p[1] << 8) | (p[2] << 16) | ((guint32) p[3] << 24);
}

typedef struct
{
  gchar *name;
  guint16 method;
  guint16 flags;
  guint32 csize, usize, offset;
} ZipEntry;

static void
zip_entries_free (GArray * entries)
{
  for (guint i = 0; i < entries->len; i++)
    g_free (g_array_index (entries, ZipEntry, i).name);
  g_array_free (entries, TRUE);
}

/* Parse the central directory. Returns NULL (and sets error) on failure. */
static GArray *
zip_read_directory (const guchar * buf, gsize len, GError ** error)
{
  if (len < 22)
    {
      g_set_error (error, MXL_ERROR, 1, "File too small to be a zip archive");
      return NULL;
    }

  /* End-of-central-directory record: scan backwards (it may be followed by a comment) */
  gssize eocd = -1;
  gsize lowest = len > 22 + 65535 ? len - 22 - 65535 : 0;
  for (gssize i = len - 22; i >= (gssize) lowest; i--)
    if (rd32 (buf + i) == SIG_EOCD)
      {
        eocd = i;
        break;
      }
  if (eocd < 0)
    {
      g_set_error (error, MXL_ERROR, 2, "Not a zip archive (no end-of-directory record)");
      return NULL;
    }

  guint16 count = rd16 (buf + eocd + 10);
  guint32 cd_offset = rd32 (buf + eocd + 16);
  if (cd_offset >= len)
    {
      g_set_error (error, MXL_ERROR, 3, "Corrupt zip directory offset (zip64 is not supported)");
      return NULL;
    }

  GArray *entries = g_array_new (FALSE, TRUE, sizeof (ZipEntry));
  gsize pos = cd_offset;
  for (guint i = 0; i < count; i++)
    {
      if (pos + 46 > len || rd32 (buf + pos) != SIG_CENTRAL)
        {
          g_set_error (error, MXL_ERROR, 4, "Corrupt zip central directory");
          zip_entries_free (entries);
          return NULL;
        }
      guint16 nlen = rd16 (buf + pos + 28), elen = rd16 (buf + pos + 30), clen = rd16 (buf + pos + 32);
      if (pos + 46 + nlen > len)
        {
          g_set_error (error, MXL_ERROR, 4, "Corrupt zip central directory");
          zip_entries_free (entries);
          return NULL;
        }
      ZipEntry e;
      e.flags = rd16 (buf + pos + 8);
      e.method = rd16 (buf + pos + 10);
      e.csize = rd32 (buf + pos + 20);
      e.usize = rd32 (buf + pos + 24);
      e.offset = rd32 (buf + pos + 42);
      e.name = g_strndup ((const gchar *) buf + pos + 46, nlen);
      g_strdelimit (e.name, "\\", '/');
      g_array_append_val (entries, e);
      pos += 46 + nlen + elen + clen;
    }
  return entries;
}

static ZipEntry *
zip_find (GArray * entries, const gchar * name)
{
  for (guint i = 0; i < entries->len; i++)
    {
      ZipEntry *e = &g_array_index (entries, ZipEntry, i);
      if (g_strcmp0 (e->name, name) == 0)
        return e;
    }
  return NULL;
}

/* Inflate/copy one entry. Result is NUL-terminated. */
static gchar *
zip_extract (const guchar * buf, gsize len, const ZipEntry * e, gsize * out_len, GError ** error)
{
  if (e->flags & 1)
    {
      g_set_error (error, MXL_ERROR, 5, "Encrypted entries are not supported: %s", e->name);
      return NULL;
    }
  /* local header gives its own name/extra lengths, which can differ from the central directory */
  if ((gsize) e->offset + 30 > len || rd32 (buf + e->offset) != SIG_LOCAL)
    {
      g_set_error (error, MXL_ERROR, 6, "Corrupt local header for %s", e->name);
      return NULL;
    }
  gsize data_start = (gsize) e->offset + 30 + rd16 (buf + e->offset + 26) + rd16 (buf + e->offset + 28);
  if (data_start > len || e->csize > len - data_start)
    {
      g_set_error (error, MXL_ERROR, 6, "Truncated data for %s", e->name);
      return NULL;
    }
  const guchar *src = buf + data_start;

  if (e->method == 0)
    {
      gchar *out = g_malloc (e->csize + 1);
      memcpy (out, src, e->csize);
      out[e->csize] = 0;
      *out_len = e->csize;
      return out;
    }
  if (e->method != 8)
    {
      g_set_error (error, MXL_ERROR, 7, "Unsupported compression method %d for %s", e->method, e->name);
      return NULL;
    }

  GInputStream *mem = g_memory_input_stream_new_from_data (src, e->csize, NULL);
  GZlibDecompressor *dec = g_zlib_decompressor_new (G_ZLIB_COMPRESSOR_FORMAT_RAW);
  GInputStream *conv = g_converter_input_stream_new (mem, G_CONVERTER (dec));
  GByteArray *out = g_byte_array_new ();
  guchar chunk[16384];
  gssize n;
  GError *err = NULL;

  while ((n = g_input_stream_read (conv, chunk, sizeof chunk, NULL, &err)) > 0)
    {
      if (out->len + n > MXL_MAX_UNCOMPRESSED)
        {
          g_set_error (&err, MXL_ERROR, 8, "Entry %s is unreasonably large", e->name);
          n = -1;
          break;
        }
      g_byte_array_append (out, chunk, n);
    }
  g_object_unref (conv);
  g_object_unref (dec);
  g_object_unref (mem);

  if (n < 0)
    {
      g_propagate_error (error, err);
      g_byte_array_free (out, TRUE);
      return NULL;
    }
  *out_len = out->len;
  guchar zero = 0;
  g_byte_array_append (out, &zero, 1);
  return (gchar *) g_byte_array_free (out, FALSE);
}

/* ---- META-INF/container.xml: pick the first <rootfile full-path="..."/> ---- */

typedef struct
{
  gchar *full_path;
} ContainerData;

static void
container_start (GMarkupParseContext * ctx, const gchar * element, const gchar ** names, const gchar ** values, gpointer user_data, GError ** error)
{
  ContainerData *cd = user_data;
  if (cd->full_path || g_strcmp0 (element, "rootfile") != 0)
    return;
  for (gint i = 0; names[i]; i++)
    if (g_strcmp0 (names[i], "full-path") == 0)
      cd->full_path = g_strdup (values[i]);
}

static gchar *
parse_container (const gchar * xml, gsize len)
{
  ContainerData cd = { NULL };
  GMarkupParser parser = { container_start, NULL, NULL, NULL, NULL };
  GMarkupParseContext *ctx = g_markup_parse_context_new (&parser, 0, &cd, NULL);
  g_markup_parse_context_parse (ctx, xml, len, NULL);   /* ignore errors: we only need the first rootfile */
  g_markup_parse_context_free (ctx);
  return cd.full_path;
}

static gboolean
looks_like_score_name (const gchar * name)
{
  if (g_str_has_prefix (name, "META-INF/"))
    return FALSE;
  return g_str_has_suffix (name, ".xml") || g_str_has_suffix (name, ".musicxml");
}

gboolean
mxl_file_is_zip (const gchar * filename)
{
  FILE *f = g_fopen (filename, "rb");
  if (!f)
    return FALSE;
  guchar magic[4];
  gboolean result = (fread (magic, 1, 4, f) == 4 && rd32 (magic) == SIG_LOCAL);
  fclose (f);
  return result;
}

gchar *
mxl_extract_score (const gchar * filename, gsize * length, GError ** error)
{
  gchar *contents = NULL;
  gsize len = 0;
  if (!g_file_get_contents (filename, &contents, &len, error))
    return NULL;

  const guchar *buf = (const guchar *) contents;
  GArray *entries = zip_read_directory (buf, len, error);
  if (!entries)
    {
      g_free (contents);
      return NULL;
    }

  gchar *root_name = NULL;
  ZipEntry *container = zip_find (entries, "META-INF/container.xml");
  if (container)
    {
      gsize clen;
      gchar *cxml = zip_extract (buf, len, container, &clen, NULL);
      if (cxml)
        {
          root_name = parse_container (cxml, clen);
          g_free (cxml);
        }
    }

  ZipEntry *root = root_name ? zip_find (entries, root_name) : NULL;
  if (!root)
    {
      /* no usable container.xml: fall back to the first plausible .xml/.musicxml entry */
      for (guint i = 0; i < entries->len && !root; i++)
        {
          ZipEntry *e = &g_array_index (entries, ZipEntry, i);
          if (looks_like_score_name (e->name))
            root = e;
        }
    }

  gchar *result = NULL;
  if (!root)
    g_set_error (error, MXL_ERROR, 9, "No MusicXML score found in %s", filename);
  else
    result = zip_extract (buf, len, root, length, error);

  g_free (root_name);
  zip_entries_free (entries);
  g_free (contents);
  return result;
}
