-- Login rate-limit buckets. Shared across isolates, unlike Worker memory.
CREATE TABLE IF NOT EXISTS login_attempts (
  bucket_key TEXT PRIMARY KEY,
  attempt_count INTEGER NOT NULL,
  reset_at INTEGER NOT NULL
);
