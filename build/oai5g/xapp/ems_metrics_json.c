/*
 * Telemetry envelope serializer of the EMS metrics xApp.
 *
 * All JSON syntax is produced by Cesanta Frozen; this module only owns the
 * growable buffer the document is accumulated in and the unix datagram
 * transport the EMS agent reads from.
 *
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "ems_metrics_json.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

// The largest envelope the xApp may emit. It must stay below the receive
// buffer the EMS agent configures on its unixgram socket.
#define EMS_JSON_MAX_DATAGRAM (256 * 1024)

void ems_json_init(ems_json_writer_t *w)
{
  memset(w, 0, sizeof(*w));
}

void ems_json_free(ems_json_writer_t *w)
{
  free(w->buf);
  memset(w, 0, sizeof(*w));
}

void ems_json_clear(ems_json_writer_t *w)
{
  w->len = 0;
  if (w->buf)
    w->buf[0] = '\0';
}

// Frozen's printer callback: append a chunk, growing the buffer as needed.
// Returning a value smaller than len stops Frozen, so an allocation failure
// makes the whole document short instead of silently truncating it.
static int ems_json_printer(struct json_out *out, const char *str, size_t len)
{
  ems_json_writer_t *w = (ems_json_writer_t *)out;
  if (ems_json_reserve(w, len) != 0)
    return -1;
  memcpy(w->buf + w->len, str, len);
  w->len += len;
  return (int)len;
}

int ems_json_reserve(ems_json_writer_t *w, size_t extra)
{
  if (w->len + extra + 1 <= w->cap)
    return 0;
  size_t cap = w->cap ? w->cap : 4096;
  while (w->len + extra + 1 > cap) {
    if (cap > (SIZE_MAX / 2))
      return -1;
    cap *= 2;
  }
  char *grown = realloc(w->buf, cap);
  if (!grown) {
    // The xApp must stay alive for the RAN; give up on this document instead
    // of aborting the process.
    fprintf(stderr, "ems-metrics: out of memory growing json buffer\n");
    return -1;
  }
  w->buf = grown;
  w->cap = cap;
  return 0;
}

int ems_json_printf(ems_json_writer_t *w, const char *fmt, ...)
{
  // The writer is initialised lazily so callers never have to.
  if (!w->cap) {
    if (ems_json_reserve(w, 4096) != 0)
      return -1;
    w->out.printer = ems_json_printer;
    w->out.u.data = w;
    w->buf[0] = '\0';
  }

  va_list ap;
  va_start(ap, fmt);
  // Frozen returns the number of bytes the format string yields, even when
  // the printer rejects them. A document that does not fit the datagram limit
  // is reported to the caller so it can be dropped rather than split.
  int n = json_vprintf(&w->out, fmt, ap);
  va_end(ap);

  if (n > 0 && w->buf)
    w->buf[w->len] = '\0';
  return n;
}

int ems_json_send_uds(const ems_json_writer_t *w, const char *socket_path)
{
  if (!socket_path || !socket_path[0])
    return -1;
  if (!w->buf || w->len == 0)
    return -1;
  if (w->len > EMS_JSON_MAX_DATAGRAM) {
    fprintf(stderr, "ems-metrics: envelope %zu bytes exceeds datagram limit\n", w->len);
    return -1;
  }

  int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  if (fd < 0)
    return -1;

  // Keep the whole document inside the socket buffers so the EMS agent, which
  // reads with a bounded buffer, never receives a truncated envelope.
  int const buf_size = (int)EMS_JSON_MAX_DATAGRAM;
  setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &buf_size, sizeof(buf_size));

  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  if (strlen(socket_path) >= sizeof(addr.sun_path)) {
    close(fd);
    return -1;
  }
  snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", socket_path);

  ssize_t sent = sendto(fd, w->buf, w->len, 0, (struct sockaddr *)&addr, sizeof(addr));
  close(fd);
  return sent == (ssize_t)w->len ? 0 : -1;
}
