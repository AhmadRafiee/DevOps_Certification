resource "openstack_images_image_v2" "my_image" {
  name                = var.image_name
  image_source_url    = var.image_url
  disk_format         = var.image_disk_format
  container_format    = var.image_container_format
  visibility          = "public"  # Change to "private" if needed
}