// Bounded retry for idempotent reads only. Permission failures opt out.
export async function retryRead(read, {attempts = 3, sleep = ms => new Promise(resolve => setTimeout(resolve, ms))} = {}) {
  for (let attempt = 0; ; attempt++) {
    try { return await read(attempt); }
    catch (error) {
      if (error.retryable === false || attempt + 1 >= attempts) throw error;
      await sleep(400 * (attempt + 1));
    }
  }
}
