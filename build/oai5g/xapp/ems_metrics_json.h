/*
 * Telemetry envelope serializer of the EMS metrics xApp.
 *
 * JSON generation is delegated to the Cesanta Frozen library (vendored under
 * frozen/, Apache 2.0). Frozen is a battle-tested printf-style JSON emitter:
 * it escapes strings, places every separator itself and rejects malformed
 * format strings, so the ~150 fields of the NR envelope are written
 * declaratively instead of through a hand-rolled state machine.
 *
 * The document is accumulated in a heap buffer that grows on demand and is
 * delivered as a single unix datagram to the socket the EMS agent listens on.
 * Datagrams that do not fit the socket buffers are refused rather than
 * truncated, so the EMS agent never parses a partial document.
 *
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#ifndef EMS_METRICS_JSON_H
#define EMS_METRICS_JSON_H

#include <stddef.h>
#include <stdint.h>

#include "frozen/frozen.h"

typedef struct {
  // Growable destination of the json_printf output. Frozen reports how many
  // bytes a format string yields before printing them, which is used here to
  // size the buffer ahead of every write.
  struct json_out out;
  char *buf;
  size_t len;
  size_t cap;
} ems_json_writer_t;

// ems_json_reserve makes room for at least extra more bytes. Frozen's printer
// callback is not allowed to fail silently: a failed allocation aborts the
// whole document, which the caller drops instead of the process.
void ems_json_init(ems_json_writer_t *w);
void ems_json_free(ems_json_writer_t *w);
void ems_json_clear(ems_json_writer_t *w);
int ems_json_reserve(ems_json_writer_t *w, size_t extra);

// ems_json_printf forwards to Frozen, which extends printf with JSON-specific
// specifiers (%Q escaped string, %B boolean, %M nested callback, plus the
// plain %d/%u/%f/%s ones), so the compiler's format checker does not apply
// here. It returns the number of bytes the format string produces; a value
// greater than the room left means the document does not fit and is dropped.
int ems_json_printf(ems_json_writer_t *w, const char *fmt, ...);

// ems_json_send_uds delivers the document as one unix datagram to the socket
// the EMS agent is listening on.
int ems_json_send_uds(const ems_json_writer_t *w, const char *socket_path);

#endif // EMS_METRICS_JSON_H
