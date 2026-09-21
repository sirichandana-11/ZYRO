/**
 * ZYRO Ride State Machine Engine
 * 
 * Enforces strict, deterministic state transitions for the ride lifecycle.
 * Rejects illegal transitions and maintains an immutable audit trail.
 */

const RideStatus = Object.freeze({
  CREATED: 'CREATED',
  SEARCHING: 'SEARCHING',
  DRIVER_ASSIGNED: 'DRIVER_ASSIGNED',
  DRIVER_ARRIVING: 'DRIVER_ARRIVING',
  RIDE_STARTED: 'RIDE_STARTED',
  COMPLETED: 'COMPLETED',
  CANCELLED: 'CANCELLED',
  NO_DRIVER: 'NO_DRIVER',
});

// Directed Acyclic Graph of legal state transitions
const LEGAL_TRANSITIONS = Object.freeze({
  [RideStatus.CREATED]: [RideStatus.SEARCHING, RideStatus.CANCELLED],
  [RideStatus.SEARCHING]: [RideStatus.DRIVER_ASSIGNED, RideStatus.NO_DRIVER, RideStatus.CANCELLED],
  [RideStatus.DRIVER_ASSIGNED]: [RideStatus.DRIVER_ARRIVING, RideStatus.CANCELLED],
  [RideStatus.DRIVER_ARRIVING]: [RideStatus.RIDE_STARTED, RideStatus.CANCELLED],
  [RideStatus.RIDE_STARTED]: [RideStatus.COMPLETED, RideStatus.CANCELLED],
  [RideStatus.COMPLETED]: [], // Terminal
  [RideStatus.CANCELLED]: [], // Terminal
  [RideStatus.NO_DRIVER]: [], // Terminal
});

class InvalidStateTransitionError extends Error {
  constructor(currentStatus, targetStatus, reason) {
    super(`Illegal ride state transition from '${currentStatus}' to '${targetStatus}'. ${reason || ''}`);
    this.name = 'InvalidStateTransitionError';
    this.currentStatus = currentStatus;
    this.targetStatus = targetStatus;
  }
}

class RideStateMachine {
  /**
   * Validates if a transition from currentStatus to targetStatus is allowed.
   */
  static canTransition(currentStatus, targetStatus) {
    if (!currentStatus || !targetStatus) return false;
    if (currentStatus === targetStatus) return true; // Idempotent same-state no-op

    const allowed = LEGAL_TRANSITIONS[currentStatus];
    if (!allowed) return false;
    return allowed.includes(targetStatus);
  }

  /**
   * Applies a transition to a ride object.
   * Throws InvalidStateTransitionError if transition is illegal.
   */
  static transition(ride, targetStatus, { actorUid, actorRole, reason = null } = {}) {
    if (!ride) {
      throw new Error('Ride record is required for state transition.');
    }

    const currentStatus = ride.status || RideStatus.CREATED;

    // Handle idempotent repeat requests
    if (currentStatus === targetStatus) {
      return {
        ride,
        changed: false,
        message: `Ride is already in state '${targetStatus}'.`,
      };
    }

    if (!this.canTransition(currentStatus, targetStatus)) {
      throw new InvalidStateTransitionError(
        currentStatus,
        targetStatus,
        `Terminal or non-sequential jump attempted by ${actorRole || 'unknown'} (${actorUid || 'unknown'}).`
      );
    }

    const now = new Date();
    const transitionEvent = {
      fromStatus: currentStatus,
      toStatus: targetStatus,
      actorUid: actorUid || 'system',
      actorRole: actorRole || 'system',
      timestamp: now.toISOString(),
      reason,
    };

    // Update ride mutable properties
    ride.status = targetStatus;
    ride.updatedAt = now;
    
    if (targetStatus === RideStatus.DRIVER_ASSIGNED && !ride.assignedAt) {
      ride.assignedAt = now;
    } else if (targetStatus === RideStatus.RIDE_STARTED && !ride.startedAt) {
      ride.startedAt = now;
    } else if (targetStatus === RideStatus.COMPLETED && !ride.completedAt) {
      ride.completedAt = now;
    } else if (targetStatus === RideStatus.CANCELLED && !ride.cancelledAt) {
      ride.cancelledAt = now;
    }

    if (!Array.isArray(ride.auditTrail)) {
      ride.auditTrail = [];
    }
    ride.auditTrail.push(transitionEvent);

    return {
      ride,
      changed: true,
      event: transitionEvent,
    };
  }

  static isTerminal(status) {
    return status === RideStatus.COMPLETED ||
           status === RideStatus.CANCELLED ||
           status === RideStatus.NO_DRIVER;
  }
}

module.exports = {
  RideStatus,
  LEGAL_TRANSITIONS,
  InvalidStateTransitionError,
  RideStateMachine,
};
