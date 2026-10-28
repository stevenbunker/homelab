output "open_vpn" {
  description = "Outputs from making an Open VPN instance"
  type        = map(string)
  value = {
    open_vpn_network_interface_id = aws_instance.this.primary_network_interface_id
  }
}