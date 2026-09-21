const { CloudTasksClient } = require('@google-cloud/tasks');

/**
 * Service for scheduling deferred ride timeout execution using Google Cloud Tasks.
 */
class TaskQueueService {
  constructor() {
    this.client = null;
    this.projectId = process.env.GCLOUD_PROJECT || 'zyro-66077';
    this.location = process.env.FUNCTION_REGION || 'us-central1';
    this.queueName = process.env.TASK_QUEUE_NAME || 'ride-timeouts';
    this.serviceAccountEmail =
      process.env.CLOUD_TASKS_SERVICE_ACCOUNT ||
      `${this.projectId}@appspot.gserviceaccount.com`;
  }

  getClient() {
    if (!this.client) {
      this.client = new CloudTasksClient();
    }
    return this.client;
  }

  /**
   * Resolves the target HTTP URL for a deployed Firebase Cloud Function.
   *
   * @param {string} [functionName='processRideTimeoutTask']
   * @returns {string} Fully qualified URL
   */
  getTargetUrl(functionName = 'processRideTimeoutTask') {
    if (process.env.TIMEOUT_FUNCTION_URL) {
      return process.env.TIMEOUT_FUNCTION_URL;
    }
    // Standard Firebase Cloud Functions v2 URL format for us-central1
    return `https://${this.location}-${this.projectId}.cloudfunctions.net/${functionName}`;
  }

  /**
   * Schedules a task in Google Cloud Tasks to invoke processRideTimeoutTask
   * at the ride's exact expiresAt timestamp (120 seconds after creation).
   *
   * @param {Object} params
   * @param {string} params.rideId
   * @param {number} params.scheduleTimeSeconds (epoch seconds)
   * @param {string} [params.targetUrl] Optional custom target URL override
   * @returns {Promise<string>} Created task name
   */
  async scheduleRideTimeout({ rideId, scheduleTimeSeconds, targetUrl }) {
    const url = targetUrl || this.getTargetUrl('processRideTimeoutTask');
    const client = this.getClient();
    const parent = client.queuePath(this.projectId, this.location, this.queueName);

    const task = {
      scheduleTime: {
        seconds: Math.floor(scheduleTimeSeconds),
      },
      httpRequest: {
        httpMethod: 'POST',
        url: url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: Buffer.from(JSON.stringify({ rideId })).toString('base64'),
        oidcToken: {
          serviceAccountEmail: this.serviceAccountEmail,
          audience: url,
        },
      },
    };

    try {
      const [response] = await client.createTask({ parent, task });
      console.log(
        `[TaskQueueService] Scheduled Cloud Task "${response.name}" for ride ${rideId} at ${new Date(
          scheduleTimeSeconds * 1000
        ).toISOString()} -> ${url}`
      );
      return response.name;
    } catch (error) {
      console.error(
        `[TaskQueueService] CRITICAL: Failed to schedule Cloud Task for ride ${rideId} on queue "${this.queueName}" at "${url}". Reason: ${error.message}`
      );
      throw error;
    }
  }
}

module.exports = TaskQueueService;
