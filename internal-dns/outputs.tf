output "records" {
  description = "Internal hostnames and the address they resolve to"
  value       = { (adguard_rewrite.wildcard.domain) = adguard_rewrite.wildcard.answer }
}
