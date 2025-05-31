# ceph rebalancing

To control and reduce the speed of rebalancing in Ceph, you primarily use configuration options rather than specific command-line flags during the rebalancing operation itself. These options tell the OSDs how aggressively they can rebalance data.

Here are the key configuration options you can adjust:

## Limiting the Number of Concurrent Backfills/Recoveries per OSD:

These settings control how many backfill and recovery operations each OSD can handle simultaneously. Lowering these values will reduce the overall speed of rebalancing.

`osd_max_backfills` (Default: 1 or 10 depending on Ceph version): This option limits the maximum number of concurrent backfill operations an OSD will perform to other OSDs. Lowering this value will significantly reduce the outgoing backfill traffic from each OSD.

    ceph config set osd osd_max_backfills <new_value>

Replace <new_value> with a smaller number (e.g., 1 or 2). You can set this globally for all OSDs under the [osd] section in your ceph.conf or for specific OSDs.

`osd_recovery_max_active` (Default: dynamically adjusted by default, often around 3): This option limits the maximum number of concurrent recovery operations an OSD will perform (both incoming and outgoing). Lowering this will reduce the overall recovery/rebalancing speed.

    ceph config set osd osd_recovery_max_active <new_value>

Replace <new_value> with a smaller number (e.g., 1 or 2). Similar to osd_max_backfills, you can set this globally or per OSD.

## Limiting the Bandwidth Used for Backfill/Recovery:

These options directly control the maximum bandwidth that OSDs will use for backfilling and recovery.

`osd_client_op_queue` (No direct equivalent for bandwidth limiting, but can indirectly influence it): This controls the size of the client operation queue. A smaller queue might indirectly lead to less aggressive background operations. However, directly limiting bandwidth is more effective.

`osd_max_backfill_bandwidth` (Default: 0, unlimited): This option sets the maximum bandwidth (in bytes per second) that an OSD will use for sending data during backfill.

    ceph config set osd osd_max_backfill_bandwidth <bytes_per_second>

Replace <bytes_per_second> with the desired bandwidth limit **(e.g., 10485760 for 10 MB/s)**.

`osd_recovery_max_bandwidth` (Default: 0, unlimited): This option sets the maximum bandwidth (in bytes per second) that an OSD will use for sending and receiving data during recovery.

    ceph config set osd osd_recovery_max_bandwidth <bytes_per_second>

Replace <bytes_per_second> with the desired bandwidth limit.

## How to Apply These Settings:

Using ceph config set (for runtime changes): This applies the changes immediately in memory on the OSD daemons. However, these settings will revert to the configuration file values upon a daemon restart.

    ceph config set osd.<osd_id> osd_max_backfills <new_value>  # For a specific OSD
    ceph config set osd osd_max_backfills <new_value>           # For all OSDs

Replace <osd_id> with the ID of the specific OSD (e.g., osd.0).

Editing ceph.conf (for persistent changes): This is the recommended way to make the changes permanent across OSD restarts. Add or modify the relevant options under the [osd] section (for global settings) or under a specific [osd.<osd_id>] section. After editing the ceph.conf file on the OSD nodes, you need to restart the Ceph OSD daemons for the changes to take effect.

## Example Scenario:

To limit the backfill speed globally to a lower value and also limit the concurrent backfills:

Set the maximum backfill bandwidth to 10 MB/s:

    ceph config set osd osd_max_backfill_bandwidth 10485760

Limit the number of concurrent backfills per OSD to 2:

    ceph config set osd osd_max_backfills 2

## Important Considerations:

  - **Impact on Recovery Time:** Reducing the rebalancing speed will significantly increase the time it takes for the cluster to return to a fully healthy and balanced state after an OSD failure or when new OSDs are added.
  - **Client Performance:** While limiting rebalancing can reduce its impact on client I/O, setting the limits too low can prolong the rebalancing process and potentially lead to prolonged periods of degraded redundancy.
  - **Monitoring:** Monitor your cluster's health and rebalancing progress after making these changes to ensure it's proceeding at an acceptable rate and that client performance is not unduly affected.
  - **Unsetting Limits:** Once the rebalancing is complete, you might want to increase these values back to their defaults or higher values to allow for faster recovery in the future.

By carefully adjusting these configuration options, you can effectively control and reduce the speed of rebalancing in your Ceph cluster to minimize its impact on client operations. Remember to choose values that balance the need for faster rebalancing with the desire to maintain good client performance.





