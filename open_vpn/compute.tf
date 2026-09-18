resource "aws_instance" "ovpn_instance" {
  ami               = var.ami_id
  instance_type     = "t3.micro"
  source_dest_check = false
  tags = merge(
    var.project_tags,
    {
      Route53HostedZoneId = var.hosted_Zone,
      Route53RecordName = var.record_name
    }
  )
}