/**
 * ZYRO Server-Side 120-Second Timeout Scheduler
 * 
 * Runs autonomous background timeout handlers independent of client Flutter lifecycle
 * or WebSocket connection state. Ensures deterministic backup-driver assignment upon 120s expiry.
 */

class TimeoutScheduler {
  constructor() {
    this.activeTimers = new Map(); // rideId -> Timer
  }

  /**
   * Schedules a 120-second allocation timeout for a ride.
   */
  scheduleAllocationTimeout(rideId, {
    durationMs = 120000, // 120 seconds default
    onExpire,
  }) {
    this.cancelAllocationTimeout(rideId);

    const timer = setTimeout(async () => {
      this.activeTimers.delete(rideId);
      try {
        if (typeof onExpire === 'function') {
          await onExpire(rideId);
        }
      } catch (err) {
        console.error(`[TimeoutScheduler] Error executing expiry for ride ${rideId}:`, err);
      }
    }, durationMs);

    this.activeTimers.set(rideId, {
      timer,
      scheduledAt: Date.now(),
      expiresAt: Date.now() + durationMs,
    });

    return timer;
  }

  /**
   * Cancels a pending timeout when a ride is accepted or cancelled before 120s.
   */
  cancelAllocationTimeout(rideId) {
    const record = this.activeTimers.get(rideId);
    if (record) {
      clearTimeout(record.timer);
      this.activeTimers.delete(rideId);
      return true;
    }
    return false;
  }

  /**
   * Returns remaining seconds for a scheduled ride.
   */
  getRemainingSeconds(rideId) {
    const record = this.activeTimers.get(rideId);
    if (!record) return 0;
    const remainingMs = Math.max(0, record.expiresAt - Date.now());
    return Math.ceil(remainingMs / 1000);
  }

  hasActiveTimeout(rideId) {
    return this.activeTimers.has(rideId);
  }

  clear() {
    for (const [rideId, record] of this.activeTimers.entries()) {
      clearTimeout(record.timer);
    }
    this.activeTimers.clear();
  }
}

module.exports = {
  TimeoutScheduler,
};
