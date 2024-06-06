resource "aws_key_pair" "test" {
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDpgAP1z1Lxg9Uv4tam6WdJBcAftZR4ik7RsSr6aNXqfnTj4civrhd/q8qMqF6wL//3OujVDZfhJcffTzPS2XYhUxh/rRVOB3xcqwETppdykD0XZpkHkc8XtmHpiqk6E9iBI4mDwYcDqEg3/vrDAGYYsnFwWmdDinxzMH1Gei+NPTmTqU+wJ1JZvkw3WBEMZKlUVJC/+nuv+jbMmCtm7sIM4rlp2wyzLWYoidRNMK97sG8+v+mDQol/qXK3Fuetj+1f+vSx2obSzpTxL4RYg1kS6W1fBlSvstDV5bQG4HvywzN5Y8eCpwzHLZ1tYtTycZEApFdy+MSfws5vPOpggQlWfZ4vA8ujfWAF75J+WABV4DlSJ3Ng6rLMW78hVatANUnb9s4clOS8H6yAjv+bU3OElKBkQ10wNneoFIMOA3grjPvPp5r8dI0WDXPIznJThDJO5yMCy3OfCXlu38VDQa1sjVj1zAPG+Vn2DsdVrl50hWSYSB17Zww0MYEr8N5rfFE= aleks@MediaPC"
}

module "lb" {
  source = "../../"
  providers = {
    aws     = aws
    aws.dns = aws
  }
  service_name                 = "website"
  subnets                      = var.lb_subnet_ids
  ami                          = data.aws_ami.ubuntu.id
  backend_subnets              = var.backend_subnet_ids
  asg_name                     = var.asg_name
  asg_min_size                 = 3
  internet_gateway_id          = var.internet_gateway_id
  zone_id                      = data.aws_route53_zone.website.zone_id
  dns_a_records                = var.dns_a_records
  key_pair_name                = aws_key_pair.test.key_name
  userdata                     = data.cloudinit_config.webserver_init.rendered
  health_check_type            = "ELB"
  tags                         = var.tags
  instance_profile_name        = var.instance_profile_name
  instance_profile_permissions = data.aws_iam_policy_document.webserver_permissions.json
}
