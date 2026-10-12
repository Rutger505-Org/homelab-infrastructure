# The zone already has an (empty) redirect entrypoint ruleset from the
# hand-made rule, and a zone can only have one per phase. Adopt it instead of
# creating a new one. Safe to delete after the first apply.
data "cloudflare_rulesets" "rutgerpronk_nl" {
  zone_id = local.rutgerpronk_nl
}

import {
  to = cloudflare_ruleset.rutgerpronk_nl_redirect
  id = "zones/${local.rutgerpronk_nl}/${one([
    for r in data.cloudflare_rulesets.rutgerpronk_nl.rulesets : r.id
    if r.phase == "http_request_dynamic_redirect" && r.kind == "zone"
  ])}"
}
