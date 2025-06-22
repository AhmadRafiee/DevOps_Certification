resource "openstack_compute_flavor_v2" "my_flavor" {
  name           = "my-flavor"   # Name of the flavor
  ram            = 2048          # Memory in MB
  vcpus          = 2             # Number of virtual CPUs
  disk           = 20            # Disk space in GB
  swap           = 0             # Swap space in MB (0 means no swap)
  is_public      = true          # Set to true if you want the flavor to be public
