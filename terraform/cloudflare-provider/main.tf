resource "cloudflare_dns_record" "a_record" {
  zone_id = var.zone_id
  comment = "Domain verification record"
  content = var.a_record_value
  name = var.a_record_name
  proxied = false
  ttl = 180
  type = "A"
}

resource "cloudflare_dns_record" "cname_record" {
  zone_id = var.zone_id
  comment = "Domain verification record"
  content = var.cname_record_value
  name = var.cname_record_name
  proxied = false
  ttl = 180
  type = "CNAME"
}

resource "cloudflare_dns_record" "txt_record" {
  zone_id = var.zone_id
  comment = "Domain verification record"
  content = var.txt_record_value
  name = var.txt_record_name
  proxied = false
  ttl = 180
  type = "TXT"
}
