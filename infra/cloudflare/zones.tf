locals {
  account_id = var.cloudflare_account_id

  zone_inspi_cloud            = "cf7b15ec76b250561b26d983e1831500"
  zone_inspiration_particle   = "71af964beafdf7c6efae735f79451219"

  allowed_emails = [
    "daniel.m.baranowski@gmail.com",
    "marta.kuczek@gmail.com",
    "katkowara@gmail.com",
    "nwojcik.psychoterapia@gmail.com",
    "phucvhhy212@gmail.com",
    "adameusz.halaczkiewicz@gmail.com",
  ]
}
