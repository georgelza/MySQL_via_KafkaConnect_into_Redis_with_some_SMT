
## Random Notes


- [ShadowTraffic](https://docs.shadowtraffic.io/overview/)
  

### Run

Execute `run_pg.sh`, this will run the shadowtraffic container connected to the host network, allowing localhost as host for the PostgreSQL datastore.

- The simulation configuration is as per the `--config /home/config.json` job configuration.

  - Take note of the `"throttleMs": 1000` (1 second) as part of each generator blocks `localconfigs` section, just to slow things down a bit during development

- License key in `conf/license.env`

- Additional environment variables key in `conf/config.env`

**Note** the varius volume mounts.


### Note

I've modified (basically renamed and duplicated) the run_pg.sh script to run_pg#.sh

You will notice we now include a couple of additional settings to manage conflicts otherwise.

1. we added -rm to auto remove the container after stopping

2. We've now included the --name to specify a unique name for the container.

3. We've provided the --metric-port paramater to make sure both containers don't try and expose the internal metrics at the same host port.