# resource "tls_private_key" "infrastructure" {
#   algorithm   = "ECDSA"
#   ecdsa_curve = "P521"
# }

# resource "tls_cert_request" "infrastructure" {
#   key_algorithm   = "${tls_private_key.infrastructure.algorithm}"
#   private_key_pem = "${tls_private_key.infrastructure.private_key_pem}"

#   subject {
#     common_name = "DOCKER HOST"
#     organization = "Harebrained Apps"
#     organizational_unit = "Infrastructure"
#   }
# }

# resource "tls_locally_signed_cert" "infrastructure" {
#   cert_request_pem = "${tls_cert_request.infrastructure.cert_request_pem}"

#   ca_key_algorithm   = "${tls_private_key.root.algorithm}"
#   ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
#   ca_cert_pem        = "${tls_self_signed_cert.infrastructure.cert_pem}"

#   validity_period_hours = 17520
#   early_renewal_hours   = 8760

#   allowed_uses = ["server_auth"]
# }