# ceph flag

By default, Ceph will reflect the current status of OSDs and perform normal operations such as rebalancing, recovering, and scrubbing. From time to time, it may be advantageous to override Ceph’s default behavior.

## Setting and Unsetting Overrides 

To override Ceph’s default behavior, use the ceph osd set command and the behavior you wish to override. For example:

    ceph osd set <flag>

Once you set the behavior, ceph health will reflect the override(s) that you have set for the cluster.

To cease overriding Ceph’s default behavior, use the ceph osd unset command and the override you wish to cease. For example:

    ceph osd unset <flag>

## Useful flag and description
  - **noin:** Prevents OSDs from being treated as in the cluster.
  - **noout:** Prevents OSDs from being treated as out of the cluster.
  - **noup:** Prevents OSDs from being treated as up and running.
  - **nodown:** Prevents OSDs from being treated as down.
  - **full:** Makes a cluster appear to have reached its full_ratio, and thereby prevents write operations.
  - **pause:** Ceph will stop processing read and write operations, but will not affect OSD in, out, up or down statuses.
  - **nobackfill:** Ceph will prevent new backfill operations.
  - **norebalance:** Ceph will prevent new rebalancing operations.
  - **norecover:** Ceph will prevent new recovery operations.
  - **noscrub:** Ceph will prevent new scrubbing operations.
  - **nodeep-scrub**: Ceph will prevent new deep scrubbing operations.
  - **notieragent:** Ceph will disable the process that is looking for cold/dirty objects to flush and evict.

# Use Cases 
  - **noin:** Commonly used with noout to address flapping OSDs.
  - **noout:** If the mon osd report timeout is exceeded and an OSD has not reported to the monitor, the OSD will get marked out. If this happens erroneously, you can set noout to prevent the OSD(s) from getting marked out while you troubleshoot the issue.
  - **noup:** Commonly used with nodown to address flapping OSDs.
  - **nodown:** Networking issues may interrupt Ceph 'heartbeat' processes, and an OSD may be up but still get marked down. You can set nodown to prevent OSDs from getting marked down while troubleshooting the issue.
  - **full:** If a cluster is reaching its full_ratio, you can pre-emptively set the cluster to full and expand capacity. NOTE: Setting the cluster to full will prevent write operations.
  - **pause:** If you need to troubleshoot a running Ceph cluster without clients reading and writing data, you can set the cluster to pause to prevent client operations.
  - **nobackfill:** If you need to take an OSD or node down temporarily, (e.g., upgrading daemons), you can set nobackfill so that Ceph will not backfill while the OSD(s) is down.
  - **norecover:** If you need to replace an OSD disk and don’t want the PGs to recover to another OSD while you are hotswapping disks, you can set norecover to prevent the other OSDs from copying a new set of PGs to other OSDs.
  - **noscrub and** nodeep-scrubb: If you want to prevent scrubbing (e.g., to reduce overhead during high loads, recovery, backfilling, rebalancing, etc.), you can set noscrub and/or nodeep-scrub to prevent the cluster from scrubbing OSDs.
  - **notieragent:** If you want to stop the tier agent process from finding cold objects to flush to the backing storage tier, you may set notieragent.