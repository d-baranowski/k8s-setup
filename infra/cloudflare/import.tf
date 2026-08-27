# Rebuild local state from live Cloudflare. Remove this file after a
# successful apply so future plans stay clean.
#
# Import IDs are Cloudflare v4: zone/record, account/tunnel,
# zone/application, zone/application/policy.

# ── tunnels ──────────────────────────────────────────────────
import {
  to = cloudflare_zero_trust_tunnel_cloudflared.utro
  id = "44765ea052c61f472b28ebf4217d05c1/7015259a-489a-4fd9-9e3e-51e1a9300d6b"
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared_config.utro
  id = "44765ea052c61f472b28ebf4217d05c1/7015259a-489a-4fd9-9e3e-51e1a9300d6b"
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared.jenkins
  id = "44765ea052c61f472b28ebf4217d05c1/06897074-eba6-408b-af0a-3955fa65b1da"
}

# ── DNS inspi.cloud ──────────────────────────────────────────
import {
  to = cloudflare_record.staging_utro_test
  id = "cf7b15ec76b250561b26d983e1831500/0e1cc6793140b60342905684efd63b16"
}

# ── DNS inspiration-particle.com ─────────────────────────────
import {
  to = cloudflare_record.root_a
  id = "71af964beafdf7c6efae735f79451219/197e01414ad660d44c21247a29d67788"
}

import {
  to = cloudflare_record.jenkins_cname
  id = "71af964beafdf7c6efae735f79451219/924e49ced570a796e04030cd48969c96"
}

import {
  to = cloudflare_record.local_debug_cname
  id = "71af964beafdf7c6efae735f79451219/c49ccaf40e4c1cd7a72817343b96a4f2"
}

import {
  to = cloudflare_record.utro_cname
  id = "71af964beafdf7c6efae735f79451219/bd54701b97fbb6ee2454f9ac4468d9a3"
}

import {
  to = cloudflare_record.www_cname
  id = "71af964beafdf7c6efae735f79451219/586a64ab405c18dc15ad045e310ac1c9"
}

import {
  to = cloudflare_record.mx_privateemail_2
  id = "71af964beafdf7c6efae735f79451219/580d74824dcd8e21524bf847fbcd4cc5"
}

import {
  to = cloudflare_record.mx_privateemail_1
  id = "71af964beafdf7c6efae735f79451219/b82d50fd76b7de109c906efc51eb91f1"
}

import {
  to = cloudflare_record.mx_send_ses
  id = "71af964beafdf7c6efae735f79451219/210fc1a42a4982cb8db28a390428dd37"
}

import {
  to = cloudflare_record.ns_registrar_2
  id = "71af964beafdf7c6efae735f79451219/2fdd5d73365991a7b2eb2fba70cd8bc0"
}

import {
  to = cloudflare_record.ns_registrar_1
  id = "71af964beafdf7c6efae735f79451219/075497b910a5f1502a259d04f1230f2a"
}

import {
  to = cloudflare_record.txt_spf
  id = "71af964beafdf7c6efae735f79451219/d54b19d9b1cde08838c9bc39402e7399"
}

import {
  to = cloudflare_record.txt_resend_dkim
  id = "71af964beafdf7c6efae735f79451219/a06743a4cf8e46e6b6d4e0b562f5a502"
}

import {
  to = cloudflare_record.txt_send_spf
  id = "71af964beafdf7c6efae735f79451219/7e93f0ecd4e66545c39c93e619604606"
}

# ── Access (account/app[/policy]) ────────────────────────────
import {
  to = cloudflare_zero_trust_access_application.staging_webhook
  id = "44765ea052c61f472b28ebf4217d05c1/f872f170-3c78-4a57-9047-fbdbaa1b3654"
}

import {
  to = cloudflare_zero_trust_access_policy.staging_webhook_bypass
  id = "44765ea052c61f472b28ebf4217d05c1/f872f170-3c78-4a57-9047-fbdbaa1b3654/25026a22-4770-405c-91b5-60bc2ec9bae7"
}

import {
  to = cloudflare_zero_trust_access_application.production_webhook
  id = "44765ea052c61f472b28ebf4217d05c1/f80884bd-3ffd-4188-b140-4cd8bdbecb6b"
}

import {
  to = cloudflare_zero_trust_access_policy.production_webhook_bypass
  id = "44765ea052c61f472b28ebf4217d05c1/f80884bd-3ffd-4188-b140-4cd8bdbecb6b/43970dfc-a2df-42cf-a709-fc6aff97d2f3"
}

import {
  to = cloudflare_zero_trust_access_application.utro_test_ui
  id = "44765ea052c61f472b28ebf4217d05c1/f97a8639-f537-416a-8ec1-59849a9509f6"
}

import {
  to = cloudflare_zero_trust_access_application.utro_ui
  id = "44765ea052c61f472b28ebf4217d05c1/ca6272af-37b6-462a-b822-c3eee6fb30ec"
}
