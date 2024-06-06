resource "aws_instance" "client" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = var.lb_subnet_ids[0]
  key_name      = aws_key_pair.test.key_name
  tags = {
    Name : "foo-app-client"
  }
}
