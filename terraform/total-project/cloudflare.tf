resource "cloudflare_dns_record" "cname_record_api" {
  zone_id = var.zone_id
  comment = "Minio api domain"
  content = var.cname_value_api
  name = var.minio_api_domain
  proxied = false
  ttl = 180
  type = "CNAME"
}

resource "cloudflare_dns_record" "cname_record_panel" {
  zone_id = var.zone_id
  comment = "Minio console domain"
  content = var.cname_value_panel
  name = var.minio_console_domain
  proxied = false
  ttl = 180
  type = "CNAME"
}