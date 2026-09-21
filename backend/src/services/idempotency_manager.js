/**
 * ZYRO Idempotency Manager
 * 
 * Provides deduplication for critical mutations (create ride, accept ride, cancel ride).
 * Stores cached response fingerprints with TTL to safely handle client retries.
 */

class IdempotencyManager {
  constructor(defaultTtlMs = 86400000) { // 24 hours default TTL
    this.store = new Map();
    this.defaultTtlMs = defaultTtlMs;
  }

  /**
   * Generates a composite cache key.
   */
  _formatKey(scope, key) {
    return `${scope}:${key}`;
  }

  /**
   * Checks if an idempotency key is already stored and still valid.
   */
  get(scope, key) {
    if (!key) return null;
    const fullKey = this._formatKey(scope, key);
    const entry = this.store.get(fullKey);

    if (!entry) return null;

    if (Date.now() > entry.expiresAt) {
      this.store.delete(fullKey);
      return null;
    }

    return entry.result;
  }

  /**
   * Saves a mutation result with an idempotency key.
   */
  set(scope, key, result, ttlMs = this.defaultTtlMs) {
    if (!key) return;
    const fullKey = this._formatKey(scope, key);
    
    this.store.set(fullKey, {
      result,
      savedAt: Date.now(),
      expiresAt: Date.now() + ttlMs,
    });
  }

  /**
   * Executes a mutation wrapped in an idempotency check.
   */
  async executeIdempotent(scope, key, mutationFn) {
    if (!key) {
      // No idempotency key provided - execute directly
      return await mutationFn();
    }

    const cached = this.get(scope, key);
    if (cached) {
      return {
        ...cached,
        isIdempotentReplay: true,
      };
    }

    const result = await mutationFn();
    this.set(scope, key, result);

    return {
      ...result,
      isIdempotentReplay: false,
    };
  }

  /**
   * Cleanup expired keys (runs periodically).
   */
  purgeExpired() {
    const now = Date.now();
    for (const [key, entry] of this.store.entries()) {
      if (now > entry.expiresAt) {
        this.store.delete(key);
      }
    }
  }

  clear() {
    this.store.clear();
  }
}

module.exports = {
  IdempotencyManager,
};
