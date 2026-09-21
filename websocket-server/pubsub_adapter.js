/**
 * ZYRO Distributed Pub/Sub Adapter Interface
 * 
 * Enables seamless horizontal scaling across multiple WebSocket server instances.
 * - InMemoryPubSubAdapter: Used in local single-instance mode (default).
 * - RedisPubSubAdapter: Plugged in when scaling across multi-node Kubernetes / Cloud Run clusters.
 */

class BasePubSubAdapter {
  async publish(channel, message) {
    throw new Error('publish() must be implemented by adapter.');
  }

  async subscribe(channel, handler) {
    throw new Error('subscribe() must be implemented by adapter.');
  }

  async unsubscribe(channel, handler) {
    throw new Error('unsubscribe() must be implemented by adapter.');
  }
}

/**
 * In-Memory Pub/Sub Adapter (Single-Node / Local Dev)
 */
class InMemoryPubSubAdapter extends BasePubSubAdapter {
  constructor() {
    super();
    this.channels = new Map(); // channel -> Set<handler>
  }

  async publish(channel, message) {
    const handlers = this.channels.get(channel);
    if (!handlers || handlers.size === 0) return 0;

    const payload = typeof message === 'string' ? message : JSON.stringify(message);
    for (const handler of handlers) {
      try {
        handler(payload);
      } catch (err) {
        console.error(`[InMemoryPubSub] Error in subscriber callback for channel ${channel}:`, err);
      }
    }
    return handlers.size;
  }

  async subscribe(channel, handler) {
    if (!this.channels.has(channel)) {
      this.channels.set(channel, new Set());
    }
    this.channels.get(channel).add(handler);
  }

  async unsubscribe(channel, handler) {
    if (!this.channels.has(channel)) return;
    if (handler) {
      this.channels.get(channel).delete(handler);
      if (this.channels.get(channel).size === 0) {
        this.channels.delete(channel);
      }
    } else {
      this.channels.delete(channel);
    }
  }

  clear() {
    this.channels.clear();
  }
}

/**
 * Distributed Redis Pub/Sub Adapter (Multi-Node Cluster Ready)
 */
class RedisPubSubAdapter extends BasePubSubAdapter {
  constructor(redisClient, redisSubscriber) {
    super();
    this.client = redisClient;
    this.subscriber = redisSubscriber;
    this.localHandlers = new Map();
  }

  async publish(channel, message) {
    if (!this.client) throw new Error('Redis client not configured.');
    const payload = typeof message === 'string' ? message : JSON.stringify(message);
    return await this.client.publish(channel, payload);
  }

  async subscribe(channel, handler) {
    if (!this.subscriber) throw new Error('Redis subscriber not configured.');
    if (!this.localHandlers.has(channel)) {
      this.localHandlers.set(channel, new Set());
      await this.subscriber.subscribe(channel, (message) => {
        const handlers = this.localHandlers.get(channel);
        if (handlers) {
          handlers.forEach((h) => h(message));
        }
      });
    }
    this.localHandlers.get(channel).add(handler);
  }

  async unsubscribe(channel, handler) {
    if (!this.localHandlers.has(channel)) return;
    if (handler) {
      this.localHandlers.get(channel).delete(handler);
    }
    if (!handler || this.localHandlers.get(channel).size === 0) {
      this.localHandlers.delete(channel);
      if (this.subscriber) {
        await this.subscriber.unsubscribe(channel);
      }
    }
  }
}

module.exports = {
  BasePubSubAdapter,
  InMemoryPubSubAdapter,
  RedisPubSubAdapter,
};
