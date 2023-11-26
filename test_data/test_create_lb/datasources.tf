data "template_cloudinit_config" "webserver_init" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = join(
      "\n",
      [
        "#cloud-config",
        yamlencode(
          {
            "package_update" : true,
            packages : [
              "xinetd",
              "net-tools"
            ]
            write_files : [
              {
                path : "/etc/xinetd.d/http"
                permissions : "0600"
                content : file("${path.module}/xinetd.d.http")
              },
              {
                path : "/usr/local/bin/httpd"
                permissions : "0755"
                content : file("${path.module}/httpd.sh")
              }
            ]
            runcmd : [
              "systemctl start xinetd"
            ]
          }
        )
      ]
    )
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-${var.ubuntu_codename}-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "state"
    values = [
      "available"
    ]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_iam_policy_document" "webserver_permissions" {
  statement {
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
}

data "aws_route53_zone" "website" {
  name = var.dns_zone
}
