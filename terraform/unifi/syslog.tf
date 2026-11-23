resource "unifi_setting_rsyslogd" "siem" {
  enabled = true
  ip      = local.log_intake_ip
  port    = 514
  contents = [
    "device",
    "client",
    "firewall_default_policy",
    "triggers",
    "updates",
    "admin_activity",
    "critical",
    "security_detections",
    "vpn",
  ]
}
