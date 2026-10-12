# One-time adoption of records that existed before OpenTofu managed DNS.
# Safe to delete once the first apply has imported them.

import {
  to = cloudflare_dns_record.rutgerpronk_com_apex
  id = "5a42a07d90934e2a4a3e2313992b50f8/d50d27988912e394136c4d097c1f0e4d"
}

import {
  to = cloudflare_dns_record.rutgerpronk_com_wildcard
  id = "5a42a07d90934e2a4a3e2313992b50f8/57ba7b4e1de99b72927598c5a3ed9130"
}

import {
  to = cloudflare_dns_record.dijker
  id = "5a42a07d90934e2a4a3e2313992b50f8/07f83b76fbc1b92b537961788a2b94c5"
}

import {
  to = cloudflare_dns_record.dijker_wildcard
  id = "5a42a07d90934e2a4a3e2313992b50f8/9272f0a7a64df700915da05492559fa0"
}

import {
  to = cloudflare_dns_record.rutgerpronk_com_google_verification
  id = "5a42a07d90934e2a4a3e2313992b50f8/894260b94540710f23176ebbdbde0ad0"
}

import {
  to = cloudflare_dns_record.rutgerpronk_nl_apex
  id = "04c9a01113e04e0e701cc74c88c877c4/81e7ebcca512f8a7b2540e2b83f910b0"
}

import {
  to = cloudflare_dns_record.rutgerpronk_nl_ns["ns0.transip.net"]
  id = "04c9a01113e04e0e701cc74c88c877c4/c6f9ac5ac44530ed3d80b09c9b341a92"
}

import {
  to = cloudflare_dns_record.rutgerpronk_nl_ns["ns1.transip.nl"]
  id = "04c9a01113e04e0e701cc74c88c877c4/24046fa356193526b7261e7851268edd"
}

import {
  to = cloudflare_dns_record.rutgerpronk_nl_ns["ns2.transip.eu"]
  id = "04c9a01113e04e0e701cc74c88c877c4/e6d517573a24c9f319bf16cb47469900"
}
