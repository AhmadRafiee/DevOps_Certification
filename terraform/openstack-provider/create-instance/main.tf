resource "openstack_compute_instance_v2" "basic" {
  name            = "basic"
  image_id        = var.image_id
  flavor_id       = var.flavor_id
  key_pair        = var.key_pair_name
  security_groups = ["default"]
  network {
    name = var.network_name
  }
}
