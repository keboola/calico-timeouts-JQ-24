# Connection/network timeout test script

Finding the dreaded `curl: (28) Operation timed out after 20001 milliseconds with 0 bytes received`.

## What it does

- A `Pod` with a bash script running 20 curl requests to our API with 1 sec delay.
  - The `Pod` is not deleted nor restarted when requests finish.
  - When all 20 curl requests finish successfully the pod transitions to `Succeeded` state.
  - If any the curl requests fails the pod transitions to `Failed` state.
- There are 50 `Pods` created in a single batch.
- There are 10 batches executed with a 10 seconds delay between them.

The connection/network errors usually start showing up after 3rd batch when >50 pods are running and new pods are arriving at the same time with a number of already finished pods.

## Detection

Each `Pod` logs each curl request to STDOUT. If a request fails

- the script logs the error message to STDOUT, e. g. `curl: (28) Operation timed out after 20001 milliseconds with 0 bytes received`
- the script finishes and propagates the error code to the container
- the container finishes with an error and the `Pod` transitions to `Failed` state.

```
Request 1
Request 2
Request 3
curl: (28) Operation timed out after 20001 milliseconds with 0 bytes received
```

To detect the issues you can

- monitor logs of all containers or
- look for `Pods` in failed state (which is way easier) and then look into their logs to verify the cause of the state.

## How to run

Create 500 `Pods` in 10 batches with 10s delay between batches

```
./run.sh
```

If you want to run only a single batch

```
./generate-pods.sh
```

## Cleanup

To delete all pods from the test in the cluster run

```
./purge.sh
```

