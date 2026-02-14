## Redis Purge

In the absence of getting ttl configured on records going into the Redis datastore, created this script that can be run via cron to "age out" records older than X hours.