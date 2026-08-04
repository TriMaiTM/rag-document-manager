# Background document processing

Codexys uses Active Job with Solid Queue for PDF extraction, chunking, and
embedding. The web request only saves the upload and enqueues a document ID.
The worker loads that document and calls `Documents::ProcessDocument`.

## Development

Prepare both the application and queue databases:

```bash
bin/rails db:prepare
```

`bin/dev` starts Puma. Puma also starts Solid Queue in development, so queued
documents continue through the `documents` queue without an extra terminal.

To run the worker separately instead, use two terminals:

```bash
SOLID_QUEUE_IN_PUMA=false bin/dev
bin/jobs
```

## Test and production

Tests use Active Job's `:test` adapter. They never start a real worker or call
Gemini unless a test explicitly provides a fake client.

Production uses the dedicated `queue` database configured in
`config/database.yml`. Run `bin/rails db:prepare` during deployment and start
the worker with `bin/jobs` or set `SOLID_QUEUE_IN_PUMA=true` for a small,
single-host deployment.

## Failure behavior

- A missing or deleted document is discarded safely.
- Gemini network errors, HTTP 429 responses, and HTTP 5xx responses retry up
  to three executions with polynomial backoff.
- Invalid PDFs and permanent API errors are not retried automatically. Their
  document remains failed and can be retried explicitly from the UI.
