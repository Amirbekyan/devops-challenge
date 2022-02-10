## Providers

provider "cloudflare" {
  api_token = var.cf-token
}

## Domain Records

resource "cloudflare_record" "mon" {
  zone_id = var.zone-id
  name    = "mon.devopschallenge.${var.domain-name}"
  value   = hcloud_load_balancer.lb.ipv4
  proxied = false
  type    = "A"
}

resource "cloudflare_record" "main" {
  zone_id = var.zone-id
  name    = "devopschallenge.${var.domain-name}"
  value   = hcloud_load_balancer.lb.ipv4
  proxied = false
  type    = "A"
}
