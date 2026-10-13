output "records" {
  description = "Internal hostnames and the address they resolve to"
  value       = { for r in adguard_rewrite.this : r.domain => r.answer }
}
