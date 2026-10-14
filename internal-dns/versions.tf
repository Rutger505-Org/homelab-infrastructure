terraform {
  required_version = ">= 1.10"

  # Same R2 bucket as proxmox/ and dns/, own key. Credentials and endpoint
  # come from AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_ENDPOINT_URL_S3.
  backend "s3" {
    bucket       = "homelab-tofu-state"
    key          = "internal-dns/terraform.tfstate"
    region       = "auto"
    use_lockfile = true

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }

  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "passphrase" {
      keys = key_provider.pbkdf2.passphrase
    }

    state {
      method   = method.aes_gcm.passphrase
      enforced = true
    }

    plan {
      method   = method.aes_gcm.passphrase
      enforced = true
    }
  }

  required_providers {
    adguard = {
      source  = "gmichels/adguard"
      version = "~> 1.7"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}
